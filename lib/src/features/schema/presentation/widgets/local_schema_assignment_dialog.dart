import 'package:file_picker/file_picker.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/schema/presentation/local_schema_error_formatter.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:kafkalyzer/src/services/local_schema_assignment_service.dart';
import 'package:material_ui/material_ui.dart';

typedef LocalSchemaFilePickerFn = Future<String?> Function();

/// Dialog to assign, inspect, update, or remove a local schema file for a
/// topic's key or value side.
class LocalSchemaAssignmentDialog extends StatefulWidget {
  final LocalSchemaSide side;
  final LocalSchemaAssignmentDto? existing;
  final Future<void> Function(LocalSchemaAssignmentDto assignment) onSave;
  final Future<void> Function() onRemove;
  final InspectLocalSchemaFn? inspectLocalSchemaFn;
  final LocalSchemaFilePickerFn? pickFileFn;

  const LocalSchemaAssignmentDialog({
    super.key,
    required this.side,
    this.existing,
    required this.onSave,
    required this.onRemove,
    this.inspectLocalSchemaFn,
    this.pickFileFn,
  });

  static const List<String> allowedExtensions = [
    'avsc',
    'proto',
    'desc',
    'pb',
    'binpb',
    'json',
  ];

  static LocalSchemaFormatDto? guessFormatFromExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.avsc')) return LocalSchemaFormatDto.avro;
    if (lower.endsWith('.proto')) return LocalSchemaFormatDto.protobufSource;
    if (lower.endsWith('.desc') ||
        lower.endsWith('.pb') ||
        lower.endsWith('.binpb')) {
      return LocalSchemaFormatDto.protobufDescriptor;
    }
    if (lower.endsWith('.json')) return LocalSchemaFormatDto.jsonSchema;
    return null;
  }

  @override
  State<LocalSchemaAssignmentDialog> createState() =>
      _LocalSchemaAssignmentDialogState();
}

class _LocalSchemaAssignmentDialogState
    extends State<LocalSchemaAssignmentDialog> {
  String? _path;
  LocalSchemaFormatDto _format = LocalSchemaFormatDto.avro;
  String? _messageType;
  FramingDto _framing = FramingDto.auto;
  LocalSchemaModeDto _mode = LocalSchemaModeDto.fallback;
  LocalSchemaInfo? _info;
  bool _inspecting = false;
  bool _saving = false;
  int _inspectSeq = 0;

  InspectLocalSchemaFn get _inspect =>
      widget.inspectLocalSchemaFn ?? inspectLocalSchema;

  bool get _isProtobuf =>
      _format == LocalSchemaFormatDto.protobufSource ||
      _format == LocalSchemaFormatDto.protobufDescriptor;

  bool get _canSave {
    if (_saving || _inspecting) return false;
    final path = _path;
    final info = _info;
    if (path == null || path.isEmpty || info == null) return false;
    if (info.error != null) return false;
    if (_isProtobuf) {
      if (_messageType == null || !info.messageTypes.contains(_messageType)) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _path = existing.path;
      _format = existing.format;
      _messageType = existing.messageType;
      _framing = existing.framing;
      _mode = existing.mode;
      _runInspect(path: existing.path, format: existing.format);
    }
  }

  Future<void> _pickFile() async {
    final String? pickedPath;
    if (widget.pickFileFn != null) {
      pickedPath = await widget.pickFileFn!();
    } else {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: LocalSchemaAssignmentDialog.allowedExtensions,
      );
      pickedPath = result?.files.single.path;
    }
    if (pickedPath == null || pickedPath.isEmpty || !mounted) return;

    final guessed = LocalSchemaAssignmentDialog.guessFormatFromExtension(
      pickedPath,
    );
    setState(() {
      _path = pickedPath;
      if (guessed != null) {
        _format = guessed;
      }
      _messageType = null;
    });
    await _runInspect(path: pickedPath, format: guessed);
  }

  Future<void> _runInspect({
    required String path,
    LocalSchemaFormatDto? format,
  }) async {
    final seq = ++_inspectSeq;
    setState(() {
      _inspecting = true;
    });
    try {
      final info = await _inspect(
        path: path,
        format: format,
        messageType: _messageType,
      );
      if (!mounted || seq != _inspectSeq) return;
      setState(() {
        _info = info;
        if (format == null && info.detectedFormat != null) {
          _format = info.detectedFormat!;
        }
        if (_isProtobuf) {
          if (_messageType != null &&
              !info.messageTypes.contains(_messageType)) {
            _messageType = null;
          }
          if (_messageType == null && info.messageTypes.length == 1) {
            _messageType = info.messageTypes.single;
          }
        } else {
          _messageType = null;
        }
        _inspecting = false;
      });
    } catch (e) {
      if (!mounted || seq != _inspectSeq) return;
      setState(() {
        _info = LocalSchemaInfo(
          fileName: path.split('/').last,
          messageTypes: const [],
          error: LocalSchemaErrorDto(
            kind: LocalDecodeErrorKindDto.schemaInvalid,
            detail: e.toString(),
          ),
        );
        _inspecting = false;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final assignment = LocalSchemaAssignmentDto(
        path: _path!,
        format: _format,
        messageType: _isProtobuf ? _messageType : null,
        framing: _format == LocalSchemaFormatDto.avro
            ? _framing
            : FramingDto.auto,
        mode: _mode,
        expectedSha256: _info?.sha256Hex,
      );
      await widget.onSave(assignment);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleRemove() async {
    setState(() => _saving = true);
    try {
      await widget.onRemove();
      if (mounted) Navigator.of(context).pop(false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sideLabel = widget.side == LocalSchemaSide.key
        ? l10n.localSchemaSideKey
        : l10n.localSchemaSideValue;
    final fileName =
        _info?.fileName ??
        (_path != null && _path!.isNotEmpty
            ? _path!.split(RegExp(r'[/\\]')).last
            : null);

    return AlertDialog(
      title: Text(l10n.localSchemaDialogTitle(sideLabel)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.localSchemaFileLabel,
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        fileName ?? l10n.localSchemaNoFileSelected,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : _pickFile,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(l10n.localSchemaChooseFile),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<LocalSchemaFormatDto>(
                initialValue: _format,
                decoration: InputDecoration(
                  labelText: l10n.localSchemaFormatLabel,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: LocalSchemaFormatDto.values
                    .map(
                      (f) => DropdownMenuItem(
                        value: f,
                        child: Text(localSchemaFormatLabel(l10n, f)),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (val) {
                        if (val == null) return;
                        setState(() {
                          _format = val;
                          _messageType = null;
                        });
                        if (_path != null && _path!.isNotEmpty) {
                          _runInspect(path: _path!, format: val);
                        }
                      },
              ),
              if (_isProtobuf &&
                  _info != null &&
                  _info!.messageTypes.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _info!.messageTypes.contains(_messageType)
                      ? _messageType
                      : null,
                  hint: Text(l10n.localSchemaMessageTypeHint),
                  decoration: InputDecoration(
                    labelText: l10n.localSchemaMessageTypeLabel,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  items: _info!.messageTypes
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (val) {
                          setState(() => _messageType = val);
                          if (_path != null && _path!.isNotEmpty) {
                            _runInspect(path: _path!, format: _format);
                          }
                        },
                ),
              ],
              if (_format == LocalSchemaFormatDto.avro) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<FramingDto>(
                  initialValue: _framing,
                  decoration: InputDecoration(
                    labelText: l10n.localSchemaFramingLabel,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: FramingDto.auto,
                      child: Text(l10n.localSchemaFramingAuto),
                    ),
                    DropdownMenuItem(
                      value: FramingDto.prefixed,
                      child: Text(l10n.localSchemaFramingPrefixed),
                    ),
                    DropdownMenuItem(
                      value: FramingDto.raw,
                      child: Text(l10n.localSchemaFramingRaw),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (val) {
                          if (val != null) setState(() => _framing = val);
                        },
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<LocalSchemaModeDto>(
                initialValue: _mode,
                decoration: InputDecoration(
                  labelText: l10n.localSchemaModeLabel,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: LocalSchemaModeDto.fallback,
                    child: Text(l10n.localSchemaModeFallback),
                  ),
                  DropdownMenuItem(
                    value: LocalSchemaModeDto.always,
                    child: Text(l10n.localSchemaModeAlways),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (val) {
                        if (val != null) setState(() => _mode = val);
                      },
              ),
              const SizedBox(height: 16),
              if (_inspecting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_info?.error != null)
                _buildErrorBox(context, l10n, _info!.error!)
              else if (_info != null)
                _buildFieldPreview(context, l10n, _info!),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: _saving ? null : _handleRemove,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(l10n.localSchemaRemoveAction),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _canSave ? _handleSave : null,
          child: Text(l10n.localSchemaSaveAction),
        ),
      ],
    );
  }

  Widget _buildErrorBox(
    BuildContext context,
    AppLocalizations l10n,
    LocalSchemaErrorDto error,
  ) {
    final theme = Theme.of(context);
    final showDescriptorHint =
        error.kind == LocalDecodeErrorKindDto.unsupportedProto2 ||
        error.kind == LocalDecodeErrorKindDto.unresolvedImport;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            describeLocalDecodeError(l10n, error.kind, error.detail),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          if (showDescriptorHint) ...[
            const SizedBox(height: 6),
            Text(
              l10n.localSchemaProto2DescriptorHint,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldPreview(
    BuildContext context,
    AppLocalizations l10n,
    LocalSchemaInfo info,
  ) {
    final theme = Theme.of(context);
    final fields = info.fields?.fields ?? const [];

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.localSchemaPreviewTitle,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          if (fields.isEmpty)
            Text(l10n.localSchemaPreviewEmpty, style: theme.textTheme.bodySmall)
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: fields.length,
                itemBuilder: (context, index) {
                  final f = fields[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      left: f.depth * 12.0,
                      top: 2,
                      bottom: 2,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            f.path,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          f.typeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
