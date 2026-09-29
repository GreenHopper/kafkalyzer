import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/ui/smart_tree/entity_formatter_registry.dart';
import 'package:kafkalyzer/src/ui/smart_tree/smart_composite_badge.dart';

void main() {
  group('SmartCompositeBadge', () {
    testWidgets('renders badge icon, key name, and label', (tester) async {
      const badgeData = FormattedBadgeData(
        icon: Icons.location_on_outlined,
        label: 'Musterstrasse 1, 1010 Wien',
        color: Colors.blueAccent,
      );
      final data = {
        'strasse': 'Musterstrasse 1',
        'plz': '1010',
        'ort': 'Wien',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SmartCompositeBadge(
                keyName: 'address',
                data: data,
                badgeInfo: badgeData,
              ),
            ),
          ),
        ),
      );

      expect(
        find.text('address: Musterstrasse 1, 1010 Wien'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    });

    testWidgets('tapping badge pins popover and displays all fields with copy button', (tester) async {
      const badgeData = FormattedBadgeData(
        icon: Icons.data_object,
        label: '1042 • Acme Corp',
        color: Colors.teal,
      );
      final data = {
        'id': 1042,
        'name': 'Acme Corp',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SmartCompositeBadge(
                keyName: 'customer',
                data: data,
                badgeInfo: badgeData,
              ),
            ),
          ),
        ),
      );

      // Popover is not open initially
      expect(find.text('id'), findsNothing);

      // Tap badge to pin
      await tester.tap(find.byType(SmartCompositeBadge));
      await tester.pumpAndSettle();

      // Lock icon indicates pinned state
      expect(find.byIcon(Icons.lock), findsOneWidget);

      // Popover shows header and fields
      expect(find.text('customer'), findsOneWidget);
      expect(find.text('id'), findsOneWidget);
      expect(find.text('1042'), findsOneWidget);
      expect(find.text('name'), findsOneWidget);
      expect(find.text('Acme Corp'), findsOneWidget);
      expect(find.byTooltip('Copy whole object'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);

      // Tap close button dismisses popover
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('1042'), findsNothing);
      expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    });

    testWidgets('ellipsizes long label under tight width constraints', (
      tester,
    ) async {
      const badgeData = FormattedBadgeData(
        icon: Icons.location_on_outlined,
        label:
            'Musterstrasse 1, 1010 Wien, Austria, very long address '
            'that would overflow a narrow tree column',
        color: Colors.blueAccent,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              child: SmartCompositeBadge(
                keyName: 'address',
                data: <String, dynamic>{
                  'strasse': 'Musterstrasse 1',
                  'plz': '1010',
                  'ort': 'Wien',
                },
                badgeInfo: badgeData,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SmartCompositeBadge), findsOneWidget);
    });

    testWidgets('initiallyPinned opens popover on mount', (tester) async {
      const badgeData = FormattedBadgeData(
        icon: Icons.date_range_outlined,
        label: '2026-09-01 → 2026-09-30',
        color: Colors.orangeAccent,
      );
      final data = {
        'startDate': '2026-09-01',
        'endDate': '2026-09-30',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SmartCompositeBadge(
                keyName: 'validity',
                data: data,
                badgeInfo: badgeData,
                initiallyPinned: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.text('2026-09-01'), findsOneWidget);
    });
  });
}
