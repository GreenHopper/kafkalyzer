import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/tls_transition_controller.dart';

class TlsTransitionDialog extends StatelessWidget {
  final TlsTransitionDecision decision;

  const TlsTransitionDialog({super.key, required this.decision});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final errorText = (decision.errorMessage?.trim().isNotEmpty ?? false)
        ? decision.errorMessage!.trim()
        : '-';

    return AlertDialog(
      icon: Icon(Icons.gpp_maybe_outlined, color: colorScheme.error, size: 32),
      title: Text(l10n.tlsTransitionDialogTitle),
      content: SizedBox(
        width: 480,
        child: Text(
          l10n.tlsTransitionDialogBody(decision.profile.name, errorText),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
          child: Text(l10n.tlsTransitionDisable),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.tlsTransitionKeepEnabled),
        ),
      ],
    );
  }
}
