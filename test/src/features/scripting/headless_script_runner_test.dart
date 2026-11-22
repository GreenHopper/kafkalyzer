import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/application/headless_script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';

class _RecordingScriptRunner extends ChangeNotifier implements ScriptRunner {
  _RecordingScriptRunner({this.throwOnRun = false, this.errorSteps = false});

  final bool throwOnRun;
  final bool errorSteps;
  ScriptRun? lastRun;

  @override
  Map<String, StepStatus> get stepStatuses =>
      errorSteps ? {'s1': StepStatus.error} : {'s1': StepStatus.completed};

  @override
  Map<String, String> get stepErrorMessages =>
      errorSteps ? {'s1': 'step blew up'} : {};

  @override
  int getMatchCount(String stepId, String topic) => 2;

  @override
  Future<ScriptRun?> runScript(
    Script script,
    Map<String, String> variables, {
    ClusterProfile? overrideCluster,
  }) async {
    if (throwOnRun) throw StateError('runner failed');
    lastRun = ScriptRun(
      id: 'run-ok',
      scriptName: script.name,
      timestamp: 1,
      parameters: variables,
      status: errorSteps ? ScriptRunStatus.error : ScriptRunStatus.completed,
      path: '/tmp/run-ok',
      scriptSnapshot: script,
    );
    return lastRun;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('HeadlessScriptRunner', () {
    test('formatCliCommand formats command correctly', () {
      final cmd = HeadlessScriptRunner.formatCliCommand(
        scriptIdOrName: 'order-audit',
        clusterName: 'prod-kafka',
        variables: {'limit': '100', 'orderId': 'ORD-1234'},
        outputFilePath: '/tmp/result.json',
      );

      expect(cmd, contains('kafkalyzer script run'));
      expect(cmd, contains('--script "order-audit"'));
      expect(cmd, contains('--cluster "prod-kafka"'));
      expect(cmd, contains('--var limit="100"'));
      expect(cmd, contains('--var orderId="ORD-1234"'));
      expect(cmd, contains('--output "/tmp/result.json"'));
    });

    test(
      'resolveVariables handles provided variables and detects missing required variables',
      () {
        final script = Script(
          id: 's1',
          name: 'Test Script',
          steps: const [],
          variables: const [
            ScriptVariable(name: 'env'),
            ScriptVariable(name: 'limit'),
            ScriptVariable(name: 'customerId'),
          ],
        );

        final resolved = HeadlessScriptRunner.resolveVariables(
          script: script,
          providedVariables: {
            'env': 'prod',
            'limit': '200',
            'customerId': 'CUST-1',
          },
        );

        expect(resolved['env'], 'prod');
        expect(resolved['limit'], '200');
        expect(resolved['customerId'], 'CUST-1');
      },
    );

    test(
      'resolveVariables throws ArgumentError when required variables are missing',
      () {
        final script = Script(
          id: 's1',
          name: 'Test Script',
          steps: const [],
          variables: const [ScriptVariable(name: 'requiredField')],
        );

        expect(
          () => HeadlessScriptRunner.resolveVariables(
            script: script,
            providedVariables: {},
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Missing required script variables: requiredField'),
            ),
          ),
        );
      },
    );

    test(
      'run returns failure result with exitCode 2 when validation fails',
      () async {
        final runner = HeadlessScriptRunner(
          logger: Logger(printer: PrettyPrinter(methodCount: 0)),
        );

        final script = Script(
          id: 's1',
          name: 'Test Script',
          steps: const [],
          variables: const [ScriptVariable(name: 'mustProvide')],
        );

        final result = await runner.run(
          script: script,
          clusterProfile: const ClusterProfile(
            name: 'c',
            bootstrapServers: 'localhost:9092',
            tlsVerification: TlsVerification.enabled,
          ),
          variables: {},
        );

        expect(result.success, isFalse);
        expect(result.exitCode, 2);
        expect(
          result.errorMessage,
          contains('Missing required script variables'),
        );
      },
    );

    test('HeadlessRunResult.toJson omits null optional fields', () {
      const result = HeadlessRunResult(
        success: true,
        scriptName: 's',
        durationMs: 12,
        stepStatuses: {'a': 'ok'},
        extractedVariables: {'x': '1'},
        messageCounts: {'a': 3},
        exitCode: 0,
      );
      expect(result.toJson()['success'], isTrue);
      expect(result.toJson().containsKey('errorMessage'), isFalse);
      expect(result.toJson().containsKey('runId'), isFalse);
    });

    test('printUsage writes help text', () {
      final sink = StringBuffer();
      HeadlessScriptRunner.printUsage(sink);
      expect(sink.toString(), contains('kafkalyzer script run'));
    });

    test('run succeeds through substitute ScriptRunner', () async {
      final fake = _RecordingScriptRunner();
      final runner = HeadlessScriptRunner(
        runner: fake,
        logger: Logger(level: Level.off),
      );
      final script = Script(
        id: 's1',
        name: 'Ok Script',
        steps: const [
          ScriptStep(
            id: 's1',
            name: 'Step',
            clusterName: 'c',
            topicNames: ['orders'],
          ),
        ],
      );

      final result = await runner.run(
        script: script,
        clusterProfile: const ClusterProfile(
          name: 'c',
          bootstrapServers: 'localhost:9092',
          tlsVerification: TlsVerification.enabled,
        ),
        variables: {},
      );

      expect(result.success, isTrue);
      expect(result.exitCode, 0);
      expect(result.runId, 'run-ok');
      expect(result.messageCounts['s1_orders'], 2);
    });

    test('run returns exitCode 1 when substitute reports step error', () async {
      final fake = _RecordingScriptRunner(errorSteps: true);
      final runner = HeadlessScriptRunner(
        runner: fake,
        logger: Logger(level: Level.off),
      );
      final script = Script(
        id: 's1',
        name: 'Bad Script',
        steps: const [
          ScriptStep(
            id: 's1',
            name: 'Step',
            clusterName: 'c',
            topicNames: ['orders'],
          ),
        ],
      );

      final result = await runner.run(
        script: script,
        clusterProfile: const ClusterProfile(
          name: 'c',
          bootstrapServers: 'localhost:9092',
          tlsVerification: TlsVerification.enabled,
        ),
        variables: {},
      );

      expect(result.success, isFalse);
      expect(result.exitCode, 1);
      expect(result.errorMessage, contains('step blew up'));
    });

    test('run returns exitCode 3 when substitute throws', () async {
      final fake = _RecordingScriptRunner(throwOnRun: true);
      final runner = HeadlessScriptRunner(
        runner: fake,
        logger: Logger(level: Level.off),
      );
      final script = Script(id: 's1', name: 'Throw Script', steps: const []);

      final result = await runner.run(
        script: script,
        clusterProfile: const ClusterProfile(
          name: 'c',
          bootstrapServers: 'localhost:9092',
          tlsVerification: TlsVerification.enabled,
        ),
        variables: {},
      );

      expect(result.success, isFalse);
      expect(result.exitCode, 3);
      expect(result.errorMessage, contains('runner failed'));
    });

    test(
      'missing required variables abort before any container Kafka lookup',
      () async {
        await getIt.reset();
        final runner = HeadlessScriptRunner(logger: Logger(level: Level.off));
        final script = Script(
          id: 's1',
          name: 'Test Script',
          steps: const [
            ScriptStep(
              id: 'step-1',
              name: 'Step',
              clusterName: 'c',
              topicNames: ['orders'],
            ),
          ],
          variables: const [ScriptVariable(name: 'mustProvide')],
        );

        final result = await runner.run(
          script: script,
          clusterProfile: const ClusterProfile(
            name: 'c',
            bootstrapServers: 'localhost:9092',
            tlsVerification: TlsVerification.enabled,
          ),
          variables: {},
        );

        expect(result.success, isFalse);
        expect(result.exitCode, isNonZero);
        expect(getIt.isRegistered<Logger>(), isFalse);
      },
    );

    test(
      'runFromArgs reports unreadable cluster profiles and returns non-zero',
      () async {
        await getIt.reset();
        getIt.registerSingleton<ClusterService>(_UnreadableClusterService());

        final err = StringBuffer();
        final exitCode = await HeadlessScriptRunner.runCli(
          ['--script', 'my-script', '--cluster', 'prod'],
          stderrSink: err,
          stdoutSink: StringBuffer(),
          shouldExit: false,
        );

        expect(exitCode, isNonZero);
        expect(err.toString(), contains('cluster profiles could not be read'));
        expect(err.toString(), isNot(contains('not found')));
      },
    );

    test(
      'runCli reports unreadable script store and returns non-zero',
      () async {
        await getIt.reset();
        getIt.registerSingleton<ScriptRepository>(
          _UnreadableScriptRepository(),
        );

        final err = StringBuffer();
        final exitCode = await HeadlessScriptRunner.runCli(
          ['--script', 'my-script', '--cluster', 'prod'],
          clusterOverride: const ClusterProfile(
            name: 'prod',
            bootstrapServers: 'localhost:9092',
            tlsVerification: TlsVerification.enabled,
          ),
          stderrSink: err,
          stdoutSink: StringBuffer(),
          shouldExit: false,
        );

        expect(exitCode, isNonZero);
        expect(err.toString(), contains('script store could not be read'));
        expect(err.toString(), isNot(contains('not found')));
      },
    );
  });
}

class _UnreadableClusterService extends ClusterService {
  @override
  Future<List<ClusterProfile>> loadClusters() async {
    throw StoredDataUnreadableException('cluster_profiles');
  }
}

class _UnreadableScriptRepository extends ScriptRepository {
  @override
  Future<List<Script>> getScripts() async {
    throw StoredDataUnreadableException('saved_scripts_v1');
  }
}
