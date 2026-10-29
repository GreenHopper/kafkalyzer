import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/consumer/domain/consumer_lag_estimate.dart';

void main() {
  group('ConsumerLagEstimate', () {
    test('returns caughtUp when current lag is 0', () {
      final estimate = ConsumerLagEstimate.compute(
        currentLag: 0,
        history: [
          TimestampedLag(timestamp: DateTime(2026, 1, 1, 12, 0, 0), lag: 100),
          TimestampedLag(timestamp: DateTime(2026, 1, 1, 12, 0, 10), lag: 0),
        ],
      );

      expect(estimate.status, LagProcessingStatus.caughtUp);
      expect(estimate.estimatedTimeToClear, isNull);
    });

    test('returns pending when fewer than 2 history entries exist', () {
      final estimate = ConsumerLagEstimate.compute(
        currentLag: 500,
        history: [
          TimestampedLag(timestamp: DateTime(2026, 1, 1, 12, 0, 0), lag: 500),
        ],
      );

      expect(estimate.status, LagProcessingStatus.pending);
    });

    test('returns pending when interval is shorter than minInterval', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final estimate = ConsumerLagEstimate.compute(
        currentLag: 500,
        history: [
          TimestampedLag(timestamp: now, lag: 600),
          TimestampedLag(
            timestamp: now.add(const Duration(milliseconds: 500)),
            lag: 500,
          ),
        ],
        minInterval: const Duration(seconds: 1),
      );

      expect(estimate.status, LagProcessingStatus.pending);
    });

    test('returns draining and calculates ETA when lag is decreasing', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final t1 = DateTime(2026, 1, 1, 12, 0, 10); // 10s elapsed
      // Lag dropped from 1000 to 800 (-200 lag over 10s => 20 msgs/s)
      // At 800 current lag with 20 msgs/s => 40 seconds ETA
      final estimate = ConsumerLagEstimate.compute(
        currentLag: 800,
        history: [
          TimestampedLag(timestamp: t0, lag: 1000),
          TimestampedLag(timestamp: t1, lag: 800),
        ],
      );

      expect(estimate.status, LagProcessingStatus.draining);
      expect(estimate.ratePerSecond, closeTo(20.0, 0.01));
      expect(estimate.observedLagDelta, -200);
      expect(estimate.elapsedDuration, const Duration(seconds: 10));
      expect(estimate.estimatedTimeToClear, const Duration(seconds: 40));
    });

    test('returns accumulating when lag is increasing', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final t1 = DateTime(2026, 1, 1, 12, 0, 10);
      // Lag grew from 500 to 700 (+200 lag over 10s)
      final estimate = ConsumerLagEstimate.compute(
        currentLag: 700,
        history: [
          TimestampedLag(timestamp: t0, lag: 500),
          TimestampedLag(timestamp: t1, lag: 700),
        ],
      );

      expect(estimate.status, LagProcessingStatus.accumulating);
      expect(estimate.ratePerSecond, closeTo(-20.0, 0.01));
      expect(estimate.observedLagDelta, 200);
      expect(estimate.estimatedTimeToClear, isNull);
    });

    test('returns stalled when lag has not changed', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final t1 = DateTime(2026, 1, 1, 12, 0, 10);
      final estimate = ConsumerLagEstimate.compute(
        currentLag: 500,
        history: [
          TimestampedLag(timestamp: t0, lag: 500),
          TimestampedLag(timestamp: t1, lag: 500),
        ],
      );

      expect(estimate.status, LagProcessingStatus.stalled);
      expect(estimate.ratePerSecond, 0.0);
      expect(estimate.observedLagDelta, 0);
      expect(estimate.estimatedTimeToClear, isNull);
    });

    group('formatEta', () {
      test('handles null and edge durations', () {
        expect(ConsumerLagEstimate.formatEta(null), '');
        expect(ConsumerLagEstimate.formatEta(Duration.zero), '< 1m');
        expect(
          ConsumerLagEstimate.formatEta(const Duration(seconds: -10)),
          '< 1m',
        );
        expect(
          ConsumerLagEstimate.formatEta(const Duration(seconds: 45)),
          '< 1m',
        );
      });

      test('formats minutes and seconds', () {
        expect(
          ConsumerLagEstimate.formatEta(
            const Duration(minutes: 3, seconds: 15),
          ),
          '~3m 15s',
        );
        expect(
          ConsumerLagEstimate.formatEta(const Duration(minutes: 10)),
          '~10m',
        );
      });

      test('formats hours and minutes', () {
        expect(
          ConsumerLagEstimate.formatEta(const Duration(hours: 2, minutes: 30)),
          '~2h 30m',
        );
        expect(ConsumerLagEstimate.formatEta(const Duration(hours: 5)), '~5h');
      });

      test('formats over 24 hours', () {
        expect(
          ConsumerLagEstimate.formatEta(const Duration(hours: 25)),
          '> 24h',
        );
      });
    });

    group('formatRate', () {
      test('handles null and zero rates', () {
        expect(ConsumerLagEstimate.formatRate(null), '-');
        expect(ConsumerLagEstimate.formatRate(0.0), '0 msg/s');
      });

      test('formats small, medium, and large rates', () {
        expect(ConsumerLagEstimate.formatRate(1.234), '1.23 msg/s');
        expect(ConsumerLagEstimate.formatRate(42.5), '42.5 msg/s');
        expect(ConsumerLagEstimate.formatRate(150.2), '150 msg/s');
        // Negative rate displays absolute value with unit
        expect(ConsumerLagEstimate.formatRate(-25.4), '25.4 msg/s');
      });
    });
  });
}
