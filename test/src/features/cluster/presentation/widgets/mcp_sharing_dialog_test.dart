import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/mcp_sharing_dialog.dart';
import 'package:kafkalyzer/src/rust/api/headless_profiles.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:material_ui/material_ui.dart';

class _FakeClusterService extends ClusterService {
  List<ClusterProfile> clusters = [];
  bool failNextSave = false;

  @override
  Future<List<ClusterProfile>> loadClusters() async => List.of(clusters);

  @override
  Future<bool> saveClusters(List<ClusterProfile> next) async {
    clusters = List.of(next);
    if (failNextSave) {
      sharedProfilesStatus.value = const SharedProfilesStatus.failed(
        bridgeError: 'sync failed',
      );
    } else {
      sharedProfilesStatus.value = const SharedProfilesStatus.ok();
    }
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeClusterService service;
  late ClusterListController controller;

  setUp(() async {
    await getIt.reset();
    service = _FakeClusterService();
    getIt.registerSingleton<ClusterService>(service);
    controller = ClusterListController();
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    required ClusterProfile profile,
    required Future<McpServerLaunch> Function() launchLoader,
  }) async {
    service.clusters = [profile];
    await controller.loadClusters();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: McpSharingDialog(
            profile: profile,
            index: 0,
            clusterController: controller,
            launchLoader: launchLoader,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('buildMcpClientSnippet escapes quotes and non-ASCII names', () {
    final snippet = buildMcpClientSnippet(
      command: '/opt/kafkalyzer-mcp',
      leadingArgs: const ['--mcp'],
      clusterName: r'ord"ers-テスト',
    );
    final decoded = jsonDecode(snippet) as Map<String, dynamic>;
    final args =
        (decoded['mcpServers'] as Map)['kafkalyzer']['args'] as List<dynamic>;
    expect(args, ['--mcp', '--cluster', r'ord"ers-テスト']);
  });

  testWidgets('warning is visible before toggling', (tester) async {
    await pumpDialog(
      tester,
      profile: const ClusterProfile(
        name: 'orders',
        bootstrapServers: 'b:9092',
        tlsVerification: TlsVerification.enabled,
      ),
      launchLoader: () async => const McpServerLaunch(
        command: '/usr/bin/kafkalyzer-mcp',
        leadingArgs: [],
        exists: true,
      ),
    );

    expect(find.textContaining('language-model provider'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('copy is disabled when not shared', (tester) async {
    await pumpDialog(
      tester,
      profile: const ClusterProfile(
        name: 'orders',
        bootstrapServers: 'b:9092',
        tlsVerification: TlsVerification.enabled,
      ),
      launchLoader: () async => const McpServerLaunch(
        command: '/usr/bin/kafkalyzer-mcp',
        leadingArgs: [],
        exists: true,
      ),
    );

    final copyButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Copy snippet'),
    );
    expect(copyButton.onPressed, isNull);
    expect(find.textContaining('Share the profile first'), findsOneWidget);
  });

  testWidgets('program-not-found hint appears when binary missing', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      profile: const ClusterProfile(
        name: 'orders',
        bootstrapServers: 'b:9092',
        tlsVerification: TlsVerification.enabled,
        headlessShared: true,
      ),
      launchLoader: () async => const McpServerLaunch(
        command: '/missing/kafkalyzer-mcp',
        leadingArgs: [],
        exists: false,
      ),
    );

    expect(
      find.textContaining('Program not found at /missing/kafkalyzer-mcp'),
      findsOneWidget,
    );
  });

  testWidgets('failed toggle shows an error snackbar', (tester) async {
    service.failNextSave = true;
    await pumpDialog(
      tester,
      profile: const ClusterProfile(
        name: 'orders',
        bootstrapServers: 'b:9092',
        tlsVerification: TlsVerification.enabled,
      ),
      launchLoader: () async => const McpServerLaunch(
        command: '/usr/bin/kafkalyzer-mcp',
        leadingArgs: [],
        exists: true,
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not update sharing for this cluster.'),
      findsOneWidget,
    );
  });

  testWidgets('copy writes valid JSON for special names', (tester) async {
    const name = r'ord"ers-テスト';
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboardText};
        }
        return null;
      },
    );

    await pumpDialog(
      tester,
      profile: const ClusterProfile(
        name: name,
        bootstrapServers: 'b:9092',
        tlsVerification: TlsVerification.enabled,
        headlessShared: true,
      ),
      launchLoader: () async => const McpServerLaunch(
        command: '/usr/bin/kafkalyzer-mcp',
        leadingArgs: [],
        exists: true,
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Copy snippet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final decoded = jsonDecode(clipboardText!) as Map<String, dynamic>;
    final args =
        (decoded['mcpServers'] as Map)['kafkalyzer']['args'] as List<dynamic>;
    expect(args.last, name);
    expect(find.text('Snippet copied'), findsOneWidget);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
}
