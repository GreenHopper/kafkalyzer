import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_reporter.dart';

void main() {
  test(
    'caps ring buffer at 20 and throttles identical notices within 10 seconds',
    () {
      var now = DateTime.utc(2026, 11, 14, 12, 0, 0);
      final reporter = ErrorReporter(clock: () => now);
      addTearDown(reporter.dispose);

      var noticeCount = 0;
      reporter.pendingNotice.addListener(() {
        if (reporter.pendingNotice.value != null) {
          noticeCount++;
          reporter.clearPendingNotice();
        }
      });

      for (var i = 0; i < 50; i++) {
        reporter.reportUncaught(
          StateError('boom sasl.password=secret'),
          StackTrace.current,
        );
      }

      expect(reporter.recent.length, 20);
      expect(reporter.recent.first.message, isNot(contains('secret')));
      expect(reporter.recent.first.message, contains('sasl.password=***'));
      expect(noticeCount, 1);

      // After 10s window expires, a new notice is emitted.
      now = now.add(const Duration(seconds: 10));
      reporter.reportUncaught(
        StateError('boom sasl.password=secret'),
        StackTrace.current,
      );
      expect(noticeCount, 2);
    },
  );

  test('formats FormatException without source payload', () {
    final reporter = ErrorReporter();
    addTearDown(reporter.dispose);

    const sensitiveJson = '{"payloadSecret":"should_not_appear"}';
    reporter.reportUncaught(
      const FormatException('Unexpected character', sensitiveJson, 4),
      null,
    );

    expect(
      reporter.recent.single.message,
      'FormatException: Unexpected character (at offset 4)',
    );
    expect(
      reporter.recent.single.message,
      isNot(contains('should_not_appear')),
    );
  });
}
