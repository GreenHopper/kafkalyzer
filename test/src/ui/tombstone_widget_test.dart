import 'package:kafkalyzer/src/ui/tombstone_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

void main() {
  group('TombstoneWidget', () {
    testWidgets('renders tombstone indicator text and icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TombstoneWidget()),
        ),
      );

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text('TOMBSTONE (Value is NULL)'), findsOneWidget);
    });
  });
}
