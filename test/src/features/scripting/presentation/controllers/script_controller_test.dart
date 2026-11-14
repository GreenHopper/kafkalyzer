import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:flutter_test/flutter_test.dart';

class MockScriptRepository implements ScriptRepository {
  final List<Script> _storage = [];
  StoreStatus _status = const StoreStatus.ok();
  bool throwUnreadable = false;

  @override
  StoreStatus get storeStatus => _status;

  @override
  Future<void> discardUnreadable() async {
    throwUnreadable = false;
    _status = const StoreStatus.ok();
  }

  @override
  Future<List<Script>> getScripts() async {
    if (throwUnreadable) {
      _status = const StoreStatus.unreadable('/tmp/backup.json');
      throw StoredDataUnreadableException(
        'saved_scripts_v1',
        backupPath: '/tmp/backup.json',
      );
    }
    return List.from(_storage); // Return copy
  }

  @override
  Future<void> saveScript(Script script) async {
    final index = _storage.indexWhere((s) => s.id == script.id);
    if (index >= 0) {
      _storage[index] = script;
    } else {
      _storage.add(script);
    }
  }

  @override
  Future<void> deleteScript(String id) async {
    _storage.removeWhere((s) => s.id == id);
  }
}

void main() {
  late ScriptController controller;
  late MockScriptRepository mockRepository;

  setUp(() async {
    await getIt.reset();
    mockRepository = MockScriptRepository();
    getIt.registerSingleton<ScriptRepository>(mockRepository);

    controller = ScriptController();
    // Wait for initial load
    await Future.delayed(Duration.zero);
  });

  test(
    'duplicateScript duplicates the script with new ID and name suffix',
    () async {
      final originalScript = Script(
        id: 'original-id',
        name: 'Test Script',
        steps: [],
      );

      // Setup initial state
      await mockRepository.saveScript(originalScript);
      await controller.loadScripts();

      expect(controller.scripts.length, 1);

      await controller.duplicateScript(originalScript);

      // Verify
      final scripts = await mockRepository.getScripts();
      expect(scripts.length, 2);

      final duplicatedScript = scripts.firstWhere(
        (s) => s.id != originalScript.id,
      );

      expect(duplicatedScript.id, isNot(equals(originalScript.id)));
      expect(duplicatedScript.name, equals('Test Script (Copy)'));
      expect(duplicatedScript.steps, equals(originalScript.steps));

      // Also check controller state updated
      expect(controller.scripts.length, 2);
      expect(
        controller.scripts.any((s) => s.name == 'Test Script (Copy)'),
        isTrue,
      );
    },
  );

  test('loadScripts sorts scripts alphabetically by name', () async {
    final scripts = [
      Script(id: '1', name: 'Zebra', steps: []),
      Script(id: '2', name: 'apple', steps: []),
      Script(id: '3', name: 'Banana', steps: []),
    ];

    for (final script in scripts) {
      await mockRepository.saveScript(script);
    }

    await controller.loadScripts();

    expect(controller.scripts.length, 3);
    expect(controller.scripts[0].name, equals('apple'));
    expect(controller.scripts[1].name, equals('Banana'));
    expect(controller.scripts[2].name, equals('Zebra'));
  });

  test(
    'refuses mutations while store is unreadable and allows discard',
    () async {
      mockRepository.throwUnreadable = true;
      await controller.loadScripts();

      expect(controller.storeStatus.isUnreadable, isTrue);
      expect(controller.scripts, isEmpty);

      const script = Script(id: '1', name: 'A');
      await expectLater(
        controller.createScript('New'),
        throwsA(isA<StoredDataUnreadableException>()),
      );
      await expectLater(
        controller.saveScript(script),
        throwsA(isA<StoredDataUnreadableException>()),
      );
      await expectLater(
        controller.duplicateScript(script),
        throwsA(isA<StoredDataUnreadableException>()),
      );
      await expectLater(
        controller.deleteScript('1'),
        throwsA(isA<StoredDataUnreadableException>()),
      );
      await expectLater(
        controller.importScripts('[]'),
        throwsA(isA<StoredDataUnreadableException>()),
      );

      await controller.discardUnreadable();
      expect(controller.storeStatus.isOk, isTrue);
      await controller.createScript('Recovered');
      expect(controller.scripts.map((s) => s.name), ['Recovered']);
    },
  );
}
