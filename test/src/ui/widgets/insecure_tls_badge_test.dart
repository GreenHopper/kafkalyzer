import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/widgets/insecure_tls_badge.dart';

void main() {
  testWidgets('InsecureTlsBadge displays localized label and semantics label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(body: Center(child: InsecureTlsBadge())),
      ),
    );

    expect(find.text('Insecure TLS'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(
          'TLS certificate verification is disabled for this cluster profile.',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'InsecureTlsBadge iconOnly mode hides text label but keeps icon, tooltip and semantics',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: Center(
              child: InsecureTlsBadge(compact: true, iconOnly: true),
            ),
          ),
        ),
      );

      expect(find.text('Insecure TLS'), findsNothing);
      expect(find.byIcon(Icons.gpp_bad_outlined), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(
            'TLS certificate verification is disabled for this cluster profile.',
          ),
        ),
        findsOneWidget,
      );
    },
  );
}
