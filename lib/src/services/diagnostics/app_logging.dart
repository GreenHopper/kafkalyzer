import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/rust/api/diagnostics.dart';
import 'package:kafkalyzer/src/services/diagnostics/redaction.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class _TaggedLogMessage {
  final String origin;
  final Object? message;

  const _TaggedLogMessage(this.origin, this.message);
}

class RedactingLinePrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final ts = event.time.toUtc().toIso8601String();
    final levelName = _levelLabel(event.level);

    final String origin;
    final Object? rawMsg;
    if (event.message is _TaggedLogMessage) {
      final tagged = event.message as _TaggedLogMessage;
      origin = tagged.origin;
      rawMsg = tagged.message;
    } else {
      origin = 'dart';
      rawMsg = event.message;
    }

    final text = redact(rawMsg?.toString() ?? '');
    final lines = <String>['$ts $levelName [$origin] $text'];

    if (event.error != null) {
      lines.add('  error: ${formatSafeError(event.error!)}');
    }
    if (event.stackTrace != null) {
      final stackLines = event.stackTrace.toString().trimRight().split('\n');
      for (final stackLine in stackLines.take(20)) {
        lines.add('  ${redact(stackLine)}');
      }
    }
    return lines;
  }

  static String _levelLabel(Level level) {
    switch (level) {
      case Level.trace:
        return 'TRACE';
      case Level.debug:
        return 'DEBUG';
      case Level.info:
        return 'INFO';
      case Level.warning:
        return 'WARN';
      case Level.error:
        return 'ERROR';
      case Level.fatal:
        return 'FATAL';
      default:
        return level.name.toUpperCase();
    }
  }
}

class _SharedLogOutput extends LogOutput {
  final List<LogOutput> _targets;
  final void Function(String line)? _stdoutSink;
  final void Function(String line)? _stderrSink;
  final bool _headless;
  final bool _debugGuiConsole;

  _SharedLogOutput({
    required List<LogOutput> targets,
    required bool headless,
    required bool debugGuiConsole,
    void Function(String line)? stdoutSink,
    void Function(String line)? stderrSink,
  }) : _targets = targets,
       _headless = headless,
       _debugGuiConsole = debugGuiConsole,
       _stdoutSink = stdoutSink,
       _stderrSink = stderrSink;

  @override
  Future<void> init() async {}

  @override
  void output(OutputEvent event) {
    for (final target in _targets) {
      try {
        target.output(event);
      } catch (_) {}
    }
    if (_headless) {
      if (event.level.value >= Level.warning.value) {
        final sink = _stderrSink ?? stderr.writeln;
        for (final line in event.lines) {
          sink(line);
        }
      }
    } else if (_debugGuiConsole) {
      final sink = _stdoutSink ?? stdout.writeln;
      for (final line in event.lines) {
        sink(line);
      }
    }
  }

  @override
  Future<void> destroy() async {}
}

class _DelegatingDefaultOutput extends LogOutput {
  @override
  Future<void> init() async {}

  @override
  void output(OutputEvent event) {
    AppLogging._sharedOutput?.output(event);
  }

  @override
  Future<void> destroy() async {}
}

class AppLogging {
  AppLogging._();

  static LogOutput? _sharedOutput;
  static AdvancedFileOutput? _fileOutput;
  static Logger? _logger;
  static StreamSubscription<RustLogRecord>? _rustSub;
  static DebugPrintCallback? _originalDebugPrint;

  static String? fileLogPath;
  static String? logDirectoryPath;

  static LogFilter Function() _savedDefaultFilter = Logger.defaultFilter;
  static LogPrinter Function() _savedDefaultPrinter = Logger.defaultPrinter;
  static LogOutput Function() _savedDefaultOutput = Logger.defaultOutput;
  static Level _savedDefaultLevel = Logger.level;
  static bool _defaultsSaved = false;

  static Future<void> init({
    required bool headless,
    Directory? logsDirOverride,
    Future<Directory> Function()? supportDirProvider,
    void Function(String line)? stdoutSink,
    void Function(String line)? stderrSink,
    bool? isReleaseOverride,
    Map<String, String>? envOverride,
  }) async {
    try {
      if (!_defaultsSaved) {
        _savedDefaultFilter = Logger.defaultFilter;
        _savedDefaultPrinter = Logger.defaultPrinter;
        _savedDefaultOutput = Logger.defaultOutput;
        _savedDefaultLevel = Logger.level;
        _defaultsSaved = true;
      }
      _originalDebugPrint ??= debugPrint;

      final isRelease = isReleaseOverride ?? kReleaseMode;
      final env = envOverride ?? Platform.environment;
      final level = _resolveLevel(env['KAFKALYZER_LOG_LEVEL'], isRelease);

      Logger.level = level;
      Logger.defaultFilter = () => ProductionFilter();
      Logger.defaultPrinter = () => RedactingLinePrinter();
      Logger.defaultOutput = () => _DelegatingDefaultOutput();

      final targets = <LogOutput>[];
      fileLogPath = null;
      logDirectoryPath = null;

      try {
        final Directory logsDir;
        if (logsDirOverride != null) {
          logsDir = logsDirOverride;
        } else {
          final supportDir =
              await (supportDirProvider ?? getApplicationSupportDirectory)();
          logsDir = Directory(
            '${supportDir.path}${Platform.pathSeparator}logs',
          );
        }
        if (!await logsDir.exists()) {
          await logsDir.create(recursive: true);
        }
        // Verify writability before configuring AdvancedFileOutput.
        final probe = File(
          '${logsDir.path}${Platform.pathSeparator}.write_probe_$pid',
        );
        await probe.writeAsString('');
        await probe.delete();

        final fileOut = AdvancedFileOutput(
          path: logsDir.path,
          latestFileName: 'kafkalyzer.log',
          maxFileSizeKB: 5120,
          maxRotatedFilesCount: 3,
          writeImmediately: const [
            Level.error,
            Level.fatal,
            Level.warning,
            Level.info,
            Level.debug,
          ],
        );
        await fileOut.init();
        _fileOutput = fileOut;
        targets.add(fileOut);
        logDirectoryPath = logsDir.path;
        fileLogPath = '${logsDir.path}${Platform.pathSeparator}kafkalyzer.log';
      } catch (_) {
        fileLogPath = null;
        logDirectoryPath = null;
      }

      _sharedOutput = _SharedLogOutput(
        targets: targets,
        headless: headless,
        debugGuiConsole: !isRelease && !headless,
        stdoutSink: stdoutSink,
        stderrSink: stderrSink,
      );

      _logger = Logger(
        filter: ProductionFilter(),
        printer: RedactingLinePrinter(),
        output: _DelegatingDefaultOutput(),
        level: level,
      );

      debugPrint = (String? message, {int? wrapWidth}) {
        if (message == null || message.isEmpty) return;
        _logger?.d(message);
      };
    } catch (_) {
      fileLogPath = null;
    }
  }

  static RustLogLevel currentRustMaxLevel() {
    switch (Logger.level) {
      case Level.error:
      case Level.fatal:
        return RustLogLevel.error;
      case Level.warning:
        return RustLogLevel.warn;
      case Level.info:
        return RustLogLevel.info;
      case Level.debug:
        return RustLogLevel.debug;
      case Level.trace:
        return RustLogLevel.trace;
      default:
        return RustLogLevel.info;
    }
  }

  static void attachRust(Stream<RustLogRecord> stream) {
    _rustSub?.cancel();
    _rustSub = stream.listen((record) {
      final logger = _logger ?? Logger();
      final level = _mapRustLevel(record.level);
      final origin = record.target.isEmpty ? 'rust' : 'rust:${record.target}';
      logger.log(level, _TaggedLogMessage(origin, record.message));
    }, onError: (_) {});
  }

  static Future<void> resetForTest() async {
    await _rustSub?.cancel();
    _rustSub = null;
    try {
      await _fileOutput?.destroy();
    } catch (_) {}
    _fileOutput = null;
    _sharedOutput = null;
    _logger = null;
    fileLogPath = null;
    logDirectoryPath = null;

    if (_originalDebugPrint != null) {
      debugPrint = _originalDebugPrint!;
    }
    if (_defaultsSaved) {
      Logger.defaultFilter = _savedDefaultFilter;
      Logger.defaultPrinter = _savedDefaultPrinter;
      Logger.defaultOutput = _savedDefaultOutput;
      Logger.level = _savedDefaultLevel;
    }
  }

  static Level _resolveLevel(String? rawEnv, bool isRelease) {
    switch (rawEnv?.trim().toLowerCase()) {
      case 'trace':
        return Level.trace;
      case 'debug':
        return Level.debug;
      case 'info':
        return Level.info;
      case 'warn':
      case 'warning':
        return Level.warning;
      case 'error':
        return Level.error;
      default:
        return isRelease ? Level.info : Level.debug;
    }
  }

  static Level _mapRustLevel(RustLogLevel level) {
    switch (level) {
      case RustLogLevel.error:
        return Level.error;
      case RustLogLevel.warn:
        return Level.warning;
      case RustLogLevel.info:
        return Level.info;
      case RustLogLevel.debug:
        return Level.debug;
      case RustLogLevel.trace:
        return Level.trace;
    }
  }
}
