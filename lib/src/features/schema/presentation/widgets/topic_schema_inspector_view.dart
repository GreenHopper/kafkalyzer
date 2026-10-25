import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/utils/schema_simplifier.dart';
import 'package:kafkalyzer/src/ui/json_or_string_viewer.dart';

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

  String? _keySchema;
  String? _valueSchema;
  dynamic _simplifiedKeySchema;
  dynamic _simplifiedValueSchema;
  bool _isLoading = true;
  String? _error;

  // Version selection for a schema opened from a single message.
  List<int> _versions = const [];
  int? _selectedVersion;

  int get _totalMatches => _keyMatchCount + _valueMatchCount;

  bool get _hasRegistryConfigured =>
      widget.profile.schemaRegistryUrl != null &&
      widget.profile.schemaRegistryUrl!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? getIt<SchemaController>();
    _searchQuery = widget.searchPhrase ?? "";
    _searchController = TextEditingController(text: _searchQuery);
    _loadSchemas();
  }

  @override
  void didUpdateWidget(covariant TopicSchemaInspectorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.topicName != oldWidget.topicName ||
        widget.profile.name != oldWidget.profile.name ||
        widget.initialSubject != oldWidget.initialSubject ||
        widget.initialVersion != oldWidget.initialVersion) {
      _loadSchemas();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      final content = selected == null
          ? null
          : await _controller.fetchSchemaContent(
              widget.profile,
              subject,
              version: selected,
            );

      dynamic parsed;
      if (content != null) {
        try {
          parsed = simplifyAvroSchema(jsonDecode(content));
        } catch (_) {}
      }

      if (mounted) {
        final isKeySide = subject.endsWith('-key');
        setState(() {
          _versions = versions;
          _selectedVersion = selected;
          _keySchema = isKeySide ? content : null;
          _valueSchema = isKeySide ? null : content;
          _simplifiedKeySchema = isKeySide ? parsed : null;
          _simplifiedValueSchema = isKeySide ? null : parsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _versions = const [];
          _selectedVersion = version;
          _error = e.toString();
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
        _keySchema = null;
        _valueSchema = null;
        _simplifiedKeySchema = null;
        _simplifiedValueSchema = null;
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
      final schemas = _controller.getSchemas(widget.profile);
      String? keyContent;
      String? valueContent;

      if (schemas != null) {
        if (schemas.contains("${widget.topicName}-key")) {
          keyContent = await _controller.fetchSchemaContent(
            widget.profile,
            "${widget.topicName}-key",
          );
        }
        if (schemas.contains("${widget.topicName}-value")) {
          valueContent = await _controller.fetchSchemaContent(
            widget.profile,
            "${widget.topicName}-value",
          );
        }
      }

      dynamic parsedKey;
      dynamic parsedValue;
      if (keyContent != null) {
        try {
          parsedKey = simplifyAvroSchema(jsonDecode(keyContent));
        } catch (_) {}
      }
      if (valueContent != null) {
        try {
          parsedValue = simplifyAvroSchema(jsonDecode(valueContent));
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _keySchema = keyContent;
          _valueSchema = valueContent;
          _simplifiedKeySchema = parsedKey;
          _simplifiedValueSchema = parsedValue;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
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
            child: (_keySchema == null && _valueSchema == null)
                ? _buildNoSchemaFound(context, colorScheme, l10n)
                : _buildSchemaViewers(context, colorScheme, l10n),
          ),
        ],
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
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: l10n?.previousMatchTooltip ?? "Previous match",
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    onPressed: _jumpToNextMatch,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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

    final hasBoth = _keySchema != null && _valueSchema != null;

    if (hasBoth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: _buildViewer(
              key: _keyViewerKey,
              title: keyTitle,
              rawContent: _keySchema!,
              preParsedJson: _simplifiedKeySchema,
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
              rawContent: _valueSchema!,
              preParsedJson: _simplifiedValueSchema,
              persistenceKey: 'topic_schema_value_${widget.topicName}',
              isKey: false,
            ),
          ),
        ],
      );
    } else if (_keySchema != null) {
      return _buildViewer(
        key: _keyViewerKey,
        title: keyTitle,
        rawContent: _keySchema!,
        preParsedJson: _simplifiedKeySchema,
        persistenceKey: 'topic_schema_key_${widget.topicName}',
        isKey: true,
      );
    } else {
      return _buildViewer(
        key: _valueViewerKey,
        title: valueTitle,
        rawContent: _valueSchema!,
        preParsedJson: _simplifiedValueSchema,
        persistenceKey: 'topic_schema_value_${widget.topicName}',
        isKey: false,
      );
    }
  }

  Widget _buildViewer({
    required GlobalKey<JsonOrStringViewerState> key,
    required String title,
    required String rawContent,
    required dynamic preParsedJson,
    required String persistenceKey,
    required bool isKey,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: JsonOrStringViewer(
        key: key,
        title: title,
        rawContent: rawContent,
        preParsedJson: preParsedJson,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
                  l10n?.schemaConfigureRegistryAction ?? "Configure Cluster",
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoSchemaFound(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
              l10n?.noAvroSchemaFound ?? "No Avro schema found for this topic.",
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
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              l10n != null
                  ? l10n.errorLoadingSchema(_error!)
                  : "Error loading schema: $_error",
              style: TextStyle(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadSchemas,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n?.schemaRetry ?? "Retry"),
            ),
          ],
        ),
      ),
    );
  }
}
