import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/app.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/utils/app_version_helper.dart';

Future<void> main() async {
  debugPrint('DEBUG: main() started');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('DEBUG: WidgetsFlutterBinding initialized');
  await RustLib.init();
  debugPrint('DEBUG: RustLib initialized');
  setupDependencyInjection();
  debugPrint('DEBUG: DI setup complete');

  // Initialize settings (like default output directory)
  await getIt<SettingsService>().initializeSettings();

  await AppVersionHelper.init();

  // Clean up old script runs in background
  getIt<ScriptRunner>().cleanupHistory();

  runApp(const KafkalyzerApp());
  debugPrint('DEBUG: runApp called');
}
