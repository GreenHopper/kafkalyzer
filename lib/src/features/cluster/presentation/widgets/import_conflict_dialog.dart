import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';

class ImportConflictDialog extends StatefulWidget {
  final String profileName;
  final String suggestedRename;
  final Set<String> takenNormalizedNames;

  const ImportConflictDialog({
    super.key,
    required this.profileName,
    required this.suggestedRename,
    required this.takenNormalizedNames,
  });

  static Future<ImportConflictChoice?> show(
    BuildContext context, {
    required String profileName,
    required String suggestedRename,
    required Set<String> takenNormalizedNames,
  }) {
    return showDialog<ImportConflictChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImportConflictDialog(
        profileName: profileName,
        suggestedRename: suggestedRename,
        takenNormalizedNames: takenNormalizedNames,
      ),
    );
  }

  @override
  State<ImportConflictDialog> createState() => _ImportConflictDialogState();
}

class _ImportConflictDialogState extends State<ImportConflictDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _renameController;

  @override
  void initState() {
    super.initState();
    _renameController = TextEditingController(text: widget.suggestedRename);
  }

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n?.importConflictTitle ?? 'Cluster Profile Conflict'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.importConflictMessage(widget.profileName) ??
                    'A cluster profile named "${widget.profileName}" already exists.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _renameController,
                decoration: InputDecoration(
                  labelText: l10n?.importConflictRename ?? 'Import as new name',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return l10n?.requiredValidation ?? 'Required';
                  }
                  if (widget.takenNormalizedNames.contains(
                    normalizeProfileName(trimmed),
                  )) {
                    return l10n?.clusterNameAlreadyUsed ??
                        'A cluster profile with this name already exists.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const ImportConflictChoice.skip()),
          child: Text(l10n?.importConflictSkip ?? 'Skip'),
        ),
        OutlinedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(
                context,
              ).pop(ImportConflictChoice.rename(_renameController.text.trim()));
            }
          },
          child: Text(l10n?.importConflictRename ?? 'Import as new name'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(const ImportConflictChoice.replace()),
          child: Text(l10n?.importConflictReplace ?? 'Replace existing'),
        ),
      ],
    );
  }
}
