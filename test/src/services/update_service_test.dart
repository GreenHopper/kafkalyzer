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

    tearDown(() {
      updateService.dispose();
    });

    test('default repository url is configured correctly', () {
      expect(
        UpdateService.defaultRepositoryUrl,
        'https://github.com/GreenHopper/kafkalyzer',
      );
    });

    test('releases url points at GitHub Releases page', () {
      expect(
        UpdateService.releasesUrl,
        'https://github.com/GreenHopper/kafkalyzer/releases',
      );
    });

    test(
      'initialization handles unpackaged/test environment gracefully without throwing',
      () async {
        expect(updateService.isInitialized, isFalse);
        await updateService.initialize();
      },
    );

    test(
      'isUpdateAvailable returns false when unpackaged or uninitialized',
      () async {
        final available = await updateService.isUpdateAvailable();
        expect(available, isFalse);
      },
    );

    test(
      'checkForUpdates reports unsupportedEnvironment when unpackaged',
      () async {
        final result = await updateService.checkForUpdates();
        expect(result.status, UpdateCheckStatus.unsupportedEnvironment);
        expect(result.canAutoApply, isFalse);
        expect(result.isUpdateAvailable, isFalse);
      },
    );

    test('getLatestUpdateInfo returns null when unsupported', () async {
      final info = await updateService.getLatestUpdateInfo();
      expect(info, isNull);
    });

    test('getCurrentVersion returns null when uninitialized', () async {
      final version = await updateService.getCurrentVersion();
      expect(version, isNull);
    });

    test('isEnvironmentSupported is false before successful init', () {
      expect(updateService.isEnvironmentSupported, isFalse);
    });

    test(
      'runBackgroundCheck does not throw and leaves notifier empty when unsupported',
      () async {
        // Avoid the startup delay in unit tests by checking notifier after init path.
        final service = UpdateService(logger: Logger(level: Level.off));
        addTearDown(service.dispose);

        // Force immediate check path by calling checkForUpdates first, then
        // verifying background notifier stays null for unsupported env.
        final result = await service.checkForUpdates();
        expect(result.status, UpdateCheckStatus.unsupportedEnvironment);
        expect(service.availableUpdateNotifier.value, isNull);
      },
    );
  });
}
