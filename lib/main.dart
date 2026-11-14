import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/app.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/application/headless_script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/rust/api/diagnostics.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/diagnostics/app_logging.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_handlers.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_reporter.dart';
import 'package:kafkalyzer/src/services/diagnostics/redaction.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/services/update_service.dart';
import 'package:kafkalyzer/src/ui/startup_error_app.dart';
import 'package:kafkalyzer/src/utils/app_version_helper.dart';
import 'package:logger/logger.dart';

bool isHeadlessInvocation(List<String> args) {
  return args.isNotEmpty &&
      (args.first == 'script' ||
          args.contains('--script') ||
          args.contains('--help') ||
          args.contains('-h'));
}

Future<void> main([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();
  final headless = isHeadlessInvocation(args);

  await AppLogging.init(headless: headless);
  final reporter = ErrorReporter()..attachLoggerListener();
  final logger = Logger();
  installErrorHandlers(headless: headless, reporter: reporter, logger: logger);

  try {
    await KafkalyzerRustLib.init();
    AppLogging.attachRust(
      initRustLogging(
        maxLevel: AppLogging.currentRustMaxLevel(),
        logFilePath: AppLogging.fileLogPath ?? '',
      ),
    );
    setupDependencyInjection(errorReporter: reporter);

    if (headless) {
      await HeadlessScriptRunner.runCli(args);
      return;
    }

    await getIt<SettingsService>().initializeSettings();
    await AppVersionHelper.init();
    await getIt<UpdateService>().initialize();
  } catch (e, st) {
    logger.f(
      'Fatal startup error: ${formatSafeError(e)}',
      error: e,
      stackTrace: st,
    );
    if (headless) {
      stderr.writeln('Startup failed: ${formatSafeError(e)}');
      exit(3);
    }
    runApp(
      StartupErrorApp(error: e, stack: st, logPath: AppLogging.fileLogPath),
    );
    return;
  }

  unawaited(getIt<UpdateService>().runBackgroundCheck());
  getIt<ScriptRunner>().cleanupHistory();

  runApp(const KafkalyzerApp());
}
