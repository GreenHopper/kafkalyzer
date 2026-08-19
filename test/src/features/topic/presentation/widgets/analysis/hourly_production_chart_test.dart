import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/hourly_production_chart.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

void main() {
  testWidgets(
    'HourlyProductionChart renders 24 hour buckets and highlights peak',
    (tester) async {
      final distribution = List.generate(24, (hour) {
        return HourlyCount(
          hour: hour,
          count: hour == 14 ? 500 : 50,
          percentage: hour == 14 ? 30.0 : 3.0,
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: HourlyProductionChart(hourlyDistribution: distribution),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hourly Production Peaks (24h UTC)'), findsOneWidget);
      expect(find.textContaining('Peak: 14:00 UTC'), findsOneWidget);
    },
  );
}
