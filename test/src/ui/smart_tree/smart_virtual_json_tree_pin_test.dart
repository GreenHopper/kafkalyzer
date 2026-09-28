import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/ui/smart_tree/smart_virtual_json_tree.dart';

void main() {
  testWidgets('SmartVirtualJsonTree normalizeTreePath removes root prefix', (
    tester,
  ) async {
    expect(
      SmartVirtualJsonTreeState.normalizeTreePath('root.customer.name'),
      'customer.name',
    );
    expect(
      SmartVirtualJsonTreeState.normalizeTreePath(
        'root.leistungen[0].transportId',
      ),
      'leistungen[0].transportId',
    );
    expect(SmartVirtualJsonTreeState.normalizeTreePath('root'), '');
    expect(
      SmartVirtualJsonTreeState.normalizeTreePath('customer.id'),
      'customer.id',
    );
  });

  testWidgets(
    'clicking pin button triggers onPinToColumn callback with normalized path',
    (tester) async {
      String? pinnedPath;
      final json = {
        'customer': {'name': 'Alice'},
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: SmartVirtualJsonTree(
                json: json,
                onPinToColumn: (path) {
                  pinnedPath = path;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the pin button
      final pinButton = find.byTooltip('Pin as Column');
      expect(pinButton, findsWidgets);

      // Tap first pin button
      await tester.tap(pinButton.first);
      await tester.pumpAndSettle();

      expect(pinnedPath, isNotNull);
      expect(pinnedPath, isNot(startsWith('root.')));
    },
  );
}
