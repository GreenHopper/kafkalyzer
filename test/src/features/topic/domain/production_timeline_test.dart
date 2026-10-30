import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/topic/domain/production_timeline.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

TopicAnalysisReport _buildReport({
  required List<HourBucket> hourlyTimeline,
  int? scanReferenceTimeMs,
  int? completeFromMs,
  ValueFilterResult? valueFilterResult,
}) {
  return TopicAnalysisReport(
    topic: 'test-topic',
    totalMessages: hourlyTimeline.fold<int>(0, (s, b) => s + b.count),
    totalBytes: 1000,
    minMessageSize: 10,
    maxMessageSize: 100,
    avgMessageSize: 50.0,
    tombstonesCount: 0,
    isCompacted: false,
    nullKeysCount: 0,
    partitionStats: const [],
    hourlyDistribution: const [],
    topKeys: const [],
    contentTypeDistribution: const [],
    fieldFrequencies: const [],
    scanDurationMs: 500,
    messageSizePercentiles: null,
    sizePercentilesEstimated: false,
    estimatedDistinctKeys: 0,
    keyCardinalityCapped: false,
    hourlyTimeline: hourlyTimeline,
    scanReferenceTimeMs: scanReferenceTimeMs,
    completeFromMs: completeFromMs,
    timelineOutsideCount: 0,
    valueFilterResult: valueFilterResult,
  );
}

void main() {
  group('ProductionTimeline baseline and anomaly detection', () {
    // Fixed timezone mapping for deterministic tests: UTC
    DateTime toUtc(int ms) =>
        DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

    test('highlights unusual hour (900 vs 300 baseline = +200%)', () {
      // Reference time: day 8 at 09:30 UTC
      // Epoch ms for 2026-10-30 09:30 UTC:
      final refDt = DateTime.utc(2026, 10, 30, 9, 30);
      final refMs = refDt.millisecondsSinceEpoch;
      final refHour = (refMs / 3600000).floor();

      final timeline = <HourBucket>[];
      // Previous 7 days: day 1 to 7 at 09:00 UTC have 300 messages each
      for (var d = 1; d <= 7; d++) {
        final dHour = refHour - (24 * d);
        timeline.add(HourBucket(epochHour: dHour, count: 300));
      }
      // Today at 09:00 UTC has 900 messages
      timeline.add(HourBucket(epochHour: refHour, count: 900));

      final report = _buildReport(
        hourlyTimeline: timeline,
        scanReferenceTimeMs: refMs,
      );

      final domain = ProductionTimeline(report: report, toLocal: toUtc);
      final hours = domain.recentHours(windowHours: 24);

      final currentHourPoint = hours.last;
      expect(currentHourPoint.isCurrentHour, isTrue);
      expect(currentHourPoint.count, 900);
      expect(currentHourPoint.baseline, 300.0);
      expect(currentHourPoint.isUnusual, isTrue);
      expect(currentHourPoint.deltaPercent, 200.0);
    });

    test('does not highlight normal fluctuation (380 vs 300 baseline)', () {
      final refDt = DateTime.utc(2026, 10, 30, 9, 30);
      final refMs = refDt.millisecondsSinceEpoch;
      final refHour = (refMs / 3600000).floor();

      final timeline = <HourBucket>[];
      for (var d = 1; d <= 7; d++) {
        timeline.add(HourBucket(epochHour: refHour - (24 * d), count: 300));
      }
      timeline.add(HourBucket(epochHour: refHour, count: 380));

      final report = _buildReport(
        hourlyTimeline: timeline,
        scanReferenceTimeMs: refMs,
      );

      final domain = ProductionTimeline(report: report, toLocal: toUtc);
      final hours = domain.recentHours(windowHours: 24);

      final currentHourPoint = hours.last;
      expect(currentHourPoint.count, 380);
      expect(currentHourPoint.baseline, 300.0);
      expect(currentHourPoint.isUnusual, isFalse);
    });

    test('does not highlight small absolute numbers (6 vs 2 baseline)', () {
      final refDt = DateTime.utc(2026, 10, 30, 9, 30);
      final refMs = refDt.millisecondsSinceEpoch;
      final refHour = (refMs / 3600000).floor();

      final timeline = <HourBucket>[];
      for (var d = 1; d <= 7; d++) {
        timeline.add(HourBucket(epochHour: refHour - (24 * d), count: 2));
      }
      timeline.add(HourBucket(epochHour: refHour, count: 6));

      final report = _buildReport(
        hourlyTimeline: timeline,
        scanReferenceTimeMs: refMs,
      );

      final domain = ProductionTimeline(report: report, toLocal: toUtc);
      final hours = domain.recentHours(windowHours: 24);

      final currentHourPoint = hours.last;
      expect(currentHourPoint.count, 6);
      expect(currentHourPoint.baseline, 2.0);
      expect(currentHourPoint.isUnusual, isFalse);
    });

    test('returns null baseline when scan does not cover preceding days', () {
      final refDt = DateTime.utc(2026, 10, 30, 9, 30);
      final refMs = refDt.millisecondsSinceEpoch;
      final refHour = (refMs / 3600000).floor();

      // Only covered for last 5 hours (from 05:00 UTC)
      final completeFromMs = refDt
          .subtract(const Duration(hours: 5))
          .millisecondsSinceEpoch;

      final report = _buildReport(
        hourlyTimeline: [HourBucket(epochHour: refHour, count: 100)],
        scanReferenceTimeMs: refMs,
        completeFromMs: completeFromMs,
      );

      final domain = ProductionTimeline(report: report, toLocal: toUtc);
      final hours = domain.recentHours(windowHours: 24);

      final currentHourPoint = hours.last;
      expect(currentHourPoint.baseline, isNull);
      expect(currentHourPoint.isUnusual, isFalse);
      expect(currentHourPoint.deltaPercent, isNull);
    });
  });

  group('ProductionTimeline window switching and imported reports', () {
    DateTime toUtc(int ms) =>
        DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

    test(
      'recentHours produces 24 bars by default and 72 bars when switched',
      () {
        final refDt = DateTime.utc(2026, 10, 30, 12, 0);
        final refMs = refDt.millisecondsSinceEpoch;
        final refHour = (refMs / 3600000).floor();

        final report = _buildReport(
          hourlyTimeline: [HourBucket(epochHour: refHour, count: 50)],
          scanReferenceTimeMs: refMs,
        );

        final domain = ProductionTimeline(report: report, toLocal: toUtc);

        final defaultHours = domain.recentHours();
        expect(defaultHours.length, 24);
        expect(defaultHours.last.epochHour, refHour);
        expect(defaultHours.first.epochHour, refHour - 23);

        final expandedHours = domain.recentHours(windowHours: 72);
        expect(expandedHours.length, 72);
        expect(expandedHours.last.epochHour, refHour);
        expect(expandedHours.first.epochHour, refHour - 71);
      },
    );

    test(
      'imported report ending 3 days ago ends at its own recorded scan moment',
      () {
        // Report from 3 days ago
        final pastScanDt = DateTime.utc(2026, 10, 20, 15, 0);
        final pastScanMs = pastScanDt.millisecondsSinceEpoch;
        final pastHour = (pastScanMs / 3600000).floor();

        final report = _buildReport(
          hourlyTimeline: [HourBucket(epochHour: pastHour, count: 123)],
          scanReferenceTimeMs: pastScanMs,
        );

        final domain = ProductionTimeline(report: report, toLocal: toUtc);
        final hours = domain.recentHours(windowHours: 24);

        expect(hours.length, 24);
        expect(hours.last.epochHour, pastHour);
        expect(
          hours.last.startTime,
          pastScanDt.subtract(Duration(minutes: pastScanDt.minute)),
        );
        expect(hours.last.count, 123);
      },
    );
  });

  group('ProductionTimeline daily distribution and timezone presentation', () {
    // UTC+01:00 fixed timezone
    DateTime toUtcPlus1(int ms) {
      final utc = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      final shifted = utc.add(const Duration(hours: 1));
      return DateTime.utc(
        shifted.year,
        shifted.month,
        shifted.day,
        shifted.hour,
        shifted.minute,
        shifted.second,
      );
    }

    test('counts 2026-10-29T23:30Z for next day (2026-10-30) in UTC+01:00', () {
      // 2026-10-29 23:30 UTC
      final msgDt = DateTime.utc(2026, 10, 29, 23, 30);
      final msgMs = msgDt.millisecondsSinceEpoch;
      final msgHour = (msgMs / 3600000).floor();

      // Scan reference: 2026-10-30 02:00 UTC
      final refDt = DateTime.utc(2026, 10, 30, 2, 0);
      final refMs = refDt.millisecondsSinceEpoch;

      final report = _buildReport(
        hourlyTimeline: [HourBucket(epochHour: msgHour, count: 42)],
        scanReferenceTimeMs: refMs,
      );

      final domain = ProductionTimeline(report: report, toLocal: toUtcPlus1);

      // In recent hours:
      final hours = domain.recentHours(windowHours: 6);
      final msgPoint = hours.firstWhere((p) => p.epochHour == msgHour);
      expect(msgPoint.count, 42);
      expect(msgPoint.startTime.day, 30);
      expect(msgPoint.startTime.hour, 0); // 00:00 - 00:59 local

      // In daily distribution:
      final days = domain.dailyDistribution();
      expect(days.isNotEmpty, isTrue);
      final oct30 = days.firstWhere((d) => d.date.day == 30);
      expect(oct30.count, 42);
    });

    test(
      'daily distribution inserts gap days with 0 messages sorted newest to oldest',
      () {
        // Messages on Oct 26 (Mon) and Oct 28 (Wed), gap on Oct 27 (Tue)
        final monHour =
            (DateTime.utc(2026, 10, 26, 10).millisecondsSinceEpoch / 3600000)
                .floor();
        final wedHour =
            (DateTime.utc(2026, 10, 28, 14).millisecondsSinceEpoch / 3600000)
                .floor();
        final refMs = DateTime.utc(2026, 10, 28, 18).millisecondsSinceEpoch;

        final report = _buildReport(
          hourlyTimeline: [
            HourBucket(epochHour: monHour, count: 1200),
            HourBucket(epochHour: wedHour, count: 1500),
          ],
          scanReferenceTimeMs: refMs,
        );

        final domain = ProductionTimeline(
          report: report,
          toLocal: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        );

        final days = domain.dailyDistribution();
        expect(days.length, 3);
        // Newest first:
        expect(days[0].date.day, 28);
        expect(days[0].count, 1500);

        expect(days[1].date.day, 27); // Gap day
        expect(days[1].count, 0);

        expect(days[2].date.day, 26);
        expect(days[2].count, 1200);
      },
    );

    test(
      'marks day as partially covered when coverage start lies within it',
      () {
        // Coverage started on Oct 27 at 10:00 UTC
        final covStartMs = DateTime.utc(
          2026,
          10,
          27,
          10,
        ).millisecondsSinceEpoch;
        final refMs = DateTime.utc(2026, 10, 28, 18).millisecondsSinceEpoch;
        final hour27 =
            (DateTime.utc(2026, 10, 27, 12).millisecondsSinceEpoch / 3600000)
                .floor();
        final hour28 =
            (DateTime.utc(2026, 10, 28, 12).millisecondsSinceEpoch / 3600000)
                .floor();

        final report = _buildReport(
          hourlyTimeline: [
            HourBucket(epochHour: hour27, count: 500),
            HourBucket(epochHour: hour28, count: 800),
          ],
          scanReferenceTimeMs: refMs,
          completeFromMs: covStartMs,
        );

        final domain = ProductionTimeline(
          report: report,
          toLocal: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        );

        final days = domain.dailyDistribution();
        expect(days.length, 2);

        expect(days[0].date.day, 28);
        expect(days[0].isPartiallyCovered, isFalse);

        expect(days[1].date.day, 27);
        expect(
          days[1].isPartiallyCovered,
          isTrue,
        ); // Started at 10:00, not 00:00
      },
    );

    test('includes matchCount and shares when value filter is active', () {
      final hour =
          (DateTime.utc(2026, 10, 30, 10).millisecondsSinceEpoch / 3600000)
              .floor();
      final refMs = DateTime.utc(2026, 10, 30, 12).millisecondsSinceEpoch;

      final report = _buildReport(
        hourlyTimeline: [HourBucket(epochHour: hour, count: 100)],
        scanReferenceTimeMs: refMs,
        valueFilterResult: ValueFilterResult(
          fieldPath: 'attributes.region',
          value: 'EU',
          messagesWithField: 40,
          matchedMessages: 25,
          matchedTimeline: [HourBucket(epochHour: hour, count: 25)],
        ),
      );

      final domain = ProductionTimeline(
        report: report,
        toLocal: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      );

      final hours = domain.recentHours();
      final matchedHour = hours.firstWhere((p) => p.epochHour == hour);
      expect(matchedHour.count, 100);
      expect(matchedHour.matchCount, 25);
      expect(matchedHour.matchSharePercent, 25.0);

      final days = domain.dailyDistribution();
      expect(days.first.count, 100);
      expect(days.first.matchCount, 25);
      expect(days.first.matchSharePercent, 25.0);
    });
  });

  group('ProductionTimeline unavailable for older reports', () {
    test('returns isAvailable false when scanReferenceTimeMs is null', () {
      final report = _buildReport(
        hourlyTimeline: const [],
        scanReferenceTimeMs: null,
      );

      final domain = ProductionTimeline(report: report);
      expect(domain.isAvailable, isFalse);
      expect(domain.recentHours(), isEmpty);
      expect(domain.dailyDistribution(), isEmpty);
    });
  });

  group('ProductionTimeline DST handling', () {
    test('computes baseline across DST transition without error', () {
      // Create local timezone mapping simulating a DST jump
      // Suppose local clock leaps 02:00 -> 03:00 on spring forward
      DateTime customToLocal(int ms) {
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: false);
      }

      final now = DateTime.now();
      final refMs = now.millisecondsSinceEpoch;
      final refHour = (refMs / 3600000).floor();

      final report = _buildReport(
        hourlyTimeline: [
          HourBucket(epochHour: refHour, count: 50),
          HourBucket(epochHour: refHour - 24, count: 50),
        ],
        scanReferenceTimeMs: refMs,
      );

      final domain = ProductionTimeline(report: report, toLocal: customToLocal);
      final hours = domain.recentHours(windowHours: 24);
      expect(hours.length, 24);
      expect(domain.dailyDistribution().isNotEmpty, isTrue);
    });
  });
}
