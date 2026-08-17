import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_search_bar.dart';

void main() {
  Widget createWidgetUnderTest({
    required String searchPhrase,
    required ValueChanged<String> onSearchChanged,
    required int matchCount,
    required bool showNonMatches,
    required ValueChanged<bool> onShowNonMatchesChanged,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MessageSearchBar(
          searchPhrase: searchPhrase,
          onSearchChanged: onSearchChanged,
          matchCount: matchCount,
          showNonMatches: showNonMatches,
          onShowNonMatchesChanged: onShowNonMatchesChanged,
        ),
      ),
    );
  }

  testWidgets(
    'renders search phrase, match counts and handles input debounce',
    (WidgetTester tester) async {
      String searchResult = "";
      bool toggleResult = false;

      await tester.pumpWidget(
        createWidgetUnderTest(
          searchPhrase: "initial",
          onSearchChanged: (val) => searchResult = val,
          matchCount: 12,
          showNonMatches: false,
          onShowNonMatchesChanged: (val) => toggleResult = val,
        ),
      );

      // Verify initial state
      expect(find.text('12 matches'), findsOneWidget);
      expect(find.text('initial'), findsOneWidget);

      // Enter new text
      await tester.enterText(find.byType(TextField), 'new-search');
      await tester.pump(); // Debounce timer starts but doesn't finish

      expect(searchResult, ""); // Callback should not fire immediately

      // Pump with duration >= 300ms
      await tester.pump(const Duration(milliseconds: 300));
      expect(searchResult, "new-search");

      // Tap visibility toggle
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();
      expect(toggleResult, true);
    },
  );

  testWidgets('clears text on pressing clear icon', (
    WidgetTester tester,
  ) async {
    String searchResult = "temp";

    await tester.pumpWidget(
      createWidgetUnderTest(
        searchPhrase: "hello",
        onSearchChanged: (val) => searchResult = val,
        matchCount: 5,
        showNonMatches: true,
        onShowNonMatchesChanged: (_) {},
      ),
    );

    // Find and tap clear button
    expect(find.byIcon(Icons.clear), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    // Verify callback with empty string was fired after debounce
    await tester.pump(const Duration(milliseconds: 300));
    expect(searchResult, "");
  });
}
