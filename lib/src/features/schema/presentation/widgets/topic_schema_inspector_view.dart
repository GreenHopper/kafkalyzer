import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/ui/local_schema_error_formatter.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/local_schema_assignment_dialog.dart';
import 'package:kafkalyzer/src/services/local_schema_assignment_service.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/schema_diff_dialog.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/schema_viewer_dialog.dart';
import 'package:kafkalyzer/src/features/schema/utils/schema_simplifier.dart';
import 'package:kafkalyzer/src/features/schema/utils/schema_type_labels.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:kafkalyzer/src/services/topic_name_source.dart';
import 'package:kafkalyzer/src/ui/json_or_string_viewer.dart';
import 'package:kafkalyzer/src/ui/widgets/error_banner.dart';
import 'package:kafkalyzer/src/ui/widgets/export_notification_helper.dart';

/// Builds a nested display map from flat [api.SchemaFieldEntryDto] items
/// using the `name : Type` key format expected by [JsonOrStringViewer].
Map<String, dynamic> buildSchemaFieldDisplayMap(
  List<api.SchemaFieldEntryDto> entries,
) {
  return _buildFieldSubtree(entries, 0, entries.length);
}

Map<String, dynamic> _buildFieldSubtree(
  List<api.SchemaFieldEntryDto> entries,
  int start,
  int end,
) {
  final map = <String, dynamic>{};
  var i = start;
  while (i < end) {
    final entry = entries[i];
    var childEnd = i + 1;
    while (childEnd < end && entries[childEnd].depth > entry.depth) {
      childEnd++;
    }

    final typeSuffix = entry.repeated
        ? '${entry.typeLabel} (repeated)'
        : entry.typeLabel;
    final key = '${entry.name} : $typeSuffix';

    if (childEnd > i + 1) {
      map[key] = _buildFieldSubtree(entries, i + 1, childEnd);
    } else {
      var leaf = typeSuffix;
      if (entry.unresolvedReference != null) {
        leaf = '$leaf (unresolved: ${entry.unresolvedReference})';
      }
      map[key] = leaf;
    }
    i = childEnd;
  }
  return map;
}

class _LoadedSchemaSide {
  final api.SubjectSchemaViewDto view;
  final dynamic preParsedJson;
  final String? unavailableReason;
  final String? unsupportedTypeName;
  final bool simplifyFailed;
  final String? compatibilityLevel;
  final bool compatibilityInherited;
  final Object? compatibilityError;

  const _LoadedSchemaSide({
    required this.view,
    this.preParsedJson,
    this.unavailableReason,
    this.unsupportedTypeName,
    this.simplifyFailed = false,
    this.compatibilityLevel,
    this.compatibilityInherited = false,
    this.compatibilityError,
  });
}

/// A reusable, non-blocking Avro schema inspector for displaying Key and Value schemas
/// of a Kafka topic with real-time in-schema search, match stepper navigation, and
/// field-level actions for table column projection and search filtering.
class TopicSchemaInspectorView extends StatefulWidget {
  final ClusterProfile profile;
  final String topicName;
  final String? searchPhrase;
  final ValueChanged<String>? onPinToColumn;
  final ValueChanged<String>? onFilterByField;
  final bool isEmbedded;
  final VoidCallback? onOpenClusterSettings;
  final SchemaController? controller;

  /// Opens one exact subject instead of the topic's latest schemas — used when the
  /// schema of a single message is requested.
  final String? initialSubject;
  final int? initialVersion;
  final void Function(String subject, int version)? onOpenReference;
  final ValueChanged<String>? onNavigateToTopic;
  final LocalSchemaAssignmentService? localSchemaService;
  final InspectLocalSchemaFn? inspectLocalSchemaFn;
  final LocalSchemaFilePickerFn? pickLocalSchemaFileFn;

  const TopicSchemaInspectorView({
    super.key,
    required this.profile,
    required this.topicName,
    this.searchPhrase,
    this.onPinToColumn,
    this.onFilterByField,
    this.isEmbedded = false,
    this.onOpenClusterSettings,
    this.controller,
    this.initialSubject,
    this.initialVersion,
    this.onOpenReference,
    this.onNavigateToTopic,
    this.localSchemaService,
    this.inspectLocalSchemaFn,
    this.pickLocalSchemaFileFn,
  });

  @override
  State<TopicSchemaInspectorView> createState() =>
      _TopicSchemaInspectorViewState();
}

class _TopicSchemaInspectorViewState extends State<TopicSchemaInspectorView> {
  late final SchemaController _controller;
  late final TextEditingController _searchController;
  String _searchQuery = "";

  // Viewer Keys
  final GlobalKey<JsonOrStringViewerState> _keyViewerKey = GlobalKey();
  final GlobalKey<JsonOrStringViewerState> _valueViewerKey = GlobalKey();

  // Search State
  int _keyMatchCount = 0;
  int _valueMatchCount = 0;
  int _currentMatchIndex = 0;

  _LoadedSchemaSide? _keySide;
  _LoadedSchemaSide? _valueSide;
  bool _isLoading = true;
  Object? _error;

  // Version selection for a schema opened from a single message.
  List<int> _versions = const [];
  int? _selectedVersion;

  LocalSchemaAssignmentService? _localSchemaService;
  StoredTopicLocalSchemas? _storedLocalSchemas;
  LocalSchemaStateResult? _keyLocalState;
  LocalSchemaStateResult? _valueLocalState;

  int get _totalMatches => _keyMatchCount + _valueMatchCount;

  bool get _hasRegistryConfigured =>
      widget.profile.schemaRegistryUrl != null &&
      widget.profile.schemaRegistryUrl!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? getIt<SchemaController>();
    _localSchemaService =
        widget.localSchemaService ??
        (getIt.isRegistered<LocalSchemaAssignmentService>()
            ? getIt<LocalSchemaAssignmentService>()
            : null);
    _localSchemaService?.addListener(_onLocalSchemaChanged);
    _searchQuery = widget.searchPhrase ?? "";
    _searchController = TextEditingController(text: _searchQuery);
    _loadSchemas();
    _loadLocalSchemas();
  }

  @override
  void didUpdateWidget(covariant TopicSchemaInspectorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.topicName != oldWidget.topicName ||
        widget.profile.name != oldWidget.profile.name ||
        widget.initialSubject != oldWidget.initialSubject ||
        widget.initialVersion != oldWidget.initialVersion) {
      _loadSchemas();
      _loadLocalSchemas();
    }
  }

  @override
  void dispose() {
    _localSchemaService?.removeListener(_onLocalSchemaChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onLocalSchemaChanged() {
    _loadLocalSchemas();
  }

  Future<void> _loadLocalSchemas({bool refresh = false}) async {
    final service = _localSchemaService;
    if (service == null) return;
    final stored = await service.getForTopic(
      widget.profile.name,
      widget.topicName,
    );
    LocalSchemaStateResult? keyState;
    LocalSchemaStateResult? valueState;
    if (stored.key != null) {
      keyState = await service.stateFor(
        widget.profile.name,
        widget.topicName,
        LocalSchemaSide.key,
        refresh: refresh,
      );
    }
    if (stored.value != null) {
      valueState = await service.stateFor(
        widget.profile.name,
        widget.topicName,
        LocalSchemaSide.value,
        refresh: refresh,
      );
    }
    if (!mounted) return;
    setState(() {
      _storedLocalSchemas = stored;
      _keyLocalState = keyState;
      _valueLocalState = valueState;
    });
  }

  Future<_LoadedSchemaSide> _loadSide(String subject, {int? version}) async {
    final view = await _controller.fetchSubjectSchemaView(
      widget.profile,
      subject,
      version: version,
    );

    String? compatLevel;
    bool inherited = false;
    Object? compatError;
    try {
      final subjectCompat = await _controller.fetchSubjectCompatibility(
        widget.profile,
        subject,
      );
      if (subjectCompat != null) {
        compatLevel = subjectCompat;
        inherited = false;
      } else {
        compatLevel = await _controller.fetchGlobalCompatibility(
          widget.profile,
        );
        inherited = true;
      }
    } catch (e) {
      compatError = e;
    }

    dynamic preParsed;
    String? unavailableReason = view.fields.unavailableReason;
    String? unsupportedTypeName;
    bool simplifyFailed = false;

    if (unavailableReason == null) {
      switch (view.schema.schemaType) {
        case api.SchemaKindDto.avro:
          try {
            preParsed = simplifyAvroSchema(jsonDecode(view.schema.schema));
          } catch (_) {
            simplifyFailed = true;
          }
        case api.SchemaKindDto.json:
        case api.SchemaKindDto.protobuf:
          preParsed = buildSchemaFieldDisplayMap(view.fields.fields);
        case api.SchemaKindDto.other:
          unsupportedTypeName = view.schema.otherSchemaType ?? 'UNKNOWN';
      }
    }

    return _LoadedSchemaSide(
      view: view,
      preParsedJson: preParsed,
      unavailableReason: unavailableReason,
      unsupportedTypeName: unsupportedTypeName,
      simplifyFailed: simplifyFailed,
      compatibilityLevel: compatLevel,
      compatibilityInherited: inherited,
      compatibilityError: compatError,
    );
  }

  /// Loads one exact subject/version, as recorded by a message. A subject or
  /// version the registry no longer serves ends in the normal error state.
  Future<void> _loadSubjectVersion(String subject, int? version) async {
    try {
      final versions = await _controller.fetchSchemaVersions(
        widget.profile,
        subject,
      );
      final selected = version != null && versions.contains(version)
          ? version
          : (versions.isNotEmpty ? versions.last : version);
      final side = selected == null
          ? null
          : await _loadSide(subject, version: selected);

      if (mounted) {
        final isKeySide = subject.endsWith('-key');
        setState(() {
          _versions = versions;
          _selectedVersion = selected;
          _keySide = isKeySide ? side : null;
          _valueSide = isKeySide ? null : side;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _versions = const [];
          _selectedVersion = version;
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSchemas() async {
    if (!_hasRegistryConfigured) {
      setState(() {
        _isLoading = false;
        _error = null;
        _keySide = null;
        _valueSide = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final messageSubject = widget.initialSubject;
    if (messageSubject != null) {
      await _loadSubjectVersion(messageSubject, widget.initialVersion);
      return;
    }

    try {
      await _controller.fetchSchemas(widget.profile);
      final schemaError = _controller.errorFor(widget.profile);
      if (schemaError != null) {
        if (mounted) {
          setState(() {
            _error = _controller.errorObjectFor(widget.profile) ?? schemaError;
            _isLoading = false;
          });
        }
        return;
      }
      final schemas = _controller.getSchemas(widget.profile);
      _LoadedSchemaSide? keySide;
      _LoadedSchemaSide? valueSide;

      if (schemas != null) {
        if (schemas.contains("${widget.topicName}-key")) {
          keySide = await _loadSide("${widget.topicName}-key");
        }
        if (schemas.contains("${widget.topicName}-value")) {
          valueSide = await _loadSide("${widget.topicName}-value");
        }
      }

      if (mounted) {
        setState(() {
          _keySide = keySide;
          _valueSide = valueSide;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  /// Version chooser for a schema opened from a message: the version the message
  /// was written with is the active one, and switching re-loads that version.
  Widget _buildVersionSelector(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
  ) {
    final versionLabel = l10n?.schemaVersionLabel ?? 'Version';
    return DropdownButton<int>(
      key: const Key('schema_version_selector'),
      hint: Text(
        versionLabel,
        style: TextStyle(fontSize: widget.isEmbedded ? 12 : 13),
      ),
      value: _versions.contains(_selectedVersion) ? _selectedVersion : null,
      items: [
        for (final version in _versions)
          DropdownMenuItem(
            value: version,
            child: Text(
              '$versionLabel $version',
              style: TextStyle(fontSize: widget.isEmbedded ? 12 : 13),
            ),
          ),
      ],
      onChanged: (version) {
        final subject = widget.initialSubject;
        if (version == null || subject == null || version == _selectedVersion) {
          return;
        }
        _loadSubjectVersion(subject, version);
      },
    );
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _currentMatchIndex = 0;
    });
  }

  void _jumpToNextMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _totalMatches;
    });
    _jumpToCurrent();
  }

  void _jumpToPreviousMatch() {
    if (_totalMatches == 0) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _totalMatches) % _totalMatches;
    });
    _jumpToCurrent();
  }

  void _jumpToCurrent() {
    if (_currentMatchIndex < _keyMatchCount) {
      _keyViewerKey.currentState?.jumpToMatch(_currentMatchIndex);
    } else {
      _valueViewerKey.currentState?.jumpToMatch(
        _currentMatchIndex - _keyMatchCount,
      );
    }
  }

  void _handleFilterByField(String fieldPath) {
    if (widget.onFilterByField != null) {
      widget.onFilterByField!(fieldPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.schemaFieldFilterApplied(fieldPath) ??
                'Filter field set to \'$fieldPath\'',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasRegistryConfigured) {
      return _buildNoRegistryConfigured(context, colorScheme, l10n);
    }

    if (_error != null) {
      return _buildErrorState(context, colorScheme, l10n);
    }

    final padding = widget.isEmbedded ? 8.0 : 16.0;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar with in-schema search
          _buildToolbar(context, colorScheme, l10n),
          SizedBox(height: widget.isEmbedded ? 8 : 12),
          // Content viewers or no schema found
          Expanded(
            child: (_keySide == null && _valueSide == null)
                ? _buildNoSchemaFound(context, colorScheme, l10n)
                : _buildSchemaViewers(context, colorScheme, l10n),
          ),
        ],
      ),
    );
  }

  void _openSchemaDiffDialog(BuildContext context) {
    final subject =
        widget.initialSubject ??
        (_valueSide != null
            ? "${widget.topicName}-value"
            : "${widget.topicName}-key");
    showDialog<void>(
      context: context,
      builder: (ctx) => SchemaDiffDialog(
        profile: widget.profile,
        subject: subject,
        initialBaseVersion: _selectedVersion,
        initialCompareVersion: _selectedVersion,
        controller: _controller,
        topicNames: getIt<TopicNameSource>(),
        onNavigateToTopic: widget.onNavigateToTopic,
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
  ) {
    final searchHint = l10n != null ? l10n.schemaSearchHint : "Search...";

    return Row(
      children: [
        if (_versions.isNotEmpty) ...[
          _buildVersionSelector(context, colorScheme, l10n),
          const SizedBox(width: 8),
        ],
        if (_hasRegistryConfigured) ...[
          IconButton(
            key: const Key('schema_compare_button'),
            tooltip: l10n?.compareSchemaVersions ?? "Compare Versions",
            icon: const Icon(Icons.difference_outlined, size: 20),
            onPressed: () => _openSchemaDiffDialog(context),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Container(
            height: widget.isEmbedded ? 34 : 38,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(
                  Icons.search,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(fontSize: widget.isEmbedded ? 12 : 13),
                    decoration: InputDecoration(
                      hintText: searchHint,
                      hintStyle: TextStyle(
                        fontSize: widget.isEmbedded ? 12 : 13,
                        color: colorScheme.outline,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    tooltip: AppLocalizations.of(context)?.clear ?? 'Clear',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged("");
                    },
                  ),
                if (_searchQuery.isNotEmpty && _totalMatches > 0) ...[
                  Text(
                    "${_currentMatchIndex + 1}/$_totalMatches",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                    onPressed: _jumpToPreviousMatch,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n?.previousMatchTooltip ?? "Previous match",
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    onPressed: _jumpToNextMatch,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n?.nextMatchTooltip ?? "Next match",
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSchemaViewers(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
  ) {
    final keyTitle = l10n?.keySchemaTitle ?? "Key Schema";
    final valueTitle = l10n?.valueSchemaTitle ?? "Value Schema";

    final hasBoth = _keySide != null && _valueSide != null;

    final localSection = _buildLocalSchemaSection(
      context,
      colorScheme,
      l10n,
      compact: true,
    );

    if (hasBoth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (localSection != null) ...[
            localSection,
            const SizedBox(height: 12),
          ],
          Expanded(
            flex: 2,
            child: _buildViewer(
              key: _keyViewerKey,
              title: keyTitle,
              side: _keySide!,
              persistenceKey: 'topic_schema_key_${widget.topicName}',
              isKey: true,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 5,
            child: _buildViewer(
              key: _valueViewerKey,
              title: valueTitle,
              side: _valueSide!,
              persistenceKey: 'topic_schema_value_${widget.topicName}',
              isKey: false,
            ),
          ),
        ],
      );
    } else if (_keySide != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (localSection != null) ...[
            localSection,
            const SizedBox(height: 12),
          ],
          Expanded(
            child: _buildViewer(
              key: _keyViewerKey,
              title: keyTitle,
              side: _keySide!,
              persistenceKey: 'topic_schema_key_${widget.topicName}',
              isKey: true,
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (localSection != null) ...[
            localSection,
            const SizedBox(height: 12),
          ],
          Expanded(
            child: _buildViewer(
              key: _valueViewerKey,
              title: valueTitle,
              side: _valueSide!,
              persistenceKey: 'topic_schema_value_${widget.topicName}',
              isKey: false,
            ),
          ),
        ],
      );
    }
  }

  Future<void> _copySchema(
    BuildContext context,
    api.SubjectSchemaDto schema,
    AppLocalizations? l10n,
  ) async {
    await Clipboard.setData(ClipboardData(text: schema.schema));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.schemaCopiedSnackBar ?? 'Schema copied to clipboard',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveSchema(
    BuildContext context,
    api.SubjectSchemaDto schema,
    AppLocalizations? l10n,
  ) async {
    final ext = schemaFileExtension(schema.schemaType);
    final fileName = '${schema.subject}-v${schema.version}.$ext';
    final outputFile = await FilePicker.saveFile(
      dialogTitle: l10n?.schemaSaveDialogTitle ?? 'Save Schema',
      fileName: fileName,
    );
    if (outputFile == null) return;

    try {
      await File(outputFile).writeAsString(schema.schema);
      if (!context.mounted) return;
      showExportSuccessSnackBar(
        context,
        message:
            l10n?.schemaSavedSuccess(outputFile) ??
            'Schema saved to $outputFile',
        filePath: outputFile,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n?.schemaSaveFailed(e.toString()) ??
                  'Failed to save schema: $e',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  void _openReference(BuildContext context, api.SchemaReferenceDto ref) {
    if (widget.onOpenReference != null) {
      widget.onOpenReference!(ref.subject, ref.version);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => SchemaViewerDialog(
        profile: widget.profile,
        initialSubject: ref.subject,
        initialVersion: ref.version,
        controller: _controller,
        topicNames: getIt<TopicNameSource>(),
      ),
    );
  }

  String _compatibilityText(_LoadedSchemaSide side, AppLocalizations? l10n) {
    if (side.compatibilityError != null) {
      final reason = l10n != null
          ? describeSchemaRegistryError(l10n, side.compatibilityError!)
          : side.compatibilityError.toString();
      return l10n?.schemaCompatibilityUnknown(reason) ??
          'Compatibility: unknown ($reason)';
    }
    final level = side.compatibilityLevel;
    if (level == null) {
      return l10n?.schemaCompatibilityUnknown('unknown') ??
          'Compatibility: unknown';
    }
    final prefix =
        l10n?.schemaCompatibilityPrefix(level) ?? 'Compatibility: $level';
    final scope = side.compatibilityInherited
        ? (l10n?.schemaCompatibilityInherited ?? 'inherited')
        : (l10n?.schemaCompatibilitySubject ?? 'set on subject');
    return '$prefix ($scope)';
  }

  String? _sideNotice(_LoadedSchemaSide side, AppLocalizations? l10n) {
    if (side.unavailableReason != null) {
      return l10n?.schemaRawUnavailableNotice(side.unavailableReason!) ??
          'Structured view unavailable: ${side.unavailableReason}';
    }
    if (side.unsupportedTypeName != null) {
      return l10n?.schemaUnsupportedTypeNotice(side.unsupportedTypeName!) ??
          'Structured view is not supported for schema type ${side.unsupportedTypeName}.';
    }
    if (side.simplifyFailed) {
      return l10n?.schemaRawUnavailableNotice('Invalid Avro JSON') ??
          'Structured view unavailable: Invalid Avro JSON';
    }
    return null;
  }

  Widget _buildViewer({
    required GlobalKey<JsonOrStringViewerState> key,
    required String title,
    required _LoadedSchemaSide side,
    required String persistenceKey,
    required bool isKey,
  }) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final schema = side.view.schema;
    final typeLabel = schemaKindLabel(
      l10n,
      schema.schemaType,
      otherName: schema.otherSchemaType,
    );
    final versionLabel =
        l10n?.schemaVersionBadge(schema.version) ?? 'v${schema.version}';
    final idLabel = l10n?.schemaIdBadge(schema.id) ?? 'ID ${schema.id}';
    final notice = _sideNotice(side, l10n);
    final showMessages =
        side.view.fields.kind == api.SchemaKindDto.protobuf &&
        side.view.fields.messages.length > 1;
    final copyTooltip = l10n?.schemaCopyTooltip ?? 'Copy schema';
    final saveTooltip = l10n?.schemaSaveTooltip ?? 'Save schema';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                        '$typeLabel · $versionLabel · $idLabel',
                        style: textTheme.labelSmall,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _compatibilityText(side, l10n),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Semantics(
                      label: copyTooltip,
                      button: true,
                      child: IconButton(
                        key: Key('schema_copy_${isKey ? 'key' : 'value'}'),
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        tooltip: copyTooltip,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _copySchema(context, schema, l10n),
                      ),
                    ),
                    Semantics(
                      label: saveTooltip,
                      button: true,
                      child: IconButton(
                        key: Key('schema_save_${isKey ? 'key' : 'value'}'),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        tooltip: saveTooltip,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _saveSchema(context, schema, l10n),
                      ),
                    ),
                  ],
                ),
                if (schema.references.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n?.schemaReferencesLabel ?? 'References:',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      for (final ref in schema.references)
                        ActionChip(
                          label: Text(
                            l10n?.schemaReferenceChip(
                                  ref.name,
                                  ref.subject,
                                  ref.version,
                                ) ??
                                '${ref.name} (${ref.subject} v${ref.version})',
                            style: textTheme.labelSmall,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openReference(context, ref),
                        ),
                    ],
                  ),
                ],
                if (showMessages) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n?.schemaMessagesLabel(
                          side.view.fields.messages.join(', '),
                        ) ??
                        'Messages: ${side.view.fields.messages.join(', ')}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (notice != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      notice,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: JsonOrStringViewer(
              key: key,
              title: title,
              rawContent: schema.schema,
              preParsedJson: side.preParsedJson,
              expand: true,
              persistenceKey: persistenceKey,
              searchQuery: _searchQuery,
              focusedMatchIndex: _getFocusedMatchIndex(isKey),
              onMatchCountChanged: (count) {
                if (isKey) {
                  if (_keyMatchCount != count) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _keyMatchCount = count);
                    });
                  }
                } else {
                  if (_valueMatchCount != count) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _valueMatchCount = count);
                    });
                  }
                }
              },
              onPinToColumn: widget.onPinToColumn,
              onFilterByField: _handleFilterByField,
            ),
          ),
        ],
      ),
    );
  }

  int? _getFocusedMatchIndex(bool isKey) {
    if (_totalMatches == 0) return null;
    if (isKey) {
      return _currentMatchIndex < _keyMatchCount ? _currentMatchIndex : null;
    } else {
      return _currentMatchIndex >= _keyMatchCount
          ? (_currentMatchIndex - _keyMatchCount)
          : null;
    }
  }

  Widget _buildNoRegistryConfigured(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
  ) {
    final localSection = _buildLocalSchemaSection(
      context,
      colorScheme,
      l10n,
      compact: false,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n?.schemaNoRegistryConfigured ??
                      "No Schema Registry configured for this cluster.",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.onOpenClusterSettings != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: widget.onOpenClusterSettings,
                    icon: const Icon(Icons.settings, size: 16),
                    label: Text(
                      l10n?.schemaConfigureRegistryAction ??
                          "Configure Cluster",
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (localSection != null) ...[
            const SizedBox(height: 24),
            localSection,
          ],
        ],
      ),
    );
  }

  Widget _buildNoSchemaFound(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
  ) {
    final localSection = _buildLocalSchemaSection(
      context,
      colorScheme,
      l10n,
      compact: false,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.data_object_outlined,
                  size: 48,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n?.noSchemaFound ?? "No schema found for this topic.",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "${widget.topicName}-key / ${widget.topicName}-value",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          if (localSection != null) ...[
            const SizedBox(height: 24),
            localSection,
          ],
        ],
      ),
    );
  }

  Future<void> _openLocalSchemaDialog(LocalSchemaSide side) async {
    final service = _localSchemaService;
    if (service == null) return;
    final existing = _storedLocalSchemas?.forSide(side);
    await showDialog<bool>(
      context: context,
      builder: (context) => LocalSchemaAssignmentDialog(
        side: side,
        existing: existing,
        inspectLocalSchemaFn: widget.inspectLocalSchemaFn,
        pickFileFn: widget.pickLocalSchemaFileFn,
        onSave: (assignment) async {
          await service.saveSide(
            widget.profile.name,
            widget.topicName,
            side,
            assignment,
          );
          await _loadLocalSchemas(refresh: true);
        },
        onRemove: () async {
          await service.removeSide(widget.profile.name, widget.topicName, side);
          await _loadLocalSchemas(refresh: true);
        },
      ),
    );
  }

  Widget? _buildLocalSchemaSection(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n, {
    required bool compact,
  }) {
    final service = _localSchemaService;
    if (service == null || l10n == null) return null;

    final stored = _storedLocalSchemas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stored?.unreadable == true) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              l10n.localSchemaUnreadableBanner(stored?.unreadableReason ?? ''),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final keyCard = _buildLocalSideCard(
              context,
              colorScheme,
              l10n,
              side: LocalSchemaSide.key,
              assignment: stored?.key,
              stateResult: _keyLocalState,
              compact: compact,
            );
            final valueCard = _buildLocalSideCard(
              context,
              colorScheme,
              l10n,
              side: LocalSchemaSide.value,
              assignment: stored?.value,
              stateResult: _valueLocalState,
              compact: compact,
            );
            if (constraints.maxWidth < 820) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [keyCard, const SizedBox(height: 12), valueCard],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: keyCard),
                const SizedBox(width: 12),
                Expanded(child: valueCard),
              ],
            );
          },
        ),
      ],
    );
  }

  String _localStateLabel(
    AppLocalizations l10n,
    LocalSchemaAssignmentState state,
  ) {
    return switch (state) {
      LocalSchemaAssignmentState.usable => l10n.localSchemaStateUsable,
      LocalSchemaAssignmentState.changed => l10n.localSchemaStateChanged,
      LocalSchemaAssignmentState.fileNotFound =>
        l10n.localSchemaStateFileNotFound,
      LocalSchemaAssignmentState.fileUnreadable =>
        l10n.localSchemaStateFileUnreadable,
      LocalSchemaAssignmentState.schemaInvalid =>
        l10n.localSchemaStateSchemaInvalid,
      LocalSchemaAssignmentState.messageTypeMissing =>
        l10n.localSchemaStateMessageTypeMissing,
      LocalSchemaAssignmentState.unknown => l10n.localSchemaStateUnknown,
    };
  }

  Widget _buildLocalSideCard(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations l10n, {
    required LocalSchemaSide side,
    required LocalSchemaAssignmentDto? assignment,
    required LocalSchemaStateResult? stateResult,
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final sideLabel = side == LocalSchemaSide.key
        ? l10n.localSchemaSideKey
        : l10n.localSchemaSideValue;
    final state = stateResult?.state ?? LocalSchemaAssignmentState.unknown;
    final isError =
        assignment != null &&
        state != LocalSchemaAssignmentState.usable &&
        state != LocalSchemaAssignmentState.unknown;
    final fields = stateResult?.info?.fields?.fields ?? const [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError
              ? colorScheme.error.withValues(alpha: 0.6)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '${l10n.localSchemaCardTitle} ($sideLabel)',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (assignment != null)
                Chip(
                  label: Text(
                    _localStateLabel(l10n, state),
                    style: theme.textTheme.labelSmall,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  backgroundColor: isError
                      ? colorScheme.errorContainer
                      : colorScheme.secondaryContainer,
                ),
            ],
          ),
          if (assignment == null) ...[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => _openLocalSchemaDialog(side),
              icon: const Icon(Icons.upload_file, size: 16),
              label: Text(l10n.localSchemaAssignAction),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              assignment.path.split(RegExp(r'[/\\]')).last,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              [
                localSchemaFormatLabel(l10n, assignment.format),
                if (assignment.messageType != null) assignment.messageType!,
                assignment.mode == LocalSchemaModeDto.always
                    ? l10n.localSchemaModeAlways
                    : l10n.localSchemaModeFallback,
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (stateResult?.error != null) ...[
              const SizedBox(height: 6),
              Text(
                describeLocalDecodeError(
                  l10n,
                  stateResult!.error!.kind,
                  stateResult.error!.detail,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (state == LocalSchemaAssignmentState.changed)
                  FilledButton.tonal(
                    onPressed: () async {
                      await _localSchemaService?.confirmChanged(
                        widget.profile.name,
                        widget.topicName,
                        side,
                      );
                      await _loadLocalSchemas(refresh: true);
                    },
                    child: Text(l10n.localSchemaConfirmChangedAction),
                  ),
                OutlinedButton(
                  onPressed: () => _openLocalSchemaDialog(side),
                  child: Text(l10n.localSchemaChangeAction),
                ),
                TextButton(
                  onPressed: () async {
                    await _localSchemaService?.removeSide(
                      widget.profile.name,
                      widget.topicName,
                      side,
                    );
                    await _loadLocalSchemas(refresh: true);
                  },
                  child: Text(l10n.localSchemaRemoveAction),
                ),
              ],
            ),
            if (!compact && fields.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 180,
                child: JsonOrStringViewer(
                  title: l10n.localSchemaPreviewTitle,
                  rawContent: '',
                  preParsedJson: buildSchemaFieldDisplayMap(fields),
                  expand: true,
                  persistenceKey:
                      'local_schema_${side.name}_${widget.topicName}',
                  searchQuery: _searchQuery,
                  onPinToColumn: widget.onPinToColumn,
                  onFilterByField: _handleFilterByField,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
  ) {
    final description = l10n != null
        ? describeSchemaRegistryError(l10n, _error!)
        : _error.toString();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ErrorBanner(
            title:
                l10n?.errorLoadingSchema(description) ??
                "Error loading schema: $description",
            onRetry: _loadSchemas,
            retryLabel: l10n?.schemaRetry ?? "Retry",
          ),
        ),
      ),
    );
  }
}
