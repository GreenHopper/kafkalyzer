import 'package:kafkalyzer/src/features/scripting/application/headless_script_runner.dart';

Future<void> main(List<String> args) async {
  await HeadlessScriptRunner.runCli(args);
}
