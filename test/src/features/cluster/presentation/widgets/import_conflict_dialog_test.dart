import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/import_conflict_dialog.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<ImportConflictChoice?> openAndTap(
    WidgetTester tester,
    Future<void> Function() act,
  ) async {
    ImportConflictChoice? result = const ImportConflictChoice.skip();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ImportConflictDialog.show(
                  context,
                  profileName: 'Prod',
                  suggestedRename: 'Prod (imported)',
                  takenNormalizedNames: const {'prod', 'staging'},
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    return result;
  }

  group('ImportConflictDialog', () {
    testWidgets('returns replace when Replace existing is tapped', (
      tester,
    ) async {
      final result = await openAndTap(tester, () async {
        await tester.tap(find.text('Replace existing'));
      });
      expect(result?.action, ImportConflictAction.replace);
    });

    testWidgets('returns skip when Skip is tapped', (tester) async {
      final result = await openAndTap(tester, () async {
        await tester.tap(find.text('Skip'));
      });
      expect(result?.action, ImportConflictAction.skip);
    });

    testWidgets('returns null when Cancel is tapped', (tester) async {
      final result = await openAndTap(tester, () async {
        await tester.tap(find.text('Cancel'));
      });
      expect(result, isNull);
    });

    testWidgets('validates unique rename and returns rename choice', (
      tester,
    ) async {
      final result = await openAndTap(tester, () async {
        // Conflicting name is rejected.
        await tester.enterText(find.byType(TextFormField), ' STAGING ');
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Import as new name'),
        );
        await tester.pump();
        expect(
          find.text('A cluster profile with this name already exists.'),
          findsOneWidget,
        );

        // Unique name succeeds.
        await tester.enterText(find.byType(TextFormField), 'Prod EU');
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Import as new name'),
        );
      });
      expect(result?.action, ImportConflictAction.rename);
      expect(result?.newName, 'Prod EU');
    });
  });
}
