import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/field_value_explorer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('FieldValueExplorer renders empty state when no fields exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: FieldValueExplorer(fieldFrequencies: [])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No structured fields detected'), findsOneWidget);
  });

  testWidgets(
    'FieldValueExplorer renders fields list and displays selected field Top 10 values',
    (tester) async {
      const fieldFrequencies = [
        FieldOccurrence(
          fieldName: 'status',
          count: 100,
          percentage: 100.0,
          topValues: [
            FieldValueOccurrence(value: 'SUCCESS', count: 60, percentage: 60.0),
            FieldValueOccurrence(value: 'PENDING', count: 30, percentage: 30.0),
            FieldValueOccurrence(value: 'FAILED', count: 10, percentage: 10.0),
          ],
        ),
        FieldOccurrence(
          fieldName: 'userId',
          count: 90,
          percentage: 90.0,
          topValues: [
            FieldValueOccurrence(value: 'user_1', count: 40, percentage: 44.4),
            FieldValueOccurrence(value: 'user_2', count: 30, percentage: 33.3),
          ],
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FieldValueExplorer(fieldFrequencies: fieldFrequencies),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Field Value Explorer (Top 10 Values)'), findsOneWidget);
      expect(find.text('Search fields...'), findsOneWidget);
      expect(find.text('status'), findsOneWidget);
      expect(find.text('userId'), findsOneWidget);

      // Default selection is first field ('status')
      expect(find.text('Top 10 Values for status'), findsOneWidget);
      expect(find.text('SUCCESS'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);

      // Tap on userId field to switch selection
      await tester.tap(find.text('userId'));
      await tester.pumpAndSettle();

      expect(find.text('Top 10 Values for userId'), findsOneWidget);
      expect(find.text('user_1'), findsOneWidget);
      expect(find.text('user_2'), findsOneWidget);

      // Filter fields via search
      await tester.enterText(find.byType(TextField), 'stat');
      await tester.pumpAndSettle();

      expect(find.text('status'), findsOneWidget);
      expect(find.text('userId'), findsNothing);
    },
  );
}
