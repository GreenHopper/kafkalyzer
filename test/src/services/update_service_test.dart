import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/services/update_service.dart';
import 'package:logger/logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService', () {
    late UpdateService updateService;

    setUp(() {
      updateService = UpdateService(logger: Logger(level: Level.off));
    });

    test('default repository url is configured correctly', () {
      expect(
        UpdateService.defaultRepositoryUrl,
        'https://github.com/Protoss78/kafkalyzer',
      );
    });

    test(
      'initialization handles unpackaged/test environment gracefully without throwing',
      () async {
        expect(updateService.isInitialized, isFalse);
        // In a unit test environment, native bridge won't connect, but initialize() must not throw
        await updateService.initialize();
        // Should handle exception gracefully
      },
    );

    test(
      'isUpdateAvailable returns false when unpackaged or uninitialized',
      () async {
        final available = await updateService.isUpdateAvailable();
        expect(available, isFalse);
      },
    );

    test('getLatestUpdateInfo returns null when uninitialized', () async {
      final info = await updateService.getLatestUpdateInfo();
      expect(info, isNull);
    });

    test('getCurrentVersion returns null when uninitialized', () async {
      final version = await updateService.getCurrentVersion();
      expect(version, isNull);
    });
  });
}
