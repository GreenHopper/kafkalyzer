import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/services/session_restore_service.dart';

void main() {
  late SessionRestoreService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = SessionRestoreService();
  });

  group('SessionRestoreService', () {
    test(
      'isRestorationEnabled defaults to true and persists toggles',
      () async {
        expect(await service.isRestorationEnabled(), isTrue);

        await service.setRestorationEnabled(false);
        expect(await service.isRestorationEnabled(), isFalse);

        await service.setRestorationEnabled(true);
        expect(await service.isRestorationEnabled(), isTrue);
      },
    );

    test('returns null when no session is stored for cluster', () async {
      final session = await service.getSession('prod-cluster');
      expect(session, isNull);
    });

    test('saves and restores cluster tab session', () async {
      await service.saveSession(
        'prod-cluster',
        openTopicNames: ['orders', 'customers', 'payments'],
        activeTopicName: 'customers',
      );

      final session = await service.getSession('prod-cluster');
      expect(session, isNotNull);
      expect(session!.clusterName, 'prod-cluster');
      expect(session.openTopicNames, ['orders', 'customers', 'payments']);
      expect(session.activeTopicName, 'customers');

      // Other cluster remains unaffected
      final other = await service.getSession('dev-cluster');
      expect(other, isNull);
    });

    test('clears cluster tab session', () async {
      await service.saveSession(
        'prod-cluster',
        openTopicNames: ['orders'],
        activeTopicName: 'orders',
      );

      expect(await service.getSession('prod-cluster'), isNotNull);

      await service.clearSession('prod-cluster');
      expect(await service.getSession('prod-cluster'), isNull);
    });
  });
}
