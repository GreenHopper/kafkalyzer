import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
