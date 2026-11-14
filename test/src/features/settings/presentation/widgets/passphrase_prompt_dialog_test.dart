import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/passphrase_prompt_dialog.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'first prompt submits entered passphrase and toggles visibility',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await PassphrasePromptDialog.show(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Enter bundle passphrase'), findsOneWidget);
      expect(find.text('Wrong passphrase. Please try again.'), findsNothing);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);

      await tester.tap(find.byTooltip('Show passphrase'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );

      await tester.enterText(find.byType(TextField), 'my-secret-passphrase');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(result, 'my-secret-passphrase');
    },
  );

  testWidgets(
    'retry state shows wrong passphrase error and cancel returns null',
    (tester) async {
      String? result = 'sentinel';
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await PassphrasePromptDialog.show(
                  context,
                  previousAttemptFailed: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Wrong passphrase. Please try again.'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    },
  );
}
