import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/update_dialog.dart';
import 'package:kafkalyzer/src/services/update_service.dart';
import 'package:material_ui/material_ui.dart';

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
