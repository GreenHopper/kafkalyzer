import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/mcp_sharing_dialog.dart';
import 'package:kafkalyzer/src/features/settings/presentation/controllers/settings_import_export_controller.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/settings_cluster_section.dart';
import 'package:kafkalyzer/src/rust/api/headless_profiles.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import '../settings_view_test.mocks.dart';

class _FakeClusterService extends ClusterService {
  List<ClusterProfile> clusters = [];
  int saveCount = 0;

  @override
  Future<List<ClusterProfile>> loadClusters() async => List.of(clusters);

  @override
  Future<bool> saveClusters(List<ClusterProfile> next) async {
    saveCount++;
    clusters = List.of(next);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeClusterService service;
  late ClusterListController controller;
  late MockActiveConnectionController mockActive;
  late MockSettingsService mockSettings;
  late AppLocalizations l10n;

  setUp(() async {
    await getIt.reset();
    service = _FakeClusterService();
    getIt.registerSingleton<ClusterService>(service);
    mockActive = MockActiveConnectionController();
    when(mockActive.activeProfile).thenReturn(null);
    getIt.registerSingleton<ActiveConnectionController>(mockActive);
    mockSettings = MockSettingsService();
    getIt.registerSingleton<SettingsService>(mockSettings);
    controller = ClusterListController();
    getIt.registerSingleton<ClusterListController>(controller);
    await Future<void>.delayed(Duration.zero);
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SettingsClusterSection(
              l10n: l10n,
              exportController: SettingsImportExportController(
                settingsService: mockSettings,
                clusterListController: controller,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows shared and sharing-failed badges', (tester) async {
    service.clusters = [
      const ClusterProfile(
        name: 'ok-shared',
        bootstrapServers: 'b:9092',
        tlsVerification: TlsVerification.enabled,
        headlessShared: true,
      ),
      const ClusterProfile(
        name: 'bad-shared',
        bootstrapServers: 'b:9092',
        tlsVerification: TlsVerification.enabled,
        headlessShared: true,
      ),
    ];
    await controller.loadClusters();
    service.sharedProfilesStatus.value = const SharedProfilesStatus.failed(
      failed: [
        SharedProfileFailure(
          name: 'bad-shared',
          kind: SharedProfileFailureKind.keyringUnavailable,
        ),
      ],
    );

    await pumpSection(tester);

    expect(find.text('Shared with MCP'), findsOneWidget);
    expect(find.text('Sharing failed'), findsOneWidget);
  });

  testWidgets('retry action re-saves current clusters', (tester) async {
    service.clusters = [
      const ClusterProfile(
        name: 'bad-shared',
        bootstrapServers: 'b:9092',
        tlsVerification: TlsVerification.enabled,
        headlessShared: true,
      ),
    ];
    await controller.loadClusters();
    service.sharedProfilesStatus.value = const SharedProfilesStatus.failed(
      bridgeError: 'boom',
    );
    final savesBefore = service.saveCount;

    await pumpSection(tester);
    await tester.tap(find.text('Retry sharing'));
    await tester.pumpAndSettle();

    expect(service.saveCount, savesBefore + 1);
  });

  test('duplicate clear path drops headlessShared', () {
    const shared = ClusterProfile(
      name: 'shared',
      bootstrapServers: 'b:9092',
      tlsVerification: TlsVerification.enabled,
      headlessShared: true,
    );
    final forDialog = shared.copyWith(headlessShared: null);
    expect(forDialog.headlessShared, isNull);
    expect(
      mcpSharingFailedFor(forDialog, const SharedProfilesStatus.ok()),
      isFalse,
    );
  });
}
