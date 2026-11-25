import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/read_only_guidance_dialog.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/features/settings/presentation/settings_view.dart';
import 'package:kafkalyzer/src/rust/api/profile_crypto.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/appearance_settings.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/services/session_restore_service.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_analysis_history_service.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/utils/archive_safety.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

import '../../../rust/api/rust_mocks.mocks.dart';

@GenerateMocks([
  ClusterListController,
  ActiveConnectionController,
  SettingsService,
  ScriptController,
])
import 'settings_view_test.mocks.dart';

class _FakeFilePicker extends FilePickerPlatform {
  FilePickerResult? pickResult;
  List<String>? lastAllowedExtensions;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    lastAllowedExtensions = allowedExtensions;
    return pickResult;
  }
}

void main() {
  late MockClusterListController mockClusterListController;
  late MockActiveConnectionController mockActiveConnectionController;
  late MockSettingsService mockSettingsService;
  late MockScriptController mockScriptController;

  final testProfile = ClusterProfile(
    name: 'test-cluster',
    bootstrapServers: 'localhost:9092',
    schemaRegistryUrl: 'http://localhost:8081',
    securityProtocol: 'plaintext',
    mechanism: 'plain',
    tlsVerification: TlsVerification.enabled,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'general_default_output_dir': '/tmp',
      'scripting_max_run_history': 50,
      'consumer_max_concurrent_queries': 10,
    });

    mockClusterListController = MockClusterListController();
    mockActiveConnectionController = MockActiveConnectionController();
    mockSettingsService = MockSettingsService();
    mockScriptController = MockScriptController();
    when(
      mockClusterListController.sharedProfilesStatus,
    ).thenReturn(ValueNotifier(const SharedProfilesStatus.ok()));

    final getIt = GetIt.instance;
    getIt.registerSingleton<ClusterListController>(mockClusterListController);
    getIt.registerSingleton<ActiveConnectionController>(
      mockActiveConnectionController,
    );
    getIt.registerSingleton<SettingsService>(mockSettingsService);
    getIt.registerSingleton<ScriptController>(mockScriptController);
    getIt.registerSingleton<SessionRestoreService>(SessionRestoreService());
    getIt.registerSingleton<AppearanceSettings>(AppearanceSettings());
    getIt.registerSingleton<TopicAnalysisHistoryService>(
      TopicAnalysisHistoryService(
        supportDirectoryProvider: () async => Directory.systemTemp,
      ),
    );
    when(mockSettingsService.writeInt(any, any)).thenAnswer((invocation) async {
      final setting = invocation.positionalArguments[0] as IntSetting;
      final value = invocation.positionalArguments[1] as int;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(setting.key, value);
    });
  });

  Widget createWidgetUnderTest({Locale? locale}) {
    return MaterialApp(
      locale: locale,
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: InkRipple.splashFactory,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsView(),
    );
  }

  group('SettingsView', () {
    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders general settings', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Default Script Output Directory'), findsOneWidget);
      expect(find.text('/tmp'), findsOneWidget);
      expect(find.text('Max Script Runs to keep'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('max_run_history_field')),
          matching: find.text('50'),
        ),
        findsOneWidget,
      );
      expect(find.text('Maximum Concurrent Lag Queries'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('max_concurrent_lag_queries_field')),
          matching: find.text('10'),
        ),
        findsOneWidget,
      );
      await scrollTo(tester, find.text('Restore open tabs on startup'));
      expect(find.text('Restore open tabs on startup'), findsOneWidget);
    });

    testWidgets('toggles restore open tabs on startup setting', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(const Key('restore_open_tabs_switch'));
      await scrollTo(tester, switchFinder);
      expect(switchFinder, findsOneWidget);

      final sessionService = GetIt.instance<SessionRestoreService>();
      expect(await sessionService.isRestorationEnabled(), isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(await sessionService.isRestorationEnabled(), isFalse);
    });

    testWidgets('allows changing maximum concurrent queries setting', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Maximum Concurrent Lag Queries',
      );
      expect(textFieldFinder, findsOneWidget);

      await tester.enterText(textFieldFinder, '15');
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('consumer_max_concurrent_queries'), 15);
    });

    testWidgets('renders configuration buttons', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Configuration'));
      expect(find.text('Configuration'), findsOneWidget);
      expect(find.text('Export Configuration'), findsOneWidget);
      expect(find.text('Import Configuration'), findsOneWidget);
    });

    testWidgets('renders cluster list', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Cluster Configuration'));
      await scrollTo(tester, find.text('Schema Registry'));

      expect(find.text('Cluster Configuration'), findsOneWidget);
      expect(find.text('test-cluster'), findsOneWidget);
      expect(find.text('localhost:9092'), findsOneWidget);
      expect(find.text('plaintext'), findsOneWidget);
      expect(find.text('Schema Registry'), findsOneWidget);
    });

    testWidgets('calls export configuration', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      when(
        mockSettingsService.exportConfiguration(
          dialogTitle: anyNamed('dialogTitle'),
          encryptionPassphrase: anyNamed('encryptionPassphrase'),
        ),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Export Configuration'));
      await tester.tap(find.text('Export Configuration'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Export'));
      await tester.pumpAndSettle();

      verify(
        mockSettingsService.exportConfiguration(
          dialogTitle: anyNamed('dialogTitle'),
          encryptionPassphrase: null,
        ),
      ).called(1);
    });
    testWidgets('shows add cluster dialog on tap', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Add Cluster'));
      await tester.tap(find.text('Add Cluster'));
      await tester.pumpAndSettle();

      expect(find.text('Add Cluster'), findsNWidgets(2));
    });

    testWidgets('shows delete confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await scrollTo(tester, find.byIcon(Icons.delete_outline));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete Cluster'), findsOneWidget);
      expect(
        find.text('Are you sure you want to delete test-cluster?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(mockClusterListController.deleteCluster(0)).called(1);
    });

    testWidgets('renders ReadOnlySecurityBadge in about section', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await scrollTo(tester, find.byType(ReadOnlySecurityBadge));

      expect(find.byType(ReadOnlySecurityBadge), findsOneWidget);
      expect(find.text('Read-Only'), findsOneWidget);
    });

    testWidgets('shows unsafe entry error SnackBar on configuration import', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);
      when(
        mockSettingsService.importConfiguration(
          dialogTitle: anyNamed('dialogTitle'),
          promptPassphrase: anyNamed('promptPassphrase'),
          onClusterConflict: anyNamed('onClusterConflict'),
        ),
      ).thenThrow(const UnsafeArchiveEntryException('../evil.txt'));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Import Configuration'));
      await tester.tap(find.text('Import Configuration'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Import rejected: archive contains an unsafe entry (../evil.txt).',
        ),
        findsOneWidget,
      );
      verifyNever(mockClusterListController.loadClusters());
      verifyNever(mockScriptController.loadScripts());
    });

    testWidgets(
      'reloads cluster and script lists before success message after import',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([]);
        when(mockActiveConnectionController.activeProfile).thenReturn(null);
        when(mockClusterListController.loadClusters()).thenAnswer((_) async {});
        when(mockScriptController.loadScripts()).thenAnswer((_) async {});
        when(
          mockSettingsService.importConfiguration(
            dialogTitle: anyNamed('dialogTitle'),
            promptPassphrase: anyNamed('promptPassphrase'),
            onClusterConflict: anyNamed('onClusterConflict'),
          ),
        ).thenAnswer((_) async => const ImportConfigurationResult());

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await scrollTo(tester, find.text('Import Configuration'));
        await tester.tap(find.text('Import Configuration'));
        await tester.pumpAndSettle();

        verifyInOrder([
          mockSettingsService.importConfiguration(
            dialogTitle: anyNamed('dialogTitle'),
            promptPassphrase: anyNamed('promptPassphrase'),
            onClusterConflict: anyNamed('onClusterConflict'),
          ),
          mockClusterListController.loadClusters(),
          mockScriptController.loadScripts(),
        ]);
        expect(
          find.text('Configuration imported successfully'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows InsecureTlsBadge only for disabled tlsVerification profiles',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockActiveConnectionController.activeProfile).thenReturn(null);
        when(mockClusterListController.clusters).thenReturn([
          const ClusterProfile(
            name: 'disabled-cluster',
            bootstrapServers: 'b1:9093',
            securityProtocol: 'SSL',
            tlsVerification: TlsVerification.disabled,
          ),
          const ClusterProfile(
            name: 'enabled-cluster',
            bootstrapServers: 'b2:9093',
            securityProtocol: 'SSL',
            tlsVerification: TlsVerification.enabled,
          ),
          const ClusterProfile(
            name: 'unreviewed-cluster',
            bootstrapServers: 'b3:9093',
            securityProtocol: 'SSL',
            tlsVerification: TlsVerification.unreviewed,
          ),
        ]);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await scrollTo(tester, find.text('Insecure TLS'));
        expect(find.text('Insecure TLS'), findsOneWidget);
      },
    );

    testWidgets(
      'export dialog validates passphrase length and match and passes passphrase or null',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([]);
        when(mockActiveConnectionController.activeProfile).thenReturn(null);
        when(
          mockSettingsService.exportConfiguration(
            dialogTitle: anyNamed('dialogTitle'),
            encryptionPassphrase: anyNamed('encryptionPassphrase'),
          ),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await scrollTo(tester, find.text('Export Configuration'));
        await tester.tap(find.text('Export Configuration'));
        await tester.pumpAndSettle();

        // Check include credentials.
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();

        // 11 characters -> error and disabled button.
        final fields = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        expect(fields, findsNWidgets(2));
        await tester.enterText(fields.at(0), '12345678901');
        await tester.pumpAndSettle();
        expect(
          find.text('Passphrase must be at least 12 characters'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Export'))
              .onPressed,
          isNull,
        );

        // 12+ characters with mismatch -> error and disabled button.
        await tester.enterText(fields.at(0), 'valid-passphrase-123');
        await tester.enterText(fields.at(1), 'different-passphrase');
        await tester.pumpAndSettle();
        expect(find.text('Passphrases do not match'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Export'))
              .onPressed,
          isNull,
        );

        // Matching passphrase -> enabled and calls service with passphrase.
        await tester.enterText(fields.at(1), 'valid-passphrase-123');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Export'))
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Export'));
        await tester.pumpAndSettle();

        verify(
          mockSettingsService.exportConfiguration(
            dialogTitle: anyNamed('dialogTitle'),
            encryptionPassphrase: 'valid-passphrase-123',
          ),
        ).called(1);
      },
    );

    group('cluster import content dispatch', () {
      late MockKafkalyzerRustLibApi mockRustApi;
      late _FakeFilePicker fakePicker;
      late FilePickerPlatform originalPicker;

      setUp(() {
        mockRustApi = MockKafkalyzerRustLibApi();
        KafkalyzerRustLib.initMock(api: mockRustApi);
        originalPicker = FilePickerPlatform.instance;
        fakePicker = _FakeFilePicker();
        FilePickerPlatform.instance = fakePicker;

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([]);
        when(mockActiveConnectionController.activeProfile).thenReturn(null);
      });

      tearDown(() {
        FilePickerPlatform.instance = originalPicker;
        KafkalyzerRustLib.dispose();
      });

      testWidgets(
        'imports encrypted ZIP (.age and renamed .zip), legacy JSON, and handles cancel',
        (tester) async {
          tester.view.physicalSize = const Size(1920, 1080);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          final archive = Archive();
          final jsonBytes = utf8.encode('[]');
          archive.addFile(
            ArchiveFile('clusters.json', jsonBytes.length, jsonBytes),
          );
          final plainZip = Uint8List.fromList(ZipEncoder().encode(archive));
          final encryptedBytes = Uint8List.fromList([
            ...utf8.encode('age-encryption.org/v1\n'),
            1,
            2,
            3,
          ]);

          when(
            mockRustApi.crateApiProfileCryptoDecryptBundleWithPassphrase(
              ciphertext: encryptedBytes,
              passphrase: 'correct-horse-battery',
            ),
          ).thenAnswer((_) async => BundleCryptoResult(data: plainZip));

          when(
            mockClusterListController.importClustersZip(
              any,
              onConflict: anyNamed('onConflict'),
            ),
          ).thenAnswer(
            (_) async => const ImportSummary(
              imported: 1,
              replaced: 0,
              renamed: 0,
              skipped: 0,
            ),
          );
          when(
            mockClusterListController.importClusters(
              any,
              onConflict: anyNamed('onConflict'),
            ),
          ).thenAnswer(
            (_) async => const ImportSummary(
              imported: 1,
              replaced: 0,
              renamed: 0,
              skipped: 0,
            ),
          );

          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          await scrollTo(tester, find.widgetWithText(OutlinedButton, 'Import'));

          // 1. Encrypted .zip.age
          fakePicker.pickResult = FilePickerResult([
            PlatformFile(
              name: 'clusters.zip.age',
              size: encryptedBytes.length,
              bytes: encryptedBytes,
            ),
          ]);
          await tester.tap(find.widgetWithText(OutlinedButton, 'Import'));
          await tester.pumpAndSettle();
          expect(fakePicker.lastAllowedExtensions, ['json', 'zip', 'age']);
          await tester.enterText(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            ),
            'correct-horse-battery',
          );
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Import'));
          await tester.pumpAndSettle();
          verify(
            mockClusterListController.importClustersZip(
              plainZip,
              onConflict: anyNamed('onConflict'),
            ),
          ).called(1);

          // 2. Renamed encrypted file with .zip extension -> still decrypts!
          fakePicker.pickResult = FilePickerResult([
            PlatformFile(
              name: 'renamed.zip',
              size: encryptedBytes.length,
              bytes: encryptedBytes,
            ),
          ]);
          await tester.tap(find.widgetWithText(OutlinedButton, 'Import'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            ),
            'correct-horse-battery',
          );
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Import'));
          await tester.pumpAndSettle();
          verify(
            mockClusterListController.importClustersZip(
              plainZip,
              onConflict: anyNamed('onConflict'),
            ),
          ).called(1);

          // 3. Legacy JSON -> dispatches to importClusters without prompt
          fakePicker.pickResult = FilePickerResult([
            PlatformFile(
              name: 'clusters.json',
              size: jsonBytes.length,
              bytes: Uint8List.fromList(jsonBytes),
            ),
          ]);
          await tester.tap(find.widgetWithText(OutlinedButton, 'Import'));
          await tester.pumpAndSettle();
          verify(
            mockClusterListController.importClusters(
              '[]',
              onConflict: anyNamed('onConflict'),
            ),
          ).called(1);

          // 4. Cancel passphrase prompt -> no import call and no SnackBar
          fakePicker.pickResult = FilePickerResult([
            PlatformFile(
              name: 'cancel.zip.age',
              size: encryptedBytes.length,
              bytes: encryptedBytes,
            ),
          ]);
          await tester.tap(find.widgetWithText(OutlinedButton, 'Import'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          verifyNever(
            mockClusterListController.importClustersZip(
              any,
              onConflict: anyNamed('onConflict'),
            ),
          );
        },
      );
    });

    testWidgets(
      'message buffer limit field shows 50000 by default, rejects invalid input, and persists valid input',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final realSettings = SettingsService();
        GetIt.instance.unregister<SettingsService>();
        GetIt.instance.registerSingleton<SettingsService>(realSettings);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([]);
        when(mockActiveConnectionController.activeProfile).thenReturn(null);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final fieldFinder = find.byKey(const Key('message_buffer_limit_field'));
        expect(fieldFinder, findsOneWidget);
        expect(tester.widget<TextField>(fieldFinder).controller?.text, '50000');

        // Invalid out-of-range input -> shows localized range error and leaves pref unchanged
        await tester.enterText(fieldFinder, '500');
        await tester.pumpAndSettle();
        expect(
          find.text('Enter a whole number between 1,000 and 1,000,000'),
          findsOneWidget,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt(SettingsService.messageBufferLimitKey), isNull);

        // Valid input -> clears error and persists
        await tester.enterText(fieldFinder, '25000');
        await tester.pumpAndSettle();
        expect(
          find.text('Enter a whole number between 1,000 and 1,000,000'),
          findsNothing,
        );
        expect(prefs.getInt(SettingsService.messageBufferLimitKey), 25000);
        expect(realSettings.messageBufferLimit.value, 25000);
      },
    );

    testWidgets(
      'renders sections in expected order: Appearance, General, Configuration, Cluster, Diagnostics, About',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([]);
        when(mockActiveConnectionController.activeProfile).thenReturn(null);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final titles = [
          'Appearance',
          'General',
          'Configuration',
          'Cluster Configuration',
          'Diagnostics',
          'About Kafkalyzer',
        ];
        final ys = titles
            .map((t) => tester.getTopLeft(find.text(t)).dy)
            .toList();
        for (var i = 0; i < ys.length - 1; i++) {
          expect(
            ys[i],
            lessThan(ys[i + 1]),
            reason: '${titles[i]} should appear above ${titles[i + 1]}',
          );
        }
      },
    );

    testWidgets(
      'appearance controls update AppearanceSettings and reset confirmation works',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([]);
        when(mockActiveConnectionController.activeProfile).thenReturn(null);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final appearance = GetIt.instance<AppearanceSettings>();
        expect(appearance.themeMode, ThemeMode.system);

        // Switch theme to Light
        await tester.tap(find.text('Light'));
        await tester.pumpAndSettle();
        expect(appearance.themeMode, ThemeMode.light);

        // Switch language to Deutsch
        await tester.tap(find.byKey(const Key('appearance_language_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Deutsch').last);
        await tester.pumpAndSettle();
        expect(appearance.locale, const Locale('de'));

        // Switch text scale to 1.25
        await tester.tap(
          find.byKey(const Key('appearance_text_scale_dropdown')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('125%').last);
        await tester.pumpAndSettle();
        expect(appearance.textScale, 1.25);

        // Cancel reset -> preserves changes
        await tester.tap(find.byKey(const Key('reset_appearance_button')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(appearance.themeMode, ThemeMode.light);
        expect(appearance.locale, const Locale('de'));

        // Confirm reset -> restores defaults
        await tester.tap(find.byKey(const Key('reset_appearance_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
        await tester.pumpAndSettle();
        expect(appearance.themeMode, ThemeMode.system);
        expect(appearance.locale, isNull);
        expect(appearance.textScale, 1.0);
      },
    );

    testWidgets(
      'default result limit IntSettingField validates range and persists valid input',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final realSettings = SettingsService();
        GetIt.instance.unregister<SettingsService>();
        GetIt.instance.registerSingleton<SettingsService>(realSettings);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([]);
        when(mockActiveConnectionController.activeProfile).thenReturn(null);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final fieldFinder = find.byKey(const Key('default_result_limit_field'));
        await scrollTo(tester, fieldFinder);
        expect(tester.widget<TextField>(fieldFinder).controller?.text, '200');

        // Invalid out-of-range -> error and not persisted
        await tester.enterText(fieldFinder, '0');
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(fieldFinder).decoration?.errorText,
          isNotNull,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getInt(SettingsService.defaultResultLimitSetting.key),
          isNull,
        );

        // Valid -> clears error and persists
        await tester.enterText(fieldFinder, '250');
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(fieldFinder).decoration?.errorText,
          isNull,
        );
        expect(
          prefs.getInt(SettingsService.defaultResultLimitSetting.key),
          250,
        );
        expect(realSettings.defaultResultLimit.value, 250);
      },
    );

    testWidgets(
      'general reset button asks confirmation and resets general settings',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final realSettings = SettingsService();
        GetIt.instance.unregister<SettingsService>();
        GetIt.instance.registerSingleton<SettingsService>(realSettings);
        await realSettings.setDefaultResultLimit(250);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([]);
        when(mockActiveConnectionController.activeProfile).thenReturn(null);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        await scrollTo(tester, find.byKey(const Key('reset_general_button')));

        // Cancel preserves 250
        await tester.tap(find.byKey(const Key('reset_general_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(realSettings.defaultResultLimit.value, 250);

        // Confirm resets to 200
        await tester.tap(find.byKey(const Key('reset_general_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
        await tester.pumpAndSettle();
        expect(realSettings.defaultResultLimit.value, 200);
      },
    );

    testWidgets(
      'partition_skew_threshold_field rejects 0 and 150, persists valid value, and resets to 50',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final realSettings = SettingsService();
        GetIt.instance.unregister<SettingsService>();
        GetIt.instance.registerSingleton<SettingsService>(realSettings);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([]);
        when(mockActiveConnectionController.activeProfile).thenReturn(null);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final fieldFinder = find.byKey(
          const Key('partition_skew_threshold_field'),
        );
        await scrollTo(tester, fieldFinder);

        for (final invalid in ['0', '150']) {
          await tester.enterText(fieldFinder, invalid);
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(fieldFinder).decoration?.errorText,
            isNotNull,
          );
        }
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getInt(SettingsService.partitionSkewThresholdSetting.key),
          isNull,
        );

        await tester.enterText(fieldFinder, '75');
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(fieldFinder).decoration?.errorText,
          isNull,
        );
        expect(
          prefs.getInt(SettingsService.partitionSkewThresholdSetting.key),
          75,
        );

        await scrollTo(tester, find.byKey(const Key('reset_general_button')));
        await tester.tap(find.byKey(const Key('reset_general_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
        await tester.pumpAndSettle();
        expect(
          prefs.getInt(SettingsService.partitionSkewThresholdSetting.key),
          50,
        );
      },
    );

    testWidgets('renders German settings labels when locale is de', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);

      await tester.pumpWidget(
        createWidgetUnderTest(locale: const Locale('de')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Einstellungen'), findsOneWidget);
    });

    testWidgets(
      'delete saved analysis reports button confirms and shows success SnackBar',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        var cleared = false;
        GetIt.instance.unregister<TopicAnalysisHistoryService>();
        GetIt.instance.registerSingleton<TopicAnalysisHistoryService>(
          _FakeSettingsHistoryService(onClearAll: () => cleared = true),
        );

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([]);
        when(mockActiveConnectionController.activeProfile).thenReturn(null);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final btn = find.byKey(
          const Key('delete_saved_analysis_reports_button'),
        );
        await scrollTo(tester, btn);
        await tester.tap(btn);
        await tester.pumpAndSettle();

        expect(find.text('Delete all saved analysis reports?'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(cleared, isTrue);
        expect(find.text('Saved analysis reports deleted.'), findsOneWidget);
      },
    );
  });
}

class _FakeSettingsHistoryService extends TopicAnalysisHistoryService {
  final VoidCallback onClearAll;
  _FakeSettingsHistoryService({required this.onClearAll});

  @override
  Future<void> clearAll() async {
    onClearAll();
  }
}
