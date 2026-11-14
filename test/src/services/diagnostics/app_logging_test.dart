import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/rust/api/diagnostics.dart';
import 'package:kafkalyzer/src/services/diagnostics/app_logging.dart';
import 'package:logger/logger.dart';

void main() {
  tearDown(() async {
    await AppLogging.resetForTest();
  });

  test(
    'writes Dart and Rust records to same file with UTC, level, origin, and redaction',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'app_logging_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await AppLogging.init(
        headless: false,
        logsDirOverride: tempDir,
        isReleaseOverride: false,
      );

      expect(AppLogging.fileLogPath, '${tempDir.path}/kafkalyzer.log');

      final controller = StreamController<RustLogRecord>();
      AppLogging.attachRust(controller.stream);

      final logger = Logger();
      logger.w('dart warning sasl.password=topsecret');
      debugPrint('debugPrint route check');

      controller.add(
        RustLogRecord(
          level: RustLogLevel.warn,
          target: 'librdkafka',
          message: 'broker auth failed Authorization: Bearer jwt_secret',
          timestampMs: 1700000000000,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 80));
      await controller.close();

      final content = await File(AppLogging.fileLogPath!).readAsString();
      expect(content, contains('WARN [dart] dart warning sasl.password=***'));
      expect(content, isNot(contains('topsecret')));
      expect(content, contains('DEBUG [dart] debugPrint route check'));
      expect(
        content,
        contains(
          'WARN [rust:librdkafka] broker auth failed Authorization: ***',
        ),
      );
      expect(content, isNot(contains('jwt_secret')));
      // UTC ISO-8601 timestamp ends with Z
      expect(
        RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z').hasMatch(content),
        isTrue,
      );
    },
  );

  test(
    'headless mode writes nothing to stdout and writes warning+ to stderr',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('app_logging_hl_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final stdoutLines = <String>[];
      final stderrLines = <String>[];

      await AppLogging.init(
        headless: true,
        logsDirOverride: tempDir,
        stdoutSink: stdoutLines.add,
        stderrSink: stderrLines.add,
        isReleaseOverride: false,
      );

      final logger = Logger();
      logger.i('info should not hit stdout or stderr');
      logger.w('warn should hit stderr');
      logger.e('error should hit stderr');

      expect(stdoutLines, isEmpty);
      expect(stderrLines.length, 2);
      expect(stderrLines[0], contains('WARN [dart] warn should hit stderr'));
      expect(stderrLines[1], contains('ERROR [dart] error should hit stderr'));
    },
  );

  test(
    'unwritable directory yields fileLogPath == null without throwing',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('app_logging_ro_');
      final blocker = File('${tempDir.path}/not_a_dir');
      await blocker.writeAsString('file');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      // Using a path whose parent is a regular file forces create() to fail.
      final impossibleDir = Directory('${blocker.path}/logs');

      await AppLogging.init(
        headless: false,
        logsDirOverride: impossibleDir,
        isReleaseOverride: true,
      );

      expect(AppLogging.fileLogPath, isNull);
      Logger().e('still does not throw');
    },
  );
}
