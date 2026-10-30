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
            FieldValueOccurrence(
              value: 'SUCCESS',
              count: 60,
              percentage: 60.0,
              truncated: false,
            ),
            FieldValueOccurrence(
              value: 'PENDING',
              count: 30,
              percentage: 30.0,
              truncated: false,
            ),
            FieldValueOccurrence(
              value: 'FAILED',
              count: 10,
              percentage: 10.0,
              truncated: false,
            ),
          ],
          valuesCapped: false,
        ),
        FieldOccurrence(
          fieldName: 'userId',
          count: 90,
          percentage: 90.0,
          topValues: [
            FieldValueOccurrence(
              value: 'user_1',
              count: 40,
              percentage: 44.4,
              truncated: false,
            ),
            FieldValueOccurrence(
              value: 'user_2',
              count: 30,
              percentage: 33.3,
              truncated: false,
            ),
          ],
          valuesCapped: false,
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

  testWidgets(
    'Drill-down dialog displays metrics and triggers rescan callback',
    (tester) async {
      FieldValueFilter? rescanFilter;

      const fieldFrequencies = [
        FieldOccurrence(
          fieldName: 'status',
          count: 100,
          percentage: 100.0,
          topValues: [
            FieldValueOccurrence(
              value: 'SUCCESS',
              count: 60,
              percentage: 60.0,
              truncated: false,
            ),
          ],
          valuesCapped: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FieldValueExplorer(
              fieldFrequencies: fieldFrequencies,
              totalMessages: 200,
              onRescanWithFilter: (f) => rescanFilter = f,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the info icon for SUCCESS
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.byType(FieldValueDrillDownDialog), findsOneWidget);
      expect(find.text('Field Value Details'), findsOneWidget);
      expect(find.text('Approximate (values capped)'), findsOneWidget);
      expect(find.text('Share of all messages: 30.00%'), findsOneWidget);

      // Click Re-scan with this filter
      await tester.tap(find.text('Re-scan with this filter'));
      await tester.pumpAndSettle();

      expect(rescanFilter, isNotNull);
      expect(rescanFilter!.fieldPath, 'status');
      expect(rescanFilter!.value, 'SUCCESS');
    },
  );

  testWidgets('Drill-down dialog disables rescan for truncated values', (
    tester,
  ) async {
    const fieldFrequencies = [
      FieldOccurrence(
        fieldName: 'description',
        count: 10,
        percentage: 10.0,
        topValues: [
          FieldValueOccurrence(
            value: 'very long text that was truncated...',
            count: 10,
            percentage: 100.0,
            truncated: true,
          ),
        ],
        valuesCapped: false,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FieldValueExplorer(
            fieldFrequencies: fieldFrequencies,
            totalMessages: 100,
            onRescanWithFilter: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('Value was truncated'), findsOneWidget);
    // Button is disabled
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Re-scan with this filter'),
    );
    expect(button.onPressed, isNull);
  });
}
