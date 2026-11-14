import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/partition_balance_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('PartitionBalanceView renders balanced partition list', (
    tester,
  ) async {
    const partitions = [
      PartitionAnalysis(
        partition: 0,
        messageCount: 500,
        byteSize: 10000,
        percentage: 50.0,
        earliestOffset: 0,
        latestOffset: 500,
      ),
      PartitionAnalysis(
        partition: 1,
        messageCount: 500,
        byteSize: 10000,
        percentage: 50.0,
        earliestOffset: 0,
        latestOffset: 500,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PartitionBalanceView(
            partitionStats: partitions,
            totalMessages: 1000,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partition Utilization & Balance'), findsOneWidget);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('Partition 0'), findsOneWidget);
    expect(find.text('Partition 1'), findsOneWidget);
  });

  testWidgets('PartitionBalanceView renders German localization', (
    tester,
  ) async {
    const partitions = [
      PartitionAnalysis(
        partition: 0,
        messageCount: 500,
        byteSize: 10000,
        percentage: 100.0,
        earliestOffset: 0,
        latestOffset: 500,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const [Locale('en'), Locale('de')],
        home: const Scaffold(
          body: PartitionBalanceView(
            partitionStats: partitions,
            totalMessages: 500,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partition-Auslastung & Verteilung'), findsOneWidget);
    expect(find.textContaining('500 Nachr.'), findsOneWidget);
  });

  testWidgets(
    'PartitionBalanceView shows warning icon and localized skewed label for skewed rows in semantics tree',
    (tester) async {
      final semantics = tester.ensureSemantics();

      const partitions = [
        PartitionAnalysis(
          partition: 0,
          messageCount: 900,
          byteSize: 90000,
          percentage: 90.0,
          earliestOffset: 0,
          latestOffset: 900,
        ),
        PartitionAnalysis(
          partition: 1,
          messageCount: 100,
          byteSize: 10000,
          percentage: 10.0,
          earliestOffset: 0,
          latestOffset: 100,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('de')],
          home: const Scaffold(
            body: PartitionBalanceView(
              partitionStats: partitions,
              totalMessages: 1000,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsAtLeastNWidgets(2));
      expect(find.text('Ungleich'), findsNWidgets(2));
      expect(find.bySemanticsLabel(RegExp(r'\bUngleich\b')), findsNWidgets(2));
      semantics.dispose();
    },
  );
}
