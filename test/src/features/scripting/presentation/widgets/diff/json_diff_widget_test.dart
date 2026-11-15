import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/json_diff_widget.dart';
import 'package:kafkalyzer/src/rust/api/json_diff.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('renders added, removed, and changed rows in order with icons', (
    tester,
  ) async {
    const entries = [
      JsonDiffEntry(
        path: 'b',
        segments: ['b'],
        kind: JsonDiffKind.changed,
        oldValue: '2',
        newValue: '5',
      ),
      JsonDiffEntry(
        path: 'c',
        segments: ['c'],
        kind: JsonDiffKind.removed,
        oldValue: '3',
      ),
      JsonDiffEntry(
        path: 'd',
        segments: ['d'],
        kind: JsonDiffKind.added,
        newValue: '4',
      ),
    ];

    await tester.pumpWidget(
      _wrapWithApp(const JsonDiffWidget(entries: entries)),
    );

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    expect(texts, ['d: ', '4', 'c: ', '3', 'b: ']);

    final richTexts = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .toList();
    expect(richTexts.any((s) => s.contains('2') && s.contains('5')), isTrue);

    final icons = tester
        .widgetList<Icon>(find.byType(Icon))
        .map((i) => i.icon)
        .toList();
    expect(icons, [Icons.add, Icons.remove, Icons.edit]);
  });

  testWidgets('renders nested node and collapses/expands on tap', (
    tester,
  ) async {
    const entries = [
      JsonDiffEntry(
        path: 'user.name',
        segments: ['user', 'name'],
        kind: JsonDiffKind.changed,
        oldValue: '"Alice"',
        newValue: '"Bob"',
      ),
    ];

    await tester.pumpWidget(
      _wrapWithApp(const JsonDiffWidget(entries: entries)),
    );

    expect(find.byIcon(Icons.folder_open), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.text('user'), findsOneWidget);
    expect(find.text('name: '), findsOneWidget);

    await tester.tap(find.text('user'));
    await tester.pump();

    expect(find.byIcon(Icons.folder), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.text('name: '), findsNothing);
  });

  testWidgets('renders "No differences found." for identical JSON', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapWithApp(const JsonDiffWidget(entries: [])));

    expect(find.text('No differences found.'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });
}
