import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/scripting/application/headless_script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class FakeScriptRunner implements ScriptRunner {
  @override
  Map<String, StepStatus> stepStatuses = {};

  @override
  Map<String, String> stepErrorMessages = {};

  @override
  int getMatchCount(String stepId, String topic) => 5;

  @override
  Future<ScriptRun?> runScript(
    Script script,
    Map<String, String> variableValues, {
    ClusterProfile? overrideCluster,
  }) async {
    return ScriptRun(
      id: 'run-123',
      scriptName: script.name,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      parameters: variableValues,
      status: ScriptRunStatus.completed,
      path: '/tmp',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('HeadlessScriptRunner.runCli', () {
    test('returns 0 and prints usage for --help', () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final code = await HeadlessScriptRunner.runCli(
        ['--help'],
        stdoutSink: out,
        stderrSink: err,
        shouldExit: false,
      );

      expect(code, 0);
      expect(err.toString(), contains('kafkalyzer headless script runner'));
      expect(err.toString(), contains('--script'));
    });

    test('returns 1 when arguments are empty', () async {
      final err = StringBuffer();
      final code = await HeadlessScriptRunner.runCli(
        [],
        stderrSink: err,
        shouldExit: false,
      );

      expect(code, 1);
      expect(err.toString(), contains('kafkalyzer headless script runner'));
    });

    test('returns 1 when --cluster is missing', () async {
      final err = StringBuffer();
      final code = await HeadlessScriptRunner.runCli(
        ['--script', 'my-script'],
        stderrSink: err,
        shouldExit: false,
      );

      expect(code, 1);
      expect(
        err.toString(),
        contains('Error: Both --script and --cluster are required.'),
      );
    });

    test('returns 2 when --params file is missing', () async {
      final err = StringBuffer();
      final code = await HeadlessScriptRunner.runCli(
        [
          '--script',
          'my-script',
          '--cluster',
          'prod-cluster',
          '--params',
          '/path/to/nonexistent_file.json',
        ],
        stderrSink: err,
        shouldExit: false,
      );

      expect(code, 2);
      expect(err.toString(), contains('Parameters file not found'));
    });

    test('parses --params JSON file and environment variables', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'kafkalyzer_cli_test_',
      );
      final paramsFile = File('${tempDir.path}/params.json');
      paramsFile.writeAsStringSync(
        jsonEncode({'fromFile': 'value1', 'shared': 'fileValue'}),
      );

      final out = StringBuffer();
      final err = StringBuffer();

      final script = Script(
        id: 's1',
        name: 'test-script',
        variables: const [
          ScriptVariable(name: 'fromFile', type: ScriptVariableType.string),
          ScriptVariable(name: 'fromEnv', type: ScriptVariableType.string),
          ScriptVariable(name: 'fromCli', type: ScriptVariableType.string),
          ScriptVariable(name: 'shared', type: ScriptVariableType.string),
        ],
      );

      const cluster = ClusterProfile(
        name: 'test-cluster',
        bootstrapServers: 'localhost:9092',
      );

      final code = await HeadlessScriptRunner.runCli(
        [
          'script',
          'run',
          '--script',
          'test-script',
          '--cluster',
          'test-cluster',
          '--params',
          paramsFile.path,
          '--var',
          'fromCli=cliVal',
          '--var',
          'shared=cliOverride',
          '--json',
        ],
        stdoutSink: out,
        stderrSink: err,
        shouldExit: false,
        environmentOverride: {
          'KAFKALYZER_VAR_fromEnv': 'envVal',
          'OTHER_ENV': 'ignored',
        },
        clusterOverride: cluster,
        scriptOverride: script,
        runnerOverride: FakeScriptRunner(),
      );

      tempDir.deleteSync(recursive: true);

      expect(code, 0);
      final jsonOutput = jsonDecode(out.toString()) as Map<String, dynamic>;
      expect(jsonOutput['success'], isTrue);
      final vars = jsonOutput['extractedVariables'] as Map<String, dynamic>;
      expect(vars['fromFile'], 'value1');
      expect(vars['fromEnv'], 'envVal');
      expect(vars['fromCli'], 'cliVal');
      expect(vars['shared'], 'cliOverride'); // CLI overrides file
    });
  });
}
