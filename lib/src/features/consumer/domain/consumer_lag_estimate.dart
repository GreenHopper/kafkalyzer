import 'package:flutter/foundation.dart';

/// Represents the status of backlog processing for a consumer group or partition.
enum LagProcessingStatus {
  /// Total lag is 0; the consumer is completely caught up.
  caughtUp,

  /// Net lag is actively decreasing over elapsed time.
  draining,

  /// Net lag is increasing over elapsed time (producers outpace consumer).
  accumulating,

  /// Lag is greater than 0, but no change occurred over elapsed time.
  stalled,

  /// Awaiting additional query samples to compute an estimate.
  pending,
}

/// A snapshot reading of consumer lag with an associated timestamp.
@immutable
class TimestampedLag {
  final DateTime timestamp;
  final int lag;

  const TimestampedLag({required this.timestamp, required this.lag});
}

/// Calculation and presentation state of consumer group lag processing.
@immutable
class ConsumerLagEstimate {
  final LagProcessingStatus status;

  /// Processing rate in messages per second.
  /// Positive value indicates net backlog reduction rate.
  /// Negative value indicates net backlog accumulation rate.
  final double? ratePerSecond;

  /// Estimated time remaining until backlog is cleared to zero lag.
  final Duration? estimatedTimeToClear;

  /// Net change in lag across the observation interval (newest - oldest).
  final int? observedLagDelta;

  /// The observation interval duration between compared snapshots.
  final Duration? elapsedDuration;

  const ConsumerLagEstimate({
    required this.status,
    this.ratePerSecond,
    this.estimatedTimeToClear,
    this.observedLagDelta,
    this.elapsedDuration,
  });

  /// Factory constructor to compute an estimate from a series of timestamped readings.
  ///
  /// Readings are expected in chronological order (oldest first, newest last).
  /// [currentLag] is the latest observed lag.
  factory ConsumerLagEstimate.compute({
    required int currentLag,
    required List<TimestampedLag> history,
    Duration minInterval = const Duration(seconds: 1),
  }) {
    if (currentLag == 0) {
      return const ConsumerLagEstimate(status: LagProcessingStatus.caughtUp);
    }

    if (history.length < 2) {
      return const ConsumerLagEstimate(status: LagProcessingStatus.pending);
    }

    final newest = history.last;
    final oldest = history.first;

    final elapsed = newest.timestamp.difference(oldest.timestamp);
    if (elapsed < minInterval || elapsed.inMilliseconds <= 0) {
      return const ConsumerLagEstimate(status: LagProcessingStatus.pending);
    }

    final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
    final delta = newest.lag - oldest.lag;

    // Rate: positive when lag is dropping (draining backlog), negative when accumulating
    final drainRate = -delta / elapsedSeconds;

    if (delta == 0) {
      return ConsumerLagEstimate(
        status: LagProcessingStatus.stalled,
        ratePerSecond: 0.0,
        observedLagDelta: 0,
        elapsedDuration: elapsed,
      );
    } else if (delta > 0) {
      // Lag increased -> backlog accumulating
      return ConsumerLagEstimate(
        status: LagProcessingStatus.accumulating,
        ratePerSecond: drainRate, // negative
        observedLagDelta: delta,
        elapsedDuration: elapsed,
      );
    } else {
      // delta < 0 -> Lag decreased -> draining
      final secondsToClear = currentLag / drainRate;
      final eta = Duration(
        milliseconds: (secondsToClear * 1000).round().clamp(
          0,
          864000000,
        ), // cap at 10 days
      );

      return ConsumerLagEstimate(
        status: LagProcessingStatus.draining,
        ratePerSecond: drainRate,
        estimatedTimeToClear: eta,
        observedLagDelta: delta,
        elapsedDuration: elapsed,
      );
    }
  }

  /// Formats an estimated duration into a compact human-readable string.
  ///
  /// Examples:
  /// - Under 60 seconds: `< 1m`
  /// - 1m to 59m: `~3m 15s`
  /// - 1h to 24h: `~2h 30m`
  /// - Over 24 hours: `> 24h`
  static String formatEta(Duration? eta) {
    if (eta == null) return '';
    if (eta.isNegative || eta == Duration.zero) return '< 1m';

    final totalSeconds = eta.inSeconds;
    if (totalSeconds < 60) {
      return '< 1m';
    }

    final totalMinutes = eta.inMinutes;
    if (totalMinutes < 60) {
      final remSec = totalSeconds % 60;
      return remSec > 0 ? '~${totalMinutes}m ${remSec}s' : '~${totalMinutes}m';
    }

    final totalHours = eta.inHours;
    if (totalHours < 24) {
      final remMin = totalMinutes % 60;
      return remMin > 0 ? '~${totalHours}h ${remMin}m' : '~${totalHours}h';
    }

    return '> 24h';
  }

  /// Formats a throughput rate into a human-readable rate string (e.g., `42.5 msg/s`).
  static String formatRate(double? rate, {String unit = 'msg/s'}) {
    if (rate == null) return '-';
    final absRate = rate.abs();
    if (absRate >= 100) {
      return '${absRate.round()} $unit';
    } else if (absRate >= 10) {
      return '${absRate.toStringAsFixed(1)} $unit';
    } else if (absRate > 0) {
      return '${absRate.toStringAsFixed(2)} $unit';
    } else {
      return '0 $unit';
    }
  }
}
