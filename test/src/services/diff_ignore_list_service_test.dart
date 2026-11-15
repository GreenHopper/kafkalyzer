import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/services/diff_ignore_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingSavePrefs implements SharedPreferences {
  final Map<String, Object> _store = {};

  @override
  Object? get(String key) => _store[key];

  @override
  Future<bool> setStringList(String key, List<String> value) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('per-topic isolation and persist/reload', () async {
    final prefs = await SharedPreferences.getInstance();
    final service1 = DiffIgnoreListService(prefs: prefs);

    expect(
      await service1.addPath('orders', 'updatedAt'),
      DiffIgnoreSaveStatus.saved,
    );
    expect(
      await service1.addPath('payments', 'traceId'),
      DiffIgnoreSaveStatus.saved,
    );

    final service2 = DiffIgnoreListService(prefs: prefs);
    final orders = await service2.load('orders');
    final payments = await service2.load('payments');

    expect(orders.unreadable, isFalse);
    expect(orders.paths, ['updatedAt']);
    expect(payments.paths, ['traceId']);
  });

  test('rejects empty and duplicate paths', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = DiffIgnoreListService(prefs: prefs);

    expect(
      await service.addPath('orders', '   '),
      DiffIgnoreSaveStatus.emptyPath,
    );
    expect(
      await service.addPath('orders', '  ts  '),
      DiffIgnoreSaveStatus.saved,
    );
    expect(
      await service.addPath('orders', 'ts'),
      DiffIgnoreSaveStatus.duplicate,
    );
    expect(service.getPathsSync('orders'), ['ts']);
  });

  test('reports wrong-typed stored value and does not overwrite it', () async {
    SharedPreferences.setMockInitialValues({
      DiffIgnoreListService.storageKey('orders'): 'not-a-list',
    });
    final prefs = await SharedPreferences.getInstance();
    final service = DiffIgnoreListService(prefs: prefs);

    final result = await service.load('orders');
    expect(result.unreadable, isTrue);
    expect(result.paths, isEmpty);
    expect(service.hasLoadError('orders'), isTrue);
    // Original stored value is preserved until user explicitly edits
    expect(prefs.get(DiffIgnoreListService.storageKey('orders')), 'not-a-list');
  });

  test('reports failing save without mutating cache', () async {
    final service = DiffIgnoreListService(prefs: _FailingSavePrefs());

    final status = await service.addPath('orders', 'ts');
    expect(status, DiffIgnoreSaveStatus.saveFailed);
    expect(service.getPathsSync('orders'), isEmpty);
  });
}
