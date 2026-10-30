import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

/// Point in time representing a single clock hour in the recent production window.
class RecentHourPoint {
  final int epochHour;
  final DateTime startTime;
  final int count;
  final int? matchCount;
  final bool isCovered;
  final bool isCurrentHour;
  final double? baseline;
  final bool isUnusual;

  const RecentHourPoint({
    required this.epochHour,
    required this.startTime,
    required this.count,
    required this.matchCount,
    required this.isCovered,
    required this.isCurrentHour,
    required this.baseline,
    required this.isUnusual,
  });

  double? get deltaPercent {
    final b = baseline;
    if (b == null || b == 0) return null;
    return ((count - b) / b) * 100.0;
  }

  double? get matchSharePercent {
    final m = matchCount;
    if (m == null || count == 0) return null;
    return (m / count) * 100.0;
  }
}

/// Point in time representing a single calendar day in the daily production view.
class DailyPoint {
  final DateTime date;
  final int count;
  final int? matchCount;
  final bool isPartiallyCovered;

  const DailyPoint({
    required this.date,
    required this.count,
    required this.matchCount,
    required this.isPartiallyCovered,
  });

  double? get matchSharePercent {
    final m = matchCount;
    if (m == null || count == 0) return null;
    return (m / count) * 100.0;
  }
}

/// Domain model computing recent hourly production windows, baseline comparison,
/// anomaly detection, and daily distribution from a [TopicAnalysisReport].
class ProductionTimeline {
  static const double anomalyMultiplier = 2.0;
  static const int anomalyMinExcess = 10;
  static const int defaultWindowHours = 24;
  static const List<int> supportedWindows = [6, 12, 24, 48, 72];

  final TopicAnalysisReport report;
  final DateTime Function(int epochMs) toLocal;

  late final Map<int, int> _hourlyMap;
  late final Map<int, int>? _matchedHourlyMap;

  ProductionTimeline({
    required this.report,
    DateTime Function(int epochMs)? toLocal,
  }) : toLocal = toLocal ?? _defaultToLocal {
    _hourlyMap = <int, int>{
      for (final bucket in report.hourlyTimeline)
        bucket.epochHour: bucket.count,
    };
    final vf = report.valueFilterResult;
    if (vf != null) {
      _matchedHourlyMap = <int, int>{
        for (final bucket in vf.matchedTimeline) bucket.epochHour: bucket.count,
      };
    } else {
      _matchedHourlyMap = null;
    }
  }

  static DateTime _defaultToLocal(int epochMs) =>
      DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: false);

  /// Whether timeline data is available for this report.
  ///
  /// Older reports (v1) and reports where timeline was omitted have null
  /// scanReferenceTimeMs and return false.
  bool get isAvailable => report.scanReferenceTimeMs != null;

  int? get scanReferenceTimeMs => report.scanReferenceTimeMs;
  int? get completeFromMs => report.completeFromMs;
  int get timelineOutsideCount => report.timelineOutsideCount;
  ValueFilterResult? get valueFilterResult => report.valueFilterResult;
  bool get isFiltered => valueFilterResult != null;

  /// Coverage start moment. If null (full scan), coverage starts at the earliest
  /// bucket in the report, or null if no buckets exist.
  int? get effectiveCoverageStartMs {
    if (report.completeFromMs != null) return report.completeFromMs;
    if (report.hourlyTimeline.isNotEmpty) {
      return report.hourlyTimeline
          .map((b) => b.epochHour * 3600000)
          .reduce((a, b) => a < b ? a : b);
    }
    return null;
  }

  /// Whether the specified recent window reaches back before complete coverage.
  bool isWindowPartiallyCovered(int windowHours) {
    final ref = report.scanReferenceTimeMs;
    final complete = report.completeFromMs;
    if (ref == null || complete == null) return false;
    final refHour = (ref / 3600000).floor();
    final windowStartMs = (refHour - windowHours + 1) * 3600000;
    return windowStartMs < complete;
  }

  /// How many hours in the specified recent window are covered by the scan.
  int coveredHoursInWindow(int windowHours) {
    return recentHours(
      windowHours: windowHours,
    ).where((p) => p.isCovered).length;
  }

  /// Computes hourly points for the recent window ending at the scan moment.
  List<RecentHourPoint> recentHours({int windowHours = defaultWindowHours}) {
    final ref = report.scanReferenceTimeMs;
    if (ref == null) return const [];

    final refHour = (ref / 3600000).floor();
    final startHour = refHour - windowHours + 1;
    final points = <RecentHourPoint>[];

    for (var h = startHour; h <= refHour; h++) {
      final hourStartMs = h * 3600000;
      final startTime = toLocal(hourStartMs);
      final count = _hourlyMap[h] ?? 0;
      final matchCount = _matchedHourlyMap?[h] ?? (isFiltered ? 0 : null);
      final isCurrentHour = (h == refHour);
      final isCovered =
          report.completeFromMs == null ||
          hourStartMs >= report.completeFromMs!;
      final baseline = _calculateBaseline(h);

      final isUnusual =
          isCovered &&
          baseline != null &&
          count >= (anomalyMultiplier * baseline) &&
          (count - baseline) >= anomalyMinExcess;

      points.add(
        RecentHourPoint(
          epochHour: h,
          startTime: startTime,
          count: count,
          matchCount: matchCount,
          isCovered: isCovered,
          isCurrentHour: isCurrentHour,
          baseline: baseline,
          isUnusual: isUnusual,
        ),
      );
    }

    return points;
  }

  /// Computes daily production points, sorted from newest to oldest calendar day.
  List<DailyPoint> dailyDistribution() {
    if (!isAvailable) return const [];

    // Group buckets by local calendar date
    final dayCounts = <DateTime, int>{};
    for (final bucket in report.hourlyTimeline) {
      final localDt = toLocal(bucket.epochHour * 3600000);
      final date = _toDateOnly(localDt);
      dayCounts[date] = (dayCounts[date] ?? 0) + bucket.count;
    }

    final matchedDayCounts = <DateTime, int>{};
    if (isFiltered) {
      for (final bucket in report.valueFilterResult!.matchedTimeline) {
        final localDt = toLocal(bucket.epochHour * 3600000);
        final date = _toDateOnly(localDt);
        matchedDayCounts[date] = (matchedDayCounts[date] ?? 0) + bucket.count;
      }
    }

    if (dayCounts.isEmpty && report.completeFromMs == null) {
      return const [];
    }

    // Determine maxDate (newest) and minDate (oldest)
    final refDt = toLocal(report.scanReferenceTimeMs!);
    DateTime maxDate = _toDateOnly(refDt);

    DateTime minDate;
    if (dayCounts.isNotEmpty) {
      minDate = dayCounts.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    } else {
      minDate = maxDate;
    }

    if (report.completeFromMs != null) {
      final covStartDt = toLocal(report.completeFromMs!);
      final covStartDate = _toDateOnly(covStartDt);
      if (covStartDate.isBefore(minDate)) {
        minDate = covStartDate;
      }
    }

    if (minDate.isAfter(maxDate)) {
      maxDate = minDate;
    }

    final result = <DailyPoint>[];
    var current = maxDate;

    while (!current.isBefore(minDate)) {
      final count = dayCounts[current] ?? 0;
      final matchCount = isFiltered ? (matchedDayCounts[current] ?? 0) : null;
      final isPartiallyCovered =
          report.completeFromMs != null &&
          current.millisecondsSinceEpoch < report.completeFromMs!;

      result.add(
        DailyPoint(
          date: current,
          count: count,
          matchCount: matchCount,
          isPartiallyCovered: isPartiallyCovered,
        ),
      );

      // Decrement one calendar day
      current = _subtractDays(current, 1);
    }

    return result;
  }

  /// Calculates the average count of the same clock hour on up to 7 preceding covered days.
  double? _calculateBaseline(int epochHour) {
    final localDt = toLocal(epochHour * 3600000);
    final targetHour = localDt.hour;

    var sum = 0;
    var coveredDays = 0;

    for (var d = 1; d <= 7; d++) {
      final targetDate = _subtractDays(_toDateOnly(localDt), d);
      final center = epochHour - (24 * d);

      // Search within +-2 hours around center for the exact matching local clock hour and date
      for (var offset = -2; offset <= 2; offset++) {
        final candHour = center + offset;
        final candHourStartMs = candHour * 3600000;
        final candDt = toLocal(candHourStartMs);

        if (candDt.hour == targetHour &&
            candDt.year == targetDate.year &&
            candDt.month == targetDate.month &&
            candDt.day == targetDate.day) {
          final isCandCovered =
              report.completeFromMs == null ||
              candHourStartMs >= report.completeFromMs!;

          if (isCandCovered) {
            coveredDays++;
            sum += (_hourlyMap[candHour] ?? 0);
          }
          break;
        }
      }
    }

    if (coveredDays == 0) return null;
    return sum / coveredDays;
  }

  static DateTime _toDateOnly(DateTime dt) {
    if (dt.isUtc) {
      return DateTime.utc(dt.year, dt.month, dt.day);
    }
    return DateTime(dt.year, dt.month, dt.day);
  }

  static DateTime _subtractDays(DateTime dt, int days) {
    if (dt.isUtc) {
      return DateTime.utc(dt.year, dt.month, dt.day - days);
    }
    return DateTime(dt.year, dt.month, dt.day - days);
  }
}
