import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/update_dialog.dart';
import 'package:kafkalyzer/src/services/update_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:velopack_flutter/velopack_flutter.dart'
    show UpdateInfo, VelopackAsset;

class _FakeUpdateService extends UpdateService {
  _FakeUpdateService({required this.checkResult, super.downloadStreamFactory});

  UpdateCheckResult checkResult;
  bool cancelCalled = false;

  @override
  Future<UpdateCheckResult> checkForUpdates() async => checkResult;

  @override
  void cancelDownload() {
    cancelCalled = true;
    super.cancelDownload();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await GetIt.instance.reset();
  });

  Widget buildApp({required Widget child}) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );
  }

  group('UpdateDialog (Task 7.3)', () {
    testWidgets(
      'renders manualUpdateAvailable with Open release page and no Download',
      (tester) async {
        final service = _FakeUpdateService(
          checkResult: const UpdateCheckResult(
            status: UpdateCheckStatus.manualUpdateAvailable,
            latestVersion: '1.5.0',
            releaseUrl:
                'https://github.com/GreenHopper/kafkalyzer/releases/tag/v1.5.0',
            releaseNotes: 'Bug fixes and improvements',
            canAutoApply: false,
          ),
        );
        GetIt.instance.registerSingleton<UpdateService>(service);

        await tester.pumpWidget(buildApp(child: const UpdateDialog()));
        await tester.pumpAndSettle();

        expect(find.text('Version 1.5.0 available'), findsOneWidget);
        expect(find.text('Bug fixes and improvements'), findsOneWidget);
        expect(find.text('Open release page'), findsOneWidget);
        expect(find.text('Download Update'), findsNothing);
      },
    );

    testWidgets('renders manualUpToDate', (tester) async {
      final service = _FakeUpdateService(
        checkResult: const UpdateCheckResult(
          status: UpdateCheckStatus.manualUpToDate,
          latestVersion: '1.4.0',
          canAutoApply: false,
        ),
      );
      GetIt.instance.registerSingleton<UpdateService>(service);

      await tester.pumpWidget(buildApp(child: const UpdateDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Open release page'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(
        find.textContaining('Automatic updates are not available'),
        findsOneWidget,
      );
    });

    testWidgets('renders latestKnown', (tester) async {
      final service = _FakeUpdateService(
        checkResult: const UpdateCheckResult(
          status: UpdateCheckStatus.latestKnown,
          latestVersion: '1.5.0',
          canAutoApply: false,
        ),
      );
      GetIt.instance.registerSingleton<UpdateService>(service);

      await tester.pumpWidget(buildApp(child: const UpdateDialog()));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Latest release on GitHub: 1.5.0. Running version could not be compared.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open release page'), findsOneWidget);
    });

    testWidgets('renders auto updateAvailable with Download', (tester) async {
      final service = _FakeUpdateService(
        checkResult: UpdateCheckResult(
          status: UpdateCheckStatus.updateAvailable,
          canAutoApply: true,
          updateInfo: UpdateInfo(
            targetFullRelease: VelopackAsset(
              packageId: 'kafkalyzer',
              version: '2.0.0',
              type: 'Full',
              fileName: 'kafkalyzer-2.0.0.nupkg',
              sha1: 'abc',
              sha256: 'def',
              size: BigInt.from(10),
              notesMarkdown: 'Auto notes',
              notesHtml: '',
            ),
            deltasToTarget: const [],
            isDowngrade: false,
          ),
        ),
      );
      GetIt.instance.registerSingleton<UpdateService>(service);

      await tester.pumpWidget(buildApp(child: const UpdateDialog()));
      await tester.pumpAndSettle();

      expect(find.textContaining('v2.0.0'), findsOneWidget);
      expect(find.text('Auto notes'), findsOneWidget);
      expect(find.text('Download Update'), findsOneWidget);
    });

    testWidgets('renders upToDate', (tester) async {
      final service = _FakeUpdateService(
        checkResult: const UpdateCheckResult(
          status: UpdateCheckStatus.upToDate,
          canAutoApply: true,
        ),
      );
      GetIt.instance.registerSingleton<UpdateService>(service);
      await tester.pumpWidget(buildApp(child: const UpdateDialog()));
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('renders unsupportedEnvironment', (tester) async {
      final service = _FakeUpdateService(
        checkResult: const UpdateCheckResult(
          status: UpdateCheckStatus.unsupportedEnvironment,
          canAutoApply: false,
        ),
      );
      GetIt.instance.registerSingleton<UpdateService>(service);
      await tester.pumpWidget(buildApp(child: const UpdateDialog()));
      await tester.pumpAndSettle();
      expect(find.text('Open GitHub Releases'), findsOneWidget);
    });

    testWidgets('renders failed check and retry action', (tester) async {
      final service = _FakeUpdateService(
        checkResult: const UpdateCheckResult(
          status: UpdateCheckStatus.failed,
          errorMessage: 'network down',
          canAutoApply: false,
        ),
      );
      GetIt.instance.registerSingleton<UpdateService>(service);

      await tester.pumpWidget(buildApp(child: const UpdateDialog()));
      await tester.pumpAndSettle();

      expect(find.textContaining('network down'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('readyToRestart shows Restart Now', (tester) async {
      final service = _FakeUpdateService(
        checkResult: const UpdateCheckResult(
          status: UpdateCheckStatus.upToDate,
        ),
      );
      service.downloadState.value = const DownloadState(
        phase: DownloadPhase.finished,
        progress: 100,
      );
      GetIt.instance.registerSingleton<UpdateService>(service);

      await tester.pumpWidget(buildApp(child: const UpdateDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Restart Now'), findsOneWidget);
    });

    testWidgets('cancel during download closes dialog and shows SnackBar', (
      tester,
    ) async {
      final controller = StreamController<int>();
      addTearDown(controller.close);

      final service = _FakeUpdateService(
        checkResult: const UpdateCheckResult(
          status: UpdateCheckStatus.manualUpToDate,
        ),
        downloadStreamFactory: () => controller.stream,
      );
      GetIt.instance.registerSingleton<UpdateService>(service);

      // Start download so dialog opens directly in downloading state
      service.startDownload();
      controller.add(35);

      await tester.pumpWidget(
        buildApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => UpdateDialog.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('(35%)'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.cancelCalled, isTrue);
      expect(find.byType(UpdateDialog), findsNothing);
      expect(
        find.text('Download cancelled. The update will not be installed.'),
        findsOneWidget,
      );
    });
  });
}
