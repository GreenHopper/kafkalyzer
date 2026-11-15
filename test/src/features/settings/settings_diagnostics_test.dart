import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/settings/presentation/settings_view.dart';
import 'package:kafkalyzer/src/services/diagnostics/app_logging.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_reporter.dart';
import 'package:kafkalyzer/src/services/file_opener_service.dart';
import 'package:kafkalyzer/src/services/session_restore_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:kafkalyzer/src/services/update_service.dart';
import 'package:kafkalyzer/src/utils/app_version_helper.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'presentation/settings_view_test.mocks.dart';

class _FakeFileOpenerService extends FileOpenerService {
  _FakeFileOpenerService() : super(logger: Logger());

  bool result = true;
  String? lastPath;

  @override
  Future<bool> showInFolder(String path) async {
    lastPath = path;
    return result;
  }
}

void main() {
  late MockClusterListController mockClusterListController;
  late MockActiveConnectionController mockActiveConnectionController;
  late MockSettingsService mockSettingsService;
  late _FakeFileOpenerService fakeFileOpener;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'general_default_output_dir': '/tmp/kafkalyzer-out',
    });
    await AppLogging.resetForTest();

    mockClusterListController = MockClusterListController();
    mockActiveConnectionController = MockActiveConnectionController();
    mockSettingsService = MockSettingsService();
    fakeFileOpener = _FakeFileOpenerService();

    when(mockClusterListController.clusters).thenReturn(const []);
    when(mockClusterListController.isLoading).thenReturn(false);
    when(
      mockClusterListController.storeStatus,
    ).thenReturn(const StoreStatus.ok());
    when(mockActiveConnectionController.activeProfile).thenReturn(null);

    final getIt = GetIt.instance;
    await getIt.reset();
    getIt.registerSingleton<ClusterListController>(mockClusterListController);
    getIt.registerSingleton<ActiveConnectionController>(
      mockActiveConnectionController,
    );
    getIt.registerSingleton<SettingsService>(mockSettingsService);
    getIt.registerSingleton<SessionRestoreService>(SessionRestoreService());
    getIt.registerSingleton<FileOpenerService>(fakeFileOpener);
    getIt.registerSingleton<ErrorReporter>(ErrorReporter());
  });

  tearDown(() async {
    await AppLogging.resetForTest();
    await GetIt.instance.reset();
  });

  Widget buildApp() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SettingsView()),
    );
  }

  testWidgets(
    'Diagnostics section opens log folder (success/failure) and copies report',
    (tester) async {
      late Directory tempDir;
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('settings_diag_');
        await AppLogging.init(headless: false, logsDirOverride: tempDir);
      });
      addTearDown(() async {
        await AppLogging.resetForTest();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(find.text('Diagnostics'), findsOneWidget);
      expect(find.textContaining('kafkalyzer.log'), findsOneWidget);

      await tester.ensureVisible(find.text('Open log folder'));
      await tester.tap(find.text('Open log folder'));
      await tester.pumpAndSettle();
      expect(fakeFileOpener.lastPath, AppLogging.fileLogPath);

      fakeFileOpener.result = false;
      await tester.tap(find.text('Open log folder'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not open log folder at'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Copy diagnostics'));
      await tester.tap(find.text('Copy diagnostics'));
      await tester.pumpAndSettle();
      expect(copiedText, contains('Kafkalyzer Diagnostics Report'));
      expect(
        find.text('Diagnostics report copied to clipboard'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'About Kafkalyzer dialog shows version, repository link, 3 paths, and opens licenses',
    (tester) async {
      late Directory tempDir;
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('settings_about_');
        await AppLogging.init(headless: false, logsDirOverride: tempDir);
      });
      addTearDown(() async {
        await AppLogging.resetForTest();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async {
          if (call.method == 'getApplicationSupportDirectory') {
            return '/tmp/kafkalyzer-support';
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
      });

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final aboutFinder = find.text('About Kafkalyzer');
      await tester.scrollUntilVisible(
        aboutFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(aboutFinder);
      // About dialog resolves path_provider / prefs before showing.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AboutDialog), findsOneWidget);
      expect(
        find.textContaining(AppVersionHelper.version),
        findsAtLeastNWidgets(1),
      );
      expect(find.text(UpdateService.defaultRepositoryUrl), findsOneWidget);
      expect(find.textContaining('Log folder:'), findsOneWidget);
      expect(find.textContaining('Settings and data folder:'), findsOneWidget);
      expect(find.textContaining('Default output folder:'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AboutDialog),
          matching: find.text('/tmp/kafkalyzer-out'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('View licenses'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    },
  );
}
