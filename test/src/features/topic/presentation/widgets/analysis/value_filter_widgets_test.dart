import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/value_filter_widgets.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('ValueFilterControl', () {
    testWidgets('renders button when filter is inactive and chip when active', (
      tester,
    ) async {
      FieldValueFilter? currentFilter;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ValueFilterControl(
                  activeFilter: currentFilter,
                  isAnalyzing: false,
                  availableFieldPaths: const ['attributes.region', 'status'],
                  onFilterChanged: (f) => setState(() => currentFilter = f),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inactive button is shown
      expect(find.text('Filter by Field Value'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);

      // Open filter dialog
      await tester.tap(find.text('Filter by Field Value'));
      await tester.pumpAndSettle();

      // Enter field path and value
      expect(find.text('Field path (e.g. attributes.region)'), findsOneWidget);
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'attributes.region');
      await tester.enterText(textFields.last, 'EU');
      await tester.tap(find.text('Apply Filter'));
      await tester.pumpAndSettle();

      // Active chip is shown
      expect(find.byType(InputChip), findsOneWidget);
      expect(find.text('Filter: attributes.region = EU'), findsOneWidget);

      // Delete chip
      final chip = tester.widget<InputChip>(find.byType(InputChip));
      chip.onDeleted!();
      await tester.pumpAndSettle();

      expect(find.text('Filter by Field Value'), findsOneWidget);
    });

    testWidgets('validates empty field path in dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueFilterControl(
              activeFilter: null,
              isAnalyzing: false,
              availableFieldPaths: const ['status'],
              onFilterChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter by Field Value'));
      await tester.pumpAndSettle();

      // Click Apply without typing field path
      await tester.tap(find.text('Apply Filter'));
      await tester.pumpAndSettle();

      expect(find.text('Field path cannot be empty'), findsOneWidget);
    });
  });

  group('ValueFilterMatchCard', () {
    testWidgets(
      'renders calculated shares: 100k total, 40k with field, 2.5k matches',
      (tester) async {
        const result = ValueFilterResult(
          fieldPath: 'attributes.region',
          value: 'EU',
          messagesWithField: 40000,
          matchedMessages: 2500,
          matchedTimeline: [],
        );

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueFilterMatchCard(result: result, totalMessages: 100000),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Filter Matches'), findsOneWidget);
        expect(find.text('attributes.region = "EU"'), findsOneWidget);

        // 2,500 matches
        expect(find.text('2,500 matches'), findsOneWidget);
        // 2.50% of all scanned messages
        expect(find.text('2.50% of all scanned messages'), findsOneWidget);
        // 6.25% of messages with this field
        expect(find.text('6.25% of messages with this field'), findsOneWidget);
        // 97,500 non-matching remainder
        expect(find.text('97,500 non-matching messages'), findsOneWidget);
      },
    );

    testWidgets('renders 0 matches without hiding', (tester) async {
      const result = ValueFilterResult(
        fieldPath: 'status',
        value: 'NONEXISTENT',
        messagesWithField: 50,
        matchedMessages: 0,
        matchedTimeline: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueFilterMatchCard(result: result, totalMessages: 100),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 matches'), findsOneWidget);
      expect(find.text('0.00% of all scanned messages'), findsOneWidget);
      expect(find.text('0.00% of messages with this field'), findsOneWidget);
      expect(find.text('100 non-matching messages'), findsOneWidget);
    });
  });
}
