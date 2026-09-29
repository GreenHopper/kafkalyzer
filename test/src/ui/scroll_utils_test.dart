import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/ui/scroll_utils.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'ensureVisibleVertically keeps a parent PageView on its current page',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pageController = PageController();
      final targetKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageView(
              controller: pageController,
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < 20; i++)
                        SizedBox(
                          key: i == 15 ? targetKey : null,
                          height: 80,
                          child: Text('Item $i'),
                        ),
                    ],
                  ),
                ),
                const Center(child: Text('Adjacent page')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(pageController.page, closeTo(0.0, 0.001));
      expect(targetKey.currentContext, isNotNull);

      await ensureVisibleVertically(
        targetKey.currentContext!,
        alignment: 0.3,
      );
      await tester.pumpAndSettle();

      expect(pageController.page, closeTo(0.0, 0.001));
      expect(find.text('Item 15'), findsOneWidget);
      expect(find.text('Adjacent page'), findsNothing);
    },
  );
}
