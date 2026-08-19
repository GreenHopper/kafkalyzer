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
}
