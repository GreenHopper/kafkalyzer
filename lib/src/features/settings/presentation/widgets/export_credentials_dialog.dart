import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

class ExportCredentialsChoice {
  final String? passphrase;
  const ExportCredentialsChoice({this.passphrase});
}

class ExportCredentialsDialog extends StatefulWidget {
  final String title;
  final AppLocalizations l10n;

  const ExportCredentialsDialog({
    super.key,
    required this.title,
    required this.l10n,
  });

  @override
  State<ExportCredentialsDialog> createState() =>
      ExportCredentialsDialogState();
}

class ExportCredentialsDialogState extends State<ExportCredentialsDialog> {
  static const int _minPassphraseLength = 12;

  bool _includeCredentials = false;
  bool _obscurePassphrase = true;
  bool _obscureConfirm = true;
  final _passphraseController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final passphrase = _passphraseController.text;
    final confirm = _confirmController.text;
    final tooShort = passphrase.runes.length < _minPassphraseLength;
    final mismatch = confirm.isNotEmpty && passphrase != confirm;
    final canExport =
        !_includeCredentials || (!tooShort && passphrase == confirm);

    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.includeCredentialsInExport),
                value: _includeCredentials,
                onChanged: (val) {
                  setState(() {
                    _includeCredentials = val ?? false;
                  });
                },
              ),
              if (_includeCredentials) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _passphraseController,
                  obscureText: _obscurePassphrase,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: null,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.exportPassphraseLabel,
                    errorText: passphrase.isNotEmpty && tooShort
                        ? l10n.exportPassphraseTooShort(_minPassphraseLength)
                        : null,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassphrase
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      tooltip: _obscurePassphrase
                          ? l10n.showPassphrase
                          : l10n.hidePassphrase,
                      onPressed: () {
                        setState(() {
                          _obscurePassphrase = !_obscurePassphrase;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: null,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.exportPassphraseConfirmLabel,
                    errorText: mismatch ? l10n.exportPassphraseMismatch : null,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      tooltip: _obscureConfirm
                          ? l10n.showPassphrase
                          : l10n.hidePassphrase,
                      onPressed: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.includeCredentialsWarning,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.exportPassphraseNotRecoverable,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: canExport
              ? () => Navigator.of(context).pop(
                  ExportCredentialsChoice(
                    passphrase: _includeCredentials
                        ? _passphraseController.text
                        : null,
                  ),
                )
              : null,
          child: Text(l10n.export),
        ),
      ],
    );
  }
}
