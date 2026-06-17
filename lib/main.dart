import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/app.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';

Future<void> main() async {
  debugPrint('DEBUG: main() started');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('DEBUG: WidgetsFlutterBinding initialized');
  await RustLib.init();
  debugPrint('DEBUG: RustLib initialized');
  setupDependencyInjection();
  debugPrint('DEBUG: DI setup complete');

  // Clean up old script runs in background
  getIt<ScriptRunner>().cleanupHistory();

  runApp(const KafkalyzerApp());
  debugPrint('DEBUG: runApp called');
}
