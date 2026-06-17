import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';

void main() {
  group('ScriptRun', () {
    test('fromJson creates correct instance', () {
      final json = {
        'id': 'test_id',
        'scriptName': 'Test Script',
        'timestamp': 1234567890,
        'parameters': {'key': 'value'},
        'status': 'completed',
        'path': '/tmp/test',
        'clusterName': 'dev',
      };

      final run = ScriptRun.fromJson(json);

      expect(run.id, 'test_id');
      expect(run.scriptName, 'Test Script');
      expect(run.timestamp, 1234567890);
      expect(run.parameters, {'key': 'value'});
      expect(run.status, ScriptRunStatus.completed);
      expect(run.path, '/tmp/test');
      expect(run.clusterName, 'dev');
    });

    test('copyWith creates new instance with updated fields', () {
      const run = ScriptRun(
        id: 'test_id',
        scriptName: 'Test Script',
        timestamp: 1234567890,
        parameters: {},
        status: ScriptRunStatus.running,
        path: '/tmp/test',
      );

      final updatedRun = run.copyWith(
        status: ScriptRunStatus.completed,
        path: '/new/path',
      );

      expect(updatedRun.id, 'test_id');
      expect(updatedRun.status, ScriptRunStatus.completed);
      expect(updatedRun.path, '/new/path');
      expect(updatedRun.scriptName, 'Test Script'); // Unchanged
    });
  });
}
