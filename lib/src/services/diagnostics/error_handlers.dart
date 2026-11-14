import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_reporter.dart';
import 'package:kafkalyzer/src/services/diagnostics/redaction.dart';
import 'package:logger/logger.dart';

void installErrorHandlers({
  required bool headless,
  required ErrorReporter reporter,
  Logger? logger,
  void Function(int code)? exitFn,
  void Function(String line)? stderrSink,
  bool? isReleaseOverride,
}) {
  final log = logger ?? Logger();
  final doExit = exitFn ?? exit;
  final writeStderr = stderrSink ?? stderr.writeln;
  final isRelease = isReleaseOverride ?? kReleaseMode;

  FlutterError.onError = (FlutterErrorDetails details) {
    try {
      if (details.silent) {
        log.d(
          'Silent FlutterError: ${formatSafeError(details.exception)}',
          error: details.exception,
          stackTrace: details.stack,
        );
        return;
      }

      log.e(
        'Uncaught FlutterError: ${formatSafeError(details.exception)}',
        error: details.exception,
        stackTrace: details.stack,
      );
      reporter.reportUncaught(
        details.exception,
        details.stack,
        origin: 'flutter',
      );

      if (!isRelease) {
        FlutterError.presentError(details);
      }

      if (headless) {
        writeStderr('Uncaught error: ${formatSafeError(details.exception)}');
        doExit(3);
      }
    } catch (handlerError) {
      try {
        writeStderr('Error in FlutterError.onError: $handlerError');
      } catch (_) {}
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    try {
      log.e(
        'Uncaught platform error: ${formatSafeError(error)}',
        error: error,
        stackTrace: stack,
      );
      reporter.reportUncaught(error, stack, origin: 'platform');
      if (headless) {
        writeStderr('Uncaught error: ${formatSafeError(error)}');
        doExit(3);
      }
    } catch (handlerError) {
      try {
        writeStderr('Error in PlatformDispatcher.onError: $handlerError');
      } catch (_) {}
    }
    return true;
  };
}
