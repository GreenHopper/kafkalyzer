import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/settings/presentation/controllers/settings_import_export_controller.dart';

import '../settings_view_test.mocks.dart';

void main() {
  late MockSettingsService settingsService;
  late MockClusterListController clusterListController;

  setUp(() {
    settingsService = MockSettingsService();
    clusterListController = MockClusterListController();
  });

  Future<(SettingsImportExportController, BuildContext, AppLocalizations)>
  pumpHost(WidgetTester tester) async {
    late BuildContext context;
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              context = ctx;
              l10n = AppLocalizations.of(ctx)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (
      SettingsImportExportController(
        settingsService: settingsService,
        clusterListController: clusterListController,
      ),
      context,
      l10n,
    );
  }

  testWidgets(
    'cancelling the credential prompt runs no export',
    (tester) async {
      final (controller, context, l10n) = await pumpHost(tester);

      unawaited(controller.exportConfiguration(context, l10n));
      await tester.pump();
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      verifyNever(
        settingsService.exportConfiguration(
          dialogTitle: anyNamed('dialogTitle'),
          encryptionPassphrase: anyNamed('encryptionPassphrase'),
        ),
      );
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'a failing export reports the error and shows no success message',
    (tester) async {
      final (controller, context, l10n) = await pumpHost(tester);
      when(
        settingsService.exportConfiguration(
          dialogTitle: anyNamed('dialogTitle'),
          encryptionPassphrase: anyNamed('encryptionPassphrase'),
        ),
      ).thenThrow(StateError('disk full'));

      unawaited(controller.exportConfiguration(context, l10n));
      await tester.pump();
      await tester.tap(find.text(l10n.export));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('disk full'), findsOneWidget);
      expect(
        find.text(l10n.configurationExportedSuccessfully),
        findsNothing,
      ); // the blocking progress dialog is gone as well
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
