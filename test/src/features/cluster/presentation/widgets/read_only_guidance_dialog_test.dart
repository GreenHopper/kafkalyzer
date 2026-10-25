import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/read_only_guidance_dialog.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: InkRipple.splashFactory,
      ),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('ReadOnlySecurityBadge and ReadOnlyGuidanceDialog', () {
    testWidgets('renders ReadOnlySecurityBadge with shield icon and label', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(const ReadOnlySecurityBadge()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.text('Read-Only'), findsOneWidget);
    });

    testWidgets(
      'tapping ReadOnlySecurityBadge opens ReadOnlyGuidanceDialog with ACL guidance',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(const ReadOnlySecurityBadge()),
        );
        await tester.pumpAndSettle();

        // Tap the badge
        await tester.tap(find.byType(ReadOnlySecurityBadge));
        await tester.pumpAndSettle();

        // Verify ReadOnlyGuidanceDialog is displayed
        expect(find.byType(ReadOnlyGuidanceDialog), findsOneWidget);
        expect(find.text('Read-Only Architecture & Security'), findsOneWidget);
        expect(find.text('Recommended Least-Privilege ACLs'), findsOneWidget);
        expect(
          find.textContaining('kafka-acls.sh --bootstrap-server'),
          findsNWidgets(2),
        );

        // Verify copy button works
        expect(find.text('Copy ACL Commands'), findsOneWidget);
        await tester.tap(find.text('Copy ACL Commands'));
        await tester.pumpAndSettle();

        // SnackBar shown
        expect(find.byType(SnackBar), findsOneWidget);

        // Verify close button dismisses dialog
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        expect(find.byType(ReadOnlyGuidanceDialog), findsNothing);
      },
    );
  });
}
