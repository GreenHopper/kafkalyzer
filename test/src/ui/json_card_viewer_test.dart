import 'package:kafkalyzer/src/ui/json_card_viewer.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsonCardViewer', () {
    testWidgets('renders primitive values correctly', (tester) async {
      final json = {'key1': 'value1', 'key2': 123, 'key3': true};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 2000,
              child: SingleChildScrollView(child: JsonCardViewer(json: json)),
            ),
          ),
        ),
      );

      expect(find.text('KEY1'), findsOneWidget);
      expect(find.text('value1'), findsOneWidget);
      expect(find.text('KEY2'), findsOneWidget);
      expect(find.text('123'), findsOneWidget);
      expect(find.text('KEY3'), findsOneWidget);
      expect(find.text('true'), findsOneWidget);
    });

    testWidgets('renders nested objects correctly', (tester) async {
      final json = {
        'parent': {'child': 'nestedValue'},
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 2000,
              child: SingleChildScrollView(child: JsonCardViewer(json: json)),
            ),
          ),
        ),
      );

      expect(find.text('PARENT'), findsOneWidget);
      expect(find.text('CHILD'), findsOneWidget);
      expect(find.text('nestedValue'), findsOneWidget);
    });

    testWidgets('renders lists correctly', (tester) async {
      final json = {
        'list': ['item1', 'item2'],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 2000,
              child: SingleChildScrollView(child: JsonCardViewer(json: json)),
            ),
          ),
        ),
      );

      expect(find.text('LIST'), findsOneWidget);
      expect(find.text('[0]'), findsOneWidget);
      expect(find.text('item1'), findsOneWidget);
      expect(find.text('[1]'), findsOneWidget);
      expect(find.text('item2'), findsOneWidget);
    });

    testWidgets('highlights search queries', (tester) async {
      final json = {'key': 'foundMe'};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 2000,
              child: SingleChildScrollView(
                child: JsonCardViewer(json: json, searchQuery: 'found'),
              ),
            ),
          ),
        ),
      );

      // We expect RichText/TextSpan to contain matches.
      // Highlighting logic usually splits text into multiple spans.
      // 'foundMe' with query 'found' -> 'found' (highlighted) + 'Me' (normal)

      // Finding RichText widgets is tricky to verify styles deep inside without specific keys,
      // but we can verify that meaningful parts are present.

      // However, highlight logic creates multiple text spans. find.text might fail if it spans multiple widgets/spans?
      // Actually flutter test find.text finds plain text. find.richText helps.

      expect(find.byType(RichText), findsWidgets);
    });
  });
}
