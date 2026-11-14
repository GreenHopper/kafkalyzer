import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/services/diagnostics/redaction.dart';
import 'package:logger/logger.dart';

class ErrorRecord {
  final DateTime timestampUtc;
  final String origin;
  final String type;
  final String message;
  final List<String> stackLines;

  const ErrorRecord({
    required this.timestampUtc,
    required this.origin,
    required this.type,
    required this.message,
    required this.stackLines,
  });

  String formatDetails({String? appVersion, String? osSummary}) {
    final buffer = StringBuffer()
      ..writeln('Time (UTC): ${timestampUtc.toIso8601String()}')
      ..writeln('Origin: $origin')
      ..writeln('Type: $type')
      ..writeln('Message: $message');
    if (appVersion != null && appVersion.isNotEmpty) {
      buffer.writeln('App Version: $appVersion');
    }
    if (osSummary != null && osSummary.isNotEmpty) {
      buffer.writeln('OS: $osSummary');
    }
    if (stackLines.isNotEmpty) {
      buffer.writeln('Stack trace:');
      for (final line in stackLines) {
        buffer.writeln('  $line');
      }
    }
    return buffer.toString().trimRight();
  }
}

class ErrorReporter extends ChangeNotifier {
  static const int maxRecent = 20;
  static const Duration throttleWindow = Duration(seconds: 10);

  final DateTime Function() _clock;
  final List<ErrorRecord> _recent = [];
  final Map<String, DateTime> _lastNoticedAt = {};
  final ValueNotifier<ErrorRecord?> pendingNotice = ValueNotifier(null);
  LogCallback? _logListener;

  ErrorReporter({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  List<ErrorRecord> get recent => List.unmodifiable(_recent);

  void attachLoggerListener() {
    if (_logListener != null) return;
    _logListener = (LogEvent event) {
      if (event.level.value >= Level.error.value) {
        final rawMessage = event.error != null
            ? '${event.message}: ${formatSafeError(event.error!)}'
            : event.message.toString();
        _appendRecord(
          ErrorRecord(
            timestampUtc: event.time.toUtc(),
            origin: 'log',
            type: event.error?.runtimeType.toString() ?? 'LogError',
            message: redact(rawMessage),
            stackLines: _extractStackLines(event.stackTrace),
          ),
        );
      }
    };
    Logger.addLogListener(_logListener!);
  }

  void reportUncaught(
    Object error,
    StackTrace? stack, {
    String origin = 'dart',
  }) {
    final now = _clock().toUtc();
    final safeMessage = formatSafeError(error);
    final typeName = error.runtimeType.toString();
    final record = ErrorRecord(
      timestampUtc: now,
      origin: origin,
      type: typeName,
      message: safeMessage,
      stackLines: _extractStackLines(stack),
    );
    _appendRecord(record);

    final signature = '$typeName|$safeMessage';
    final previous = _lastNoticedAt[signature];
    if (previous == null || now.difference(previous) >= throttleWindow) {
      _lastNoticedAt[signature] = now;
      pendingNotice.value = record;
    }
  }

  void clearPendingNotice() {
    pendingNotice.value = null;
  }

  void _appendRecord(ErrorRecord record) {
    if (_recent.length >= maxRecent) {
      _recent.removeAt(0);
    }
    _recent.add(record);
    notifyListeners();
  }

  static List<String> _extractStackLines(StackTrace? stack) {
    if (stack == null) return const [];
    final raw = stack.toString().trimRight();
    if (raw.isEmpty) return const [];
    return raw.split('\n').take(20).map(redact).toList(growable: false);
  }

  @override
  void dispose() {
    if (_logListener != null) {
      Logger.removeLogListener(_logListener!);
      _logListener = null;
    }
    pendingNotice.dispose();
    super.dispose();
  }
}
