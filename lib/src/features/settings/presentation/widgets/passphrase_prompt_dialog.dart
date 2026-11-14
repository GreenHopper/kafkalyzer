import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Prompts the user for the passphrase of an encrypted `age` bundle.
///
/// Returns the entered passphrase, or `null` if the user cancels.
class PassphrasePromptDialog extends StatefulWidget {
  final bool previousAttemptFailed;

  const PassphrasePromptDialog({super.key, this.previousAttemptFailed = false});

  static Future<String?> show(
    BuildContext context, {
    bool previousAttemptFailed = false,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          PassphrasePromptDialog(previousAttemptFailed: previousAttemptFailed),
    );
  }

  @override
  State<PassphrasePromptDialog> createState() => _PassphrasePromptDialogState();
}

class _PassphrasePromptDialogState extends State<PassphrasePromptDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _obscured = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isEmpty) return;
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(l10n.importPassphraseTitle),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.previousAttemptFailed) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.importPassphraseWrong,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: _obscured,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: null,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.importPassphraseLabel,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscured ? Icons.visibility : Icons.visibility_off,
                  ),
                  tooltip: _obscured
                      ? l10n.showPassphrase
                      : l10n.hidePassphrase,
                  onPressed: () => setState(() => _obscured = !_obscured),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _controller.text.isEmpty ? null : _submit,
          child: Text(l10n.import),
        ),
      ],
    );
  }
}
