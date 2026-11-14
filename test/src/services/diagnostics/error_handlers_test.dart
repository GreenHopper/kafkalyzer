import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_handlers.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_reporter.dart';
import 'package:logger/logger.dart';

class _MemoryOutput extends LogOutput {
  final List<OutputEvent> events = [];

  @override
  void output(OutputEvent event) {
    events.add(event);
  }
}

void main() {
  late FlutterExceptionHandler? prevFlutterError;
  late bool Function(Object, StackTrace)? prevPlatformError;

  setUp(() {
    prevFlutterError = FlutterError.onError;
    prevPlatformError = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = prevFlutterError;
    PlatformDispatcher.instance.onError = prevPlatformError;
  });

  test(
    'FlutterError.onError logs, notifies reporter, and skips silent errors for notice',
    () {
      final output = _MemoryOutput();
      final logger = Logger(
        filter: ProductionFilter(),
        printer: SimplePrinter(colors: false),
        output: output,
        level: Level.debug,
      );
      final reporter = ErrorReporter();
      addTearDown(reporter.dispose);

      installErrorHandlers(
        headless: false,
        reporter: reporter,
        logger: logger,
        isReleaseOverride: true,
      );

      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('silent boom'), silent: true),
      );
      expect(reporter.recent, isEmpty);
      expect(reporter.pendingNotice.value, isNull);
      expect(output.events.single.level, Level.debug);

      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('loud boom'), silent: false),
      );
      expect(reporter.recent.length, 1);
      expect(reporter.pendingNotice.value?.message, contains('loud boom'));
      expect(output.events.last.level, Level.error);
    },
  );

  test(
    'PlatformDispatcher.onError logs, reports, and exits with 3 in headless mode',
    () {
      final output = _MemoryOutput();
      final logger = Logger(
        filter: ProductionFilter(),
        printer: SimplePrinter(colors: false),
        output: output,
        level: Level.debug,
      );
      final reporter = ErrorReporter();
      addTearDown(reporter.dispose);

      int? exitedWith;
      final stderrLines = <String>[];

      installErrorHandlers(
        headless: true,
        reporter: reporter,
        logger: logger,
        exitFn: (code) => exitedWith = code,
        stderrSink: stderrLines.add,
        isReleaseOverride: true,
      );

      final handled = PlatformDispatcher.instance.onError!(
        ArgumentError('bad arg'),
        StackTrace.current,
      );

      expect(handled, isTrue);
      expect(exitedWith, 3);
      expect(stderrLines.single, contains('bad arg'));
      expect(reporter.recent.length, 1);
      expect(output.events.single.level, Level.error);
    },
  );
}
