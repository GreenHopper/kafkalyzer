import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/diff/diff_ignore_list_dialog.dart';
import 'package:kafkalyzer/src/services/diff_ignore_list_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('add, remove, and invalid input messages work', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final service = DiffIgnoreListService(prefs: prefs);

    await tester.pumpWidget(
      _wrapWithApp(DiffIgnoreListDialog(topic: 'orders', service: service)),
    );

    expect(find.text('No ignored fields for this topic.'), findsOneWidget);

    // Empty input shows error
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a non-empty field path.'), findsOneWidget);

    // Valid add
    await tester.enterText(find.byType(TextField), 'updatedAt');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('updatedAt'), findsOneWidget);
    expect(service.getPathsSync('orders'), ['updatedAt']);

    // Duplicate input shows error
    await tester.enterText(find.byType(TextField), 'updatedAt');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('This field path is already ignored.'), findsOneWidget);

    // Remove button has tooltip and removes entry
    final removeBtn = find.byTooltip('Remove ignored field updatedAt');
    expect(removeBtn, findsOneWidget);
    await tester.tap(removeBtn);
    await tester.pumpAndSettle();
    expect(service.getPathsSync('orders'), isEmpty);
    expect(find.text('No ignored fields for this topic.'), findsOneWidget);
  });

  testWidgets('suggestions are offered but not pre-selected, and chip adds', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final service = DiffIgnoreListService(prefs: prefs);

    await tester.pumpWidget(
      _wrapWithApp(
        DiffIgnoreListDialog(
          topic: 'orders',
          service: service,
          suggestions: const ['updatedAt', 'traceId'],
        ),
      ),
    );

    expect(service.getPathsSync('orders'), isEmpty);
    expect(find.widgetWithText(ActionChip, 'updatedAt'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'traceId'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'updatedAt'));
    await tester.pumpAndSettle();

    expect(service.getPathsSync('orders'), ['updatedAt']);
    expect(find.widgetWithText(ActionChip, 'updatedAt'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'traceId'), findsOneWidget);
  });
}
