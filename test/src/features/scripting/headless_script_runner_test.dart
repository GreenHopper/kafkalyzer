import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/scripting/application/headless_script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:logger/logger.dart';

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
  });
}
