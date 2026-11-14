import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kafkalyzer/src/services/update_service.dart';
import 'package:logger/logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UpdateService createService({
    http.Client? client,
    String version = '1.4.0',
    Stream<int> Function()? downloadStreamFactory,
    Future<void> Function()? applyAndRestartFn,
  }) {
    return UpdateService(
      logger: Logger(level: Level.off),
      httpClient: client ?? MockClient((_) async => http.Response('{}', 500)),
      currentVersionProvider: () => version,
      downloadStreamFactory: downloadStreamFactory,
      applyAndRestartFn: applyAndRestartFn,
      isDebugMode: () => false,
    );
  }

  group('UpdateService', () {
    test('default repository and releases URLs are configured correctly', () {
      expect(
        UpdateService.defaultRepositoryUrl,
        'https://github.com/GreenHopper/kafkalyzer',
      );
      expect(
        UpdateService.releasesUrl,
        'https://github.com/GreenHopper/kafkalyzer/releases',
      );
    });

    test(
      'initialization handles unpackaged/test environment gracefully',
      () async {
        final service = createService();
        addTearDown(service.dispose);
        expect(service.isInitialized, isFalse);
        await service.initialize();
      },
    );

    test('getCurrentVersion returns null when uninitialized', () async {
      final service = createService();
      addTearDown(service.dispose);
      expect(await service.getCurrentVersion(), isNull);
    });
  });

  group('GitHub releases/latest lookup (Task 7.1)', () {
    test('newer tag yields manualUpdateAvailable with safe releaseUrl', () async {
      final client = MockClient((req) async {
        expect(req.url.toString(), UpdateService.latestReleaseApiUrl);
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.5.0',
            'html_url':
                'https://github.com/GreenHopper/kafkalyzer/releases/tag/v1.5.0',
            'body': 'New features',
          }),
          200,
        );
      });
      final service = createService(client: client, version: '1.4.0');
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();
      expect(result.status, UpdateCheckStatus.manualUpdateAvailable);
      expect(result.latestVersion, '1.5.0');
      expect(
        result.releaseUrl,
        'https://github.com/GreenHopper/kafkalyzer/releases/tag/v1.5.0',
      );
      expect(result.releaseNotes, 'New features');
      expect(result.canAutoApply, isFalse);
      expect(result.isUpdateAvailable, isTrue);
    });

    test('equal tag yields manualUpToDate', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'tag_name': 'v1.4.0'}), 200),
      );
      final service = createService(client: client, version: '1.4.0');
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();
      expect(result.status, UpdateCheckStatus.manualUpToDate);
      expect(result.isUpdateAvailable, isFalse);
    });

    test('older tag yields manualUpToDate', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'tag_name': 'v1.3.9'}), 200),
      );
      final service = createService(client: client, version: '1.4.0');
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();
      expect(result.status, UpdateCheckStatus.manualUpToDate);
    });

    test(
      'dev suffix 1.4.0-dev3.abc+3 vs 1.4.0 compares major.minor.patch as equal',
      () async {
        final client = MockClient(
          (_) async => http.Response(jsonEncode({'tag_name': 'v1.4.0'}), 200),
        );
        final service = createService(
          client: client,
          version: '1.4.0-dev3.abc+3',
        );
        addTearDown(service.dispose);

        final result = await service.checkForUpdates();
        expect(result.status, UpdateCheckStatus.manualUpToDate);
      },
    );

    test('unparseable DEV running version yields latestKnown', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'tag_name': 'v1.5.0'}), 200),
      );
      final service = createService(client: client, version: 'DEV');
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();
      expect(result.status, UpdateCheckStatus.latestKnown);
      expect(result.latestVersion, '1.5.0');
    });

    test('foreign html_url falls back to releasesUrl allowlist', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'tag_name': 'v1.5.0',
            'html_url': 'https://evil.example.com/phishing',
          }),
          200,
        ),
      );
      final service = createService(client: client, version: '1.4.0');
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();
      expect(result.releaseUrl, UpdateService.releasesUrl);
    });

    test('HTTP 403 rate limit yields failed, never upToDate', () async {
      final client = MockClient((_) async => http.Response('rate limit', 403));
      final service = createService(client: client);
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();
      expect(result.status, UpdateCheckStatus.failed);
      expect(result.isUpdateAvailable, isFalse);
    });

    test('HTTP 500 yields failed', () async {
      final client = MockClient((_) async => http.Response('err', 500));
      final service = createService(client: client);
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();
      expect(result.status, UpdateCheckStatus.failed);
    });

    test('timeout yields failed', () async {
      final client = MockClient(
        (_) async => throw TimeoutException('timed out'),
      );
      final service = createService(client: client);
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();
      expect(result.status, UpdateCheckStatus.failed);
    });

    test('invalid JSON yields failed', () async {
      final client = MockClient((_) async => http.Response('{not-json', 200));
      final service = createService(client: client);
      addTearDown(service.dispose);

      final result = await service.checkForUpdates();
      expect(result.status, UpdateCheckStatus.failed);
    });
  });

  group('DownloadState and cancellation (Task 7.2)', () {
    test('progress updates, finishes, and allows applyAndRestart', () async {
      final controller = StreamController<int>();
      var applied = false;
      final service = createService(
        downloadStreamFactory: () => controller.stream,
        applyAndRestartFn: () async => applied = true,
      );
      addTearDown(service.dispose);

      service.startDownload();
      expect(service.downloadState.value.phase, DownloadPhase.running);
      expect(service.downloadState.value.progress, 0);

      controller.add(42);
      await Future<void>.delayed(Duration.zero);
      expect(service.downloadState.value.progress, 42);
      expect(service.downloadState.value.canApply, isFalse);

      await controller.close();
      await Future<void>.delayed(Duration.zero);
      expect(service.downloadState.value.phase, DownloadPhase.finished);
      expect(service.downloadState.value.canApply, isTrue);

      await service.applyAndRestart();
      expect(applied, isTrue);
    });

    test(
      'cancel marks cancelled, resets to idle on done, and blocks apply',
      () async {
        final controller = StreamController<int>();
        var applied = false;
        final service = createService(
          downloadStreamFactory: () => controller.stream,
          applyAndRestartFn: () async => applied = true,
        );
        addTearDown(service.dispose);

        service.startDownload();
        controller.add(25);
        await Future<void>.delayed(Duration.zero);

        service.cancelDownload();
        expect(service.downloadState.value.phase, DownloadPhase.running);
        expect(service.downloadState.value.cancelled, isTrue);

        await controller.close();
        await Future<void>.delayed(Duration.zero);
        expect(service.downloadState.value.phase, DownloadPhase.idle);
        expect(service.downloadState.value.canApply, isFalse);
        await expectLater(service.applyAndRestart(), throwsStateError);
        expect(applied, isFalse);
      },
    );

    test(
      'second startDownload during cancelled transfer reattaches without new stream',
      () async {
        final controller = StreamController<int>();
        var factoryCalls = 0;
        final service = createService(
          downloadStreamFactory: () {
            factoryCalls++;
            return controller.stream;
          },
        );
        addTearDown(service.dispose);

        service.startDownload();
        controller.add(50);
        await Future<void>.delayed(Duration.zero);

        service.cancelDownload();
        expect(service.downloadState.value.cancelled, isTrue);

        service.startDownload();
        expect(factoryCalls, 1);
        expect(service.downloadState.value.phase, DownloadPhase.running);
        expect(service.downloadState.value.cancelled, isFalse);

        await controller.close();
        await Future<void>.delayed(Duration.zero);
        expect(service.downloadState.value.phase, DownloadPhase.finished);
      },
    );

    test('stream error transitions to failed', () async {
      final controller = StreamController<int>();
      final service = createService(
        downloadStreamFactory: () => controller.stream,
      );
      addTearDown(service.dispose);

      service.startDownload();
      controller.addError(Exception('network drop'));
      await controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(service.downloadState.value.phase, DownloadPhase.failed);
      expect(
        service.downloadState.value.errorMessage,
        contains('network drop'),
      );
    });
  });
}
