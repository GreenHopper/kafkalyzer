import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/services/diff_ignore_list_service.dart';
import 'package:material_ui/material_ui.dart';

class DiffIgnoreListDialog extends StatefulWidget {
  final String topic;
  final DiffIgnoreListService service;
  final List<String> suggestions;

  const DiffIgnoreListDialog({
    super.key,
    required this.topic,
    required this.service,
    this.suggestions = const [],
  });

  @override
  State<DiffIgnoreListDialog> createState() => _DiffIgnoreListDialogState();
}

class _DiffIgnoreListDialogState extends State<DiffIgnoreListDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleAdd(String rawPath) async {
    final l10n = AppLocalizations.of(context);
    final status = await widget.service.addPath(widget.topic, rawPath);
    if (!mounted) return;
    setState(() {
      switch (status) {
        case DiffIgnoreSaveStatus.saved:
          _errorText = null;
          _controller.clear();
        case DiffIgnoreSaveStatus.emptyPath:
          _errorText =
              l10n?.diffIgnoreEmptyPathError ?? 'Enter a non-empty field path.';
        case DiffIgnoreSaveStatus.duplicate:
          _errorText =
              l10n?.diffIgnoreDuplicatePathError ??
              'This field path is already ignored.';
        case DiffIgnoreSaveStatus.saveFailed:
          _errorText =
              l10n?.diffIgnoreSaveError ??
              'Failed to save ignore list. Change was not persisted.';
      }
    });
  }

  Future<void> _handleRemove(String path) async {
    final l10n = AppLocalizations.of(context);
    final status = await widget.service.removePath(widget.topic, path);
    if (!mounted) return;
    if (status == DiffIgnoreSaveStatus.saveFailed) {
      setState(() {
        _errorText =
            l10n?.diffIgnoreSaveError ??
            'Failed to save ignore list. Change was not persisted.';
      });
    } else {
      setState(() {
        _errorText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paths = widget.service.getPathsSync(widget.topic);
    final remainingSuggestions = widget.suggestions
        .where((s) => !paths.contains(s))
        .toList();

    return AlertDialog(
      title: Text(
        l10n?.diffIgnoreDialogTitle(widget.topic) ??
            'Ignored fields — ${widget.topic}',
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText:
                          l10n?.diffIgnorePathHint ??
                          'Field path (e.g. meta.ts or /items/0/id)',
                      errorText: _errorText,
                      isDense: true,
                    ),
                    onSubmitted: _handleAdd,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _handleAdd(_controller.text),
                  child: Text(l10n?.diffIgnoreAddButton ?? 'Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (paths.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  l10n?.diffIgnoreEmptyList ??
                      'No ignored fields for this topic.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: paths.length,
                  itemBuilder: (context, index) {
                    final path = paths[index];
                    final tooltip =
                        l10n?.diffIgnoreRemoveTooltip(path) ??
                        'Remove ignored field $path';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        path,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      trailing: Semantics(
                        label: tooltip,
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: tooltip,
                          onPressed: () => _handleRemove(path),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (remainingSuggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n?.diffIgnoreSuggestionsTitle ?? 'Suggested volatile fields',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: remainingSuggestions
                    .map(
                      (s) => ActionChip(
                        label: Text(
                          s,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        onPressed: () => _handleAdd(s),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.close ?? 'Close'),
        ),
      ],
    );
  }
}
