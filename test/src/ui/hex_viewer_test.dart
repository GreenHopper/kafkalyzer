import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/ui/hex_viewer.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

void main() {
  group('HexViewer', () {
    testWidgets('renders empty binary data placeholder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: HexViewer(bytes: Uint8List(0))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Empty binary data'), findsOneWidget);
    });

    testWidgets(
      'renders hex dump address, hex values, and ASCII representation',
      (tester) async {
        // "Hello World" in bytes
        final bytes = Uint8List.fromList([
          72,
          101,
          108,
          108,
          111,
          32,
          87,
          111,
          114,
          108,
          100,
        ]);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: HexViewer(bytes: bytes)),
          ),
        );
        await tester.pumpAndSettle();

        final textFinder = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Text),
        );
        expect(textFinder, findsOneWidget);

        final text = tester.widget<Text>(textFinder).data!;
        expect(text, contains('00000000'));
        expect(text, contains('48 65 6c 6c 6f 20 57 6f  72 6c 64'));
        expect(text, contains('|Hello World|'));
      },
    );

    testWidgets('copy button copies hex dump to clipboard', (tester) async {
      final bytes = Uint8List.fromList([65, 66, 67]); // "ABC"

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: HexViewer(bytes: bytes)),
        ),
      );
      await tester.pumpAndSettle();

      final copyButton = find.byType(OutlinedButton);
      expect(copyButton, findsOneWidget);

      await tester.tap(copyButton);
      await tester.pump(); // Start the SnackBar animation
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // Let the SnackBar slide in

      expect(find.text('Hex dump copied to clipboard'), findsOneWidget);
    });

    testWidgets('renders German empty notice and copy button label', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: HexViewer(bytes: Uint8List(0))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Leere Binärdaten'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: HexViewer(bytes: Uint8List.fromList([65]))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vollständigen Hex-Dump kopieren'), findsOneWidget);
    });
  });
}
