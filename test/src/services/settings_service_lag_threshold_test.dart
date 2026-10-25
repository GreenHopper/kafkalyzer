import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kafkalyzer/src/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('lag warning threshold', () {
    test('is disabled when never stored', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SettingsService();

      expect(await service.lagWarnThreshold(), 0);
    });

    test('round-trips through shared_preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SettingsService();

      await service.setLagWarnThreshold(5000);

      expect(await service.lagWarnThreshold(), 5000);
      expect(
        (await SharedPreferences.getInstance()).getInt(
          SettingsService.lagWarnThresholdKey,
        ),
        5000,
      );
    });

    test('a negative threshold disables the warning', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SettingsService();

      await service.setLagWarnThreshold(-1);

      expect(await service.lagWarnThreshold(), 0);
    });
  });
}
