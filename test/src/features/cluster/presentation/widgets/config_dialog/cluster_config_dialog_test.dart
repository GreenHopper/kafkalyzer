import 'dart:async';

import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/connection_diagnostics_panel.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/read_only_guidance_dialog.dart';
import 'package:kafkalyzer/src/rust/api/connection_diagnostics.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/connection_diagnostics_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectionDiagnosticsService extends ConnectionDiagnosticsService {
  final Future<ConnectionDiagnosis> Function(ClusterProfile profile) _handler;

  _FakeConnectionDiagnosticsService(this._handler);

  @override
  Future<ConnectionDiagnosis> diagnose(ClusterProfile profile) =>
      _handler(profile);
}

ConnectionDiagnosis _okDiagnosis() => ConnectionDiagnosis(
  outcome: DiagnosisOutcome.ok,
  stages: const [
    StageResult(
      stage: DiagnosisStage.network,
      state: StageState.ok,
      servers: [],
    ),
    StageResult(
      stage: DiagnosisStage.tls,
      state: StageState.notApplicable,
      servers: [],
    ),
    StageResult(
      stage: DiagnosisStage.authentication,
      state: StageState.notApplicable,
      servers: [],
    ),
    StageResult(
      stage: DiagnosisStage.metadata,
      state: StageState.ok,
      servers: [],
    ),
    StageResult(
      stage: DiagnosisStage.schemaRegistry,
      state: StageState.notApplicable,
      servers: [],
    ),
  ],
  unattributed: const [],
  elapsedMs: BigInt.from(12),
);

ConnectionDiagnosis _failedDiagnosis() => ConnectionDiagnosis(
  outcome: DiagnosisOutcome.failed,
  stages: const [
    StageResult(
      stage: DiagnosisStage.network,
      state: StageState.failed,
      hint: DiagnosisHint.connectionRefused,
      raw: 'Connection refused (os error 111)',
      servers: [],
    ),
    StageResult(
      stage: DiagnosisStage.tls,
      state: StageState.notChecked,
      notCheckedReason: NotCheckedReason.previousStageFailed,
      servers: [],
    ),
    StageResult(
      stage: DiagnosisStage.authentication,
      state: StageState.notChecked,
      notCheckedReason: NotCheckedReason.previousStageFailed,
      servers: [],
    ),
    StageResult(
      stage: DiagnosisStage.metadata,
      state: StageState.notChecked,
      notCheckedReason: NotCheckedReason.previousStageFailed,
      servers: [],
    ),
    StageResult(
      stage: DiagnosisStage.schemaRegistry,
      state: StageState.notChecked,
      notCheckedReason: NotCheckedReason.previousStageFailed,
      servers: [],
    ),
  ],
  unattributed: const [],
  elapsedMs: BigInt.from(25),
);

void main() {
  group('ClusterConfigDialog', () {
    testWidgets('renders in Add mode when no cluster provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          home: Scaffold(body: ClusterConfigDialog()),
        ),
      );

      expect(find.text('Add Cluster'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Security Protocol'), findsOneWidget);
      expect(find.text('PLAINTEXT'), findsOneWidget);

      // Default protocol is PLAINTEXT, so SASL and SSL forms should optionally NOT be visible
      // or at least not strictly required. Based on implementation, specific fields appear conditionally.
      expect(find.text('SASL Mechanism'), findsNothing);
      expect(find.textContaining('Keystore Location'), findsNothing);
    });

    testWidgets('renders in Edit mode with provided cluster', (tester) async {
      final cluster = ClusterProfile(
        name: 'Test Cluster',
        bootstrapServers: 'localhost:9094',
        securityProtocol: 'SASL_SSL',
        saslUsername: 'user',
        saslPassword: 'pass',
        mechanism: 'PLAIN',
        sslKeystoreLocation: '/path/to/keystore',
        tlsVerification: TlsVerification.enabled,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          home: Scaffold(body: ClusterConfigDialog(cluster: cluster)),
        ),
      );

      expect(find.text('Edit Cluster'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Test Cluster'), findsOneWidget);
      expect(find.text('localhost:9094'), findsOneWidget);

      // Since SASL_SSL, both forms should be visible
      expect(find.text('SASL Mechanism'), findsOneWidget);
      expect(find.textContaining('Keystore Location'), findsOneWidget);
      expect(find.text('/path/to/keystore'), findsOneWidget);
    });

    testWidgets('changes visible fields when security protocol changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          home: Scaffold(body: ClusterConfigDialog()),
        ),
      );

      // Initially PLAINTEXT
      expect(find.text('SASL Mechanism'), findsNothing);

      // Change to SASL_PLAINTEXT
      await tester.ensureVisible(find.text('PLAINTEXT'));
      await tester.tap(find.text('PLAINTEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SASL_PLAINTEXT').last);
      await tester.pumpAndSettle();

      expect(find.text('SASL Mechanism'), findsOneWidget);
      expect(find.textContaining('Keystore Location'), findsNothing);

      // Change to SSL
      await tester.ensureVisible(find.text('SASL_PLAINTEXT'));
      await tester.tap(find.text('SASL_PLAINTEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSL').last);
      await tester.pumpAndSettle();

      expect(find.text('SASL Mechanism'), findsNothing);
      expect(find.text('Truststore Location (PEM or JKS)'), findsOneWidget);

      // Select Keystore mode in segmented button
      final keystoreSegmentFinder = find.text('Keystore (PKCS12 / JKS)');
      await tester.ensureVisible(keystoreSegmentFinder);
      await tester.tap(keystoreSegmentFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('Keystore Location'), findsOneWidget);
    });

    testWidgets('validates and returns profile on save', (tester) async {
      ClusterProfile? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showDialog<ClusterProfile>(
                      context: context,
                      builder: (context) => const ClusterConfigDialog(),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Try empty save
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsNWidgets(2)); // Name and Servers

      // Fill forms
      await tester.enterText(
        find.ancestor(
          of: find.text('Cluster Name'),
          matching: find.byType(TextFormField),
        ),
        'New Cluster',
      );
      await tester.enterText(
        find.ancestor(
          of: find.text('Bootstrap Servers (e.g. localhost:9092)'),
          matching: find.byType(TextFormField),
        ),
        'localhost:9092',
      );

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.name, 'New Cluster');
      expect(result!.bootstrapServers, 'localhost:9092');
    });

    testWidgets('triggers connection test and shows diagnostics panel', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ClusterConfigDialog()),
        ),
      );

      expect(find.text('Test Connection'), findsOneWidget);

      // Attempt test connection without filling forms
      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsNWidgets(2));

      // Fill in valid fields
      await tester.enterText(
        find.ancestor(
          of: find.text('Cluster Name'),
          matching: find.byType(TextFormField),
        ),
        'Test Ping',
      );
      await tester.enterText(
        find.ancestor(
          of: find.text('Bootstrap Servers (e.g. localhost:9092)'),
          matching: find.byType(TextFormField),
        ),
        'localhost:9092',
      );

      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();

      // Diagnostics panel should appear without crashing or closing
      expect(find.byType(ConnectionDiagnosticsPanel), findsOneWidget);
    });

    testWidgets(
      'displays Protected by OS Keyring lock indicator and tooltip on password fields',
      (tester) async {
        final cluster = ClusterProfile(
          name: 'Secured Cluster',
          bootstrapServers: 'localhost:9092',
          securityProtocol: 'SASL_PLAINTEXT',
          mechanism: 'PLAIN',
          saslUsername: 'test-user',
          saslPassword: 'secret-password',
          tlsVerification: TlsVerification.enabled,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              splashFactory: InkRipple.splashFactory,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ClusterConfigDialog(cluster: cluster)),
          ),
        );
        await tester.pumpAndSettle();

        final lockIconFinder = find.byIcon(Icons.lock_outline);
        expect(lockIconFinder, findsAtLeastNWidgets(1));

        final tooltipFinder = find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == 'Protected by OS Keyring',
        );
        expect(tooltipFinder, findsAtLeastNWidgets(1));
      },
    );

    testWidgets('renders ReadOnlySecurityBadge in dialog header', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ClusterConfigDialog()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReadOnlySecurityBadge), findsOneWidget);
      expect(find.text('Read-Only'), findsOneWidget);
    });

    testWidgets(
      'TLS verification switch is hidden on PLAINTEXT, defaults to enabled on new SSL profile, and toggles disabled/enabled',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        ClusterProfile? saved;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              splashFactory: InkRipple.splashFactory,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async {
                    saved = await showDialog<ClusterProfile>(
                      context: ctx,
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

        // Hidden on default PLAINTEXT
        expect(find.text('Verify TLS certificates'), findsNothing);

        // Fill name and bootstrap
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Cluster Name'),
          'My SSL Cluster',
        );
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Bootstrap Servers (e.g. localhost:9092)',
          ),
          'broker:9093',
        );

        // Switch security protocol to SSL
        await tester.tap(find.text('PLAINTEXT'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('SSL').last);
        await tester.pumpAndSettle();

        expect(find.text('Verify TLS certificates'), findsOneWidget);
        expect(find.text('Insecure TLS'), findsNothing);

        // Toggle off -> shows warning and badge
        await tester.ensureVisible(find.text('Verify TLS certificates'));
        await tester.tap(find.text('Verify TLS certificates'));
        await tester.pumpAndSettle();
        expect(find.text('Insecure TLS'), findsOneWidget);
        expect(
          find.textContaining(
            'Certificate and hostname verification is disabled',
          ),
          findsOneWidget,
        );

        // Toggle back on -> hides warning and badge
        await tester.tap(find.text('Verify TLS certificates'));
        await tester.pumpAndSettle();
        expect(find.text('Insecure TLS'), findsNothing);

        // Save -> new profile has TlsVerification.enabled
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        expect(saved?.tlsVerification, TlsVerification.enabled);
      },
    );
  });

  group('ClusterConfigDialog connection diagnostics', () {
    tearDown(() async {
      await getIt.reset();
    });

    Future<ClusterProfile? Function()> openDialogApp(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ClusterProfile? saved;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  saved = await showDialog<ClusterProfile>(
                    context: ctx,
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
        find.widgetWithText(TextFormField, 'Cluster Name'),
        'Local Kafka',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Bootstrap Servers (e.g. localhost:9092)',
        ),
        'localhost:9092',
      );

      return () => saved;
    }

    testWidgets('success shows ConnectionDiagnosticsPanel', (tester) async {
      getIt.registerSingleton<ConnectionDiagnosticsService>(
        _FakeConnectionDiagnosticsService((_) async => _okDiagnosis()),
      );

      await openDialogApp(tester);

      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionDiagnosticsPanel), findsOneWidget);
      expect(
        find.text('Connection succeeded across all applicable stages'),
        findsOneWidget,
      );
    });

    testWidgets('failure keeps dialog open without saving', (tester) async {
      getIt.registerSingleton<ConnectionDiagnosticsService>(
        _FakeConnectionDiagnosticsService((_) async => _failedDiagnosis()),
      );

      final getSaved = await openDialogApp(tester);

      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();

      expect(find.byType(ClusterConfigDialog), findsOneWidget);
      expect(find.byType(ConnectionDiagnosticsPanel), findsOneWidget);
      expect(find.text('Connection failed at stage: Network'), findsOneWidget);
      expect(getSaved(), isNull);
    });

    testWidgets('disables Test Connection button while running', (
      tester,
    ) async {
      final completer = Completer<ConnectionDiagnosis>();
      getIt.registerSingleton<ConnectionDiagnosticsService>(
        _FakeConnectionDiagnosticsService((_) => completer.future),
      );

      await openDialogApp(tester);

      await tester.tap(find.text('Test Connection'));
      await tester.pump();

      expect(find.text('Testing Connection...'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Test Connection'),
      );
      expect(button.onPressed, isNull);

      completer.complete(_okDiagnosis());
      await tester.pumpAndSettle();

      final buttonAfter = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Test Connection'),
      );
      expect(buttonAfter.onPressed, isNotNull);
    });

    testWidgets('closing dialog during pending test throws nothing', (
      tester,
    ) async {
      final completer = Completer<ConnectionDiagnosis>();
      getIt.registerSingleton<ConnectionDiagnosticsService>(
        _FakeConnectionDiagnosticsService((_) => completer.future),
      );

      await openDialogApp(tester);

      await tester.tap(find.text('Test Connection'));
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(ClusterConfigDialog), findsNothing);

      completer.complete(_okDiagnosis());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
