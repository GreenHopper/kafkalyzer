import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/smart_tree/smart_composite_badge.dart';
import 'package:kafkalyzer/src/ui/smart_tree/smart_virtual_json_tree.dart';

void main() {
  group('SmartVirtualJsonTree', () {
    testWidgets('renders primitive fields and syntax colors', (tester) async {
      final json = {
        'username': 'bob',
        'score': 100,
        'verified': true,
        'extra': null,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SmartVirtualJsonTree(json: json),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('username: '), findsOneWidget);
      expect(find.text('"bob"'), findsOneWidget);
      expect(find.text('score: '), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('verified: '), findsOneWidget);
      expect(find.text('true'), findsOneWidget);
      expect(find.text('extra: '), findsOneWidget);
      expect(find.text('null'), findsOneWidget);
    });

    testWidgets('clicking chevron expands and collapses nested object', (tester) async {
      final json = {
        'settings': {
          'theme': {
            'mode': 'dark',
          },
          'notifications': false,
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SmartVirtualJsonTree(json: json),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially 'root.settings' is collapsed
      expect(find.text('settings: '), findsOneWidget);
      expect(find.text('{ 2 keys }'), findsOneWidget);
      expect(find.text('theme: '), findsNothing);

      // Tap chevron to expand
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      // Now expanded
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('theme: '), findsOneWidget);
      expect(find.text('{ 1 key }'), findsOneWidget);
      expect(find.text('notifications: '), findsOneWidget);
      expect(find.text('false'), findsOneWidget);

      // Tap chevron to collapse
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.text('notifications: '), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('renders inline SmartCompositeBadge for semantic objects', (tester) async {
      final json = {
        'order': 42,
        'customer': {
          'id': 1042,
          'name': 'Acme Corp',
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SmartVirtualJsonTree(json: json),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SmartCompositeBadge), findsOneWidget);
      expect(find.text('1042 • Acme Corp'), findsOneWidget);
    });

    testWidgets('reports match count and highlights search matches', (tester) async {
      int matchCount = 0;
      final json = {
        'server': {
          'host': 'production-broker',
          'port': 9092,
        }
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SmartVirtualJsonTree(
                json: json,
                searchQuery: 'production',
                onMatchCountChanged: (count) {
                  matchCount = count;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(matchCount, 1);
      // Ancestor 'server' was auto-expanded
      expect(find.text('host: '), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('renders collapsedRange placeholder and tapping it expands hidden items',
        (tester) async {
      final items = List.generate(20, (i) => {'id': i, 'title': 'Task $i'});
      final json = {'leistungen': items};

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 800,
              child: SmartVirtualJsonTree(
                json: json,
                searchQuery: 'Task 10',
                enableContextWindowing: true,
                contextRadius: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find collapsed range placeholder
      expect(find.textContaining('9 hidden items'), findsOneWidget);
      expect(find.textContaining('8 hidden items'), findsOneWidget);

      // Tap on the first collapsed placeholder to expand it
      await tester.tap(find.textContaining('9 hidden items'));
      await tester.pumpAndSettle();

      // Now the 9 items from range 0..8 should be expanded
      expect(find.textContaining('9 hidden items'), findsNothing);
      expect(find.text('[0]: '), findsOneWidget);
    });

    testWidgets('renders array match context badge and toggle button switches view mode',
        (tester) async {
      final items = List.generate(20, (i) => {'id': i, 'name': 'Item $i'});
      final json = {'items': items};

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 800,
              child: SmartVirtualJsonTree(
                json: json,
                searchQuery: 'Item 10',
                enableContextWindowing: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify array match badge is present
      expect(find.textContaining('1 matches (Focus: ±1)'), findsOneWidget);
      expect(find.text('Show all 20'), findsOneWidget);

      // Tap 'Show all 20' to expand all
      await tester.tap(find.text('Show all 20'));
      await tester.pumpAndSettle();

      // Now toggle changes to 'Focus matches (±1)' and collapsed range placeholders disappear
      expect(find.text('Focus matches (±1)'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsNothing);

      // Tap 'Focus matches (±1)' to return to context windowing
      await tester.tap(find.text('Focus matches (±1)'));
      await tester.pumpAndSettle();

      expect(find.text('Show all 20'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsWidgets);
    });

    testWidgets('jumpToMatch centers target row and applies active match indicator',
        (tester) async {
      final key = GlobalKey<SmartVirtualJsonTreeState>();
      final json = {
        'items': [
          {'id': 1, 'name': 'Target A'},
          {'id': 2, 'name': 'Target B'},
        ]
      };

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SmartVirtualJsonTree(
                key: key,
                json: json,
                searchQuery: 'Target',
                enableContextWindowing: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Programmatic jump to match 0
      key.currentState?.jumpToMatch(0);
      await tester.pumpAndSettle();

      // Active target indicator 🎯 should be rendered
      expect(find.text('🎯'), findsOneWidget);
    });

    testWidgets('renders compound breadcrumb key when enableIndentationFlattening is true',
        (tester) async {
      final json = {
        'transport': {
          'order': {
            'code': 'XYZ-999',
          }
        }
      };

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SmartVirtualJsonTree(
                json: json,
                enableIndentationFlattening: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display compound breadcrumb 'transport › order'
      expect(find.textContaining('transport'), findsOneWidget);
      expect(find.textContaining('order'), findsOneWidget);
      expect(find.textContaining('›'), findsOneWidget);
    });
  });
}
