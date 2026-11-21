import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

Future<void> confirmSectionReset(
  BuildContext context,
  AppLocalizations l10n,
  String sectionName,
  Future<void> Function() onConfirm,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.resetSectionConfirmTitle(sectionName)),
      content: Text(l10n.resetSectionConfirmBody(sectionName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.resetConfirmAction),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await onConfirm();
  }
}
