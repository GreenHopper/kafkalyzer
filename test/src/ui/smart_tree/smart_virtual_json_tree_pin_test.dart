import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
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
    'clicking pin button triggers onPinToColumn callback with normalized path and uses push_pin_outlined',
    (tester) async {
      String? pinnedPath;
      final json = {
        'customer': {'name': 'Alice'},
      };

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
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

      // Find the pin button by push_pin_outlined icon and localized tooltip
      expect(find.byIcon(Icons.push_pin_outlined), findsWidgets);
      expect(find.byIcon(Icons.view_column_outlined), findsNothing);

      final pinButton = find.byTooltip('Pin as Column');
      expect(pinButton, findsWidgets);

      // Tap first pin button
      await tester.tap(pinButton.first);
      await tester.pumpAndSettle();

      expect(pinnedPath, isNotNull);
      expect(pinnedPath, isNot(startsWith('root.')));
    },
  );

  testWidgets('renders German localized pin tooltip and copy feedback', (
    tester,
  ) async {
    String? pinnedPath;
    final json = {
      'customer': {'name': 'Alice'},
    };

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
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

    // In German, tooltip is 'Als Spalte anheften'
    final pinButton = find.byTooltip('Als Spalte anheften');
    expect(pinButton, findsWidgets);
    await tester.tap(pinButton.first);
    await tester.pumpAndSettle();
    expect(pinnedPath, isNotNull);

    // Copy button tooltip in German is 'Wert kopieren'
    final copyButton = find.byTooltip('Wert kopieren');
    expect(copyButton, findsWidgets);

    // Tap copy button and check snackbar feedback
    await tester.tap(find.byIcon(Icons.copy).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Wert in die Zwischenablage kopiert'), findsOneWidget);
  });

  testWidgets('renders localized empty JSON message in EN and DE', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: const Scaffold(
          body: SizedBox(
            width: 600,
            height: 400,
            child: SmartVirtualJsonTree(json: {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Leeres JSON'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(
          body: SizedBox(
            width: 600,
            height: 400,
            child: SmartVirtualJsonTree(json: {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Empty JSON'), findsOneWidget);
  });
}
