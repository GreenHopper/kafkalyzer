import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog.dart';
import 'package:kafkalyzer/src/rust/api/connection_diagnostics.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/profile_tools.dart';
import 'package:kafkalyzer/src/services/cluster_profile_tools.dart';
import 'package:kafkalyzer/src/services/connection_diagnostics_service.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../../helpers/fake_cluster_profile_tools.dart';

class _TrackingDiagnosticsService extends ConnectionDiagnosticsService {
  int calls = 0;

  @override
  Future<ConnectionDiagnosis> diagnose(ClusterProfile profile) async {
    calls++;
    return ConnectionDiagnosis(
      outcome: DiagnosisOutcome.ok,
      stages: const [],
      unattributed: const [],
      elapsedMs: BigInt.zero,
    );
  }
}

Widget _wrapDialog(Widget dialog) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: dialog)),
  );
}

void main() {
  late _TrackingDiagnosticsService diagnostics;

  setUp(() async {
    await getIt.reset();
    diagnostics = _TrackingDiagnosticsService();
    getIt.registerSingleton<ConnectionDiagnosticsService>(diagnostics);
    getIt.registerSingleton<ClusterProfileTools>(FakeClusterProfileTools());
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('Environment tag in ClusterConfigDialog', () {
    testWidgets('entering PROD preselects red and saves tag', (tester) async {
      ClusterProfile? saved;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  saved = await showDialog<ClusterProfile>(
                    context: context,
                    builder: (_) => const ClusterConfigDialog(),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.ancestor(
          of: find.text('Cluster Name'),
          matching: find.byType(TextFormField),
        ),
        'orders-prod',
      );
      await tester.enterText(
        find.ancestor(
          of: find.text('Bootstrap Servers (e.g. localhost:9092)'),
          matching: find.byType(TextFormField),
        ),
        'broker-1:9093',
      );
      await tester.enterText(
        find.ancestor(
          of: find.text('Environment Label'),
          matching: find.byType(TextFormField),
        ),
        'PROD',
      );
      await tester.pump();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.environmentLabel, 'PROD');
      expect(saved!.environmentColor, 'red');
    });

    testWidgets('clearing label removes tag and overlong label is rejected', (
      tester,
    ) async {
      ClusterProfile? saved;
      const existing = ClusterProfile(
        name: 'orders',
        bootstrapServers: 'b1:9092',
        tlsVerification: TlsVerification.enabled,
        environmentLabel: 'PROD',
        environmentColor: 'red',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  saved = await showDialog<ClusterProfile>(
                    context: context,
                    builder: (_) =>
                        const ClusterConfigDialog(cluster: existing),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final envField = find.ancestor(
        of: find.text('Environment Label'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(envField, '12345678901234567');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Environment label must be at most 16 characters'),
        findsOneWidget,
      );
      expect(saved, isNull);

      await tester.enterText(envField, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.environmentLabel, isNull);
      expect(saved!.environmentColor, isNull);
    });

    testWidgets('unknown stored colour is preserved on save unless changed', (
      tester,
    ) async {
      ClusterProfile? saved;
      const existing = ClusterProfile(
        name: 'orders',
        bootstrapServers: 'b1:9092',
        tlsVerification: TlsVerification.enabled,
        environmentLabel: 'CANARY',
        environmentColor: 'magenta',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  saved = await showDialog<ClusterProfile>(
                    context: context,
                    builder: (_) =>
                        const ClusterConfigDialog(cluster: existing),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.environmentLabel, 'CANARY');
      expect(saved!.environmentColor, 'magenta');
    });
  });

  group('Bootstrap and extra properties validation', () {
    testWidgets('invalid bootstrap blocks Test Connection', (tester) async {
      await tester.pumpWidget(_wrapDialog(const ClusterConfigDialog()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.ancestor(
          of: find.text('Cluster Name'),
          matching: find.byType(TextFormField),
        ),
        'dev',
      );
      await tester.enterText(
        find.ancestor(
          of: find.text('Bootstrap Servers (e.g. localhost:9092)'),
          matching: find.byType(TextFormField),
        ),
        'broker-1:9092,broker-2',
      );
      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();

      expect(
        find.text('Entry "broker-2" requires a port (:port)'),
        findsOneWidget,
      );
      expect(diagnostics.calls, 0);
    });

    testWidgets('additional properties editor validates forbidden and range', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapDialog(const ClusterConfigDialog()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.ancestor(
          of: find.text('Cluster Name'),
          matching: find.byType(TextFormField),
        ),
        'dev',
      );
      await tester.enterText(
        find.ancestor(
          of: find.text('Bootstrap Servers (e.g. localhost:9092)'),
          matching: find.byType(TextFormField),
        ),
        'broker-1:9092',
      );

      final titleFinder = find.text('Additional client properties');
      await tester.ensureVisible(titleFinder);
      await tester.tap(titleFinder);
      await tester.pumpAndSettle();

      final extrasField = find.ancestor(
        of: find.text('One key=value per line'),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(extrasField);
      await tester.enterText(extrasField, 'group.id=reader');
      await tester.pumpAndSettle();
      expect(find.text('Line 1: "group.id" is not allowed'), findsOneWidget);

      await tester.enterText(extrasField, 'socket.timeout.ms=-5');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Line 1: invalid value for "socket.timeout.ms" (allowed: 10..300000)',
        ),
        findsOneWidget,
      );
    });
  });

  group('Import client.properties and Duplicate mode', () {
    testWidgets(
      'rejects oversized and invalid UTF-8 files without changing fields',
      (tester) async {
        Uint8List nextBytes = Uint8List(1024 * 1024 + 1);
        await tester.pumpWidget(
          _wrapDialog(
            ClusterConfigDialog(
              pickClientPropertiesFile: () async =>
                  (name: 'client.properties', bytes: nextBytes),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Import client.properties'));
        await tester.pumpAndSettle();
        expect(
          find.text('File is larger than 1 MiB and cannot be imported.'),
          findsOneWidget,
        );

        nextBytes = Uint8List.fromList([0xff, 0xfe]);
        await tester.tap(find.text('Import client.properties'));
        await tester.pumpAndSettle();
        expect(
          find.text('File is not valid UTF-8 and cannot be read.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows preview with masked password and applies fields', (
      tester,
    ) async {
      await getIt.unregister<ClusterProfileTools>();
      getIt.registerSingleton<ClusterProfileTools>(
        FakeClusterProfileTools(
          clientPropertiesParser: (_) async => const ClientPropertiesPreview(
            profile: ClusterProfile(
              name: '',
              bootstrapServers: 'b1:9093',
              securityProtocol: 'SASL_SSL',
              mechanism: 'SCRAM-SHA-512',
              saslUsername: 'alice',
              saslPassword: 'secret',
              tlsVerification: TlsVerification.unreviewed,
            ),
            extraProperties: 'client.id=kafkalyzer-alice',
            skipped: [
              SkippedClientProperty(
                key: 'acks',
                reason: ClientPropertySkipReason.notAllowed,
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        _wrapDialog(
          ClusterConfigDialog(
            pickClientPropertiesFile: () async => (
              name: 'client.properties',
              bytes: Uint8List.fromList(
                utf8.encode('bootstrap.servers=b1:9093'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import client.properties'));
      await tester.pumpAndSettle();

      expect(find.text('Import client.properties Preview'), findsOneWidget);
      expect(find.text('••••'), findsOneWidget);
      expect(find.text('secret'), findsNothing);
      expect(find.text('acks'), findsOneWidget);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('b1:9093'), findsOneWidget);
      expect(find.text('alice'), findsOneWidget);
    });

    testWidgets('duplicate mode prefills copy name and hides import button', (
      tester,
    ) async {
      const source = ClusterProfile(
        name: 'prod',
        bootstrapServers: 'b1:9093',
        tlsVerification: TlsVerification.disabled,
        environmentLabel: 'PROD',
        environmentColor: 'red',
      );
      await tester.pumpWidget(
        _wrapDialog(
          const ClusterConfigDialog(
            cluster: source,
            existingNames: ['prod'],
            isDuplicate: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Duplicate Cluster'), findsOneWidget);
      expect(find.text('prod (copy)'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Import client.properties'), findsNothing);
    });
  });
}
