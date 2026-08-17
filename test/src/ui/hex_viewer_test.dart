import 'package:kafkalyzer/src/ui/hex_viewer.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> awaitIsolates(WidgetTester tester) async {
  await tester.pump();
  int attempts = 0;
  while (tester.any(find.byType(CircularProgressIndicator)) && attempts < 50) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    attempts++;
  }
  await tester.pumpAndSettle();
}

void main() {
  group('HexViewer', () {
    testWidgets('renders empty binary data placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HexViewer(bytes: [])),
        ),
      );
      await awaitIsolates(tester);

      expect(find.text('Empty binary data'), findsOneWidget);
    });

    testWidgets(
      'renders hex dump address, hex values, and ASCII representation',
      (tester) async {
        // "Hello World" in bytes
        final bytes = [72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: HexViewer(bytes: bytes)),
          ),
        );
        await awaitIsolates(tester);

        final selectableTextFinder = find.byType(SelectableText);
        expect(selectableTextFinder, findsOneWidget);

        final text = tester.widget<SelectableText>(selectableTextFinder).data!;
        expect(text, contains('00000000'));
        expect(text, contains('48 65 6c 6c 6f 20 57 6f  72 6c 64'));
        expect(text, contains('|Hello World|'));
      },
    );

    testWidgets('copy button copies hex dump to clipboard', (tester) async {
      final bytes = [65, 66, 67]; // "ABC"

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HexViewer(bytes: bytes)),
        ),
      );
      await awaitIsolates(tester);

      final copyButton = find.byType(OutlinedButton);
      expect(copyButton, findsOneWidget);

      await tester.tap(copyButton);
      await tester.pump(); // Start the SnackBar animation
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // Let the SnackBar slide in

      expect(find.text('Hex dump copied to clipboard'), findsOneWidget);
    });
  });
}
