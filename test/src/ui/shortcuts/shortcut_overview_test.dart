import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/shortcuts/shortcut_overview_dialog.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('ShortcutOverviewDialog renders macOS vs Linux modifiers', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ShortcutOverviewDialog()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('⌘B'), findsWidgets);

    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ShortcutOverviewDialog()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ctrl+B'), findsWidgets);
  });
}
