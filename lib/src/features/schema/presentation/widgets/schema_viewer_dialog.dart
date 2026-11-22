import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:kafkalyzer/src/services/topic_name_source.dart';

class _ViewerTarget {
  final String? topicName;
  final String? subject;
  final int? version;

  const _ViewerTarget({this.topicName, this.subject, this.version});
}

/// Modal dialog wrapper for standalone schema inspection, delegating display
/// to [TopicSchemaInspectorView] and supporting subject-first inspection,
/// reference navigation with a back stack, and associated topic navigation.
class SchemaViewerDialog extends StatefulWidget {
  final ClusterProfile profile;
  final String? topicName;
  final String? initialSubject;
  final int? initialVersion;
  final SchemaController controller;
  final ValueChanged<String>? onPinToColumn;
  final ValueChanged<String>? onFilterByField;
  final ValueChanged<String>? onNavigateToTopic;
  final TopicNameSource topicNames;

  const SchemaViewerDialog({
    super.key,
    required this.profile,
    this.topicName,
    this.initialSubject,
    this.initialVersion,
    required this.controller,
    this.onPinToColumn,
    this.onFilterByField,
    this.onNavigateToTopic,
    required this.topicNames,
  }) : assert(topicName != null || initialSubject != null);

  @override
  State<SchemaViewerDialog> createState() => _SchemaViewerDialogState();
}

class _SchemaViewerDialogState extends State<SchemaViewerDialog> {
  final List<_ViewerTarget> _history = [];
  late _ViewerTarget _current;

  List<String> _associatedTopics = const [];
  List<String>? _knownClusterTopics;
  bool _isLoadingAssociatedTopics = false;
  Object? _associatedTopicsError;

  @override
  void initState() {
    super.initState();
    _current = _ViewerTarget(
      topicName: widget.topicName,
      subject: widget.initialSubject,
      version: widget.initialVersion,
    );
    _loadAssociatedTopics();
  }

  /// `null` means the cluster topic list is not loaded, which is not the same
  /// as a cluster without topics.
  List<String>? _resolveAvailableTopics() =>
      widget.topicNames.topicNames(widget.profile);

  Future<void> _loadAssociatedTopics() async {
    final subject = _current.subject;
    if (subject == null) {
      setState(() {
        _associatedTopics = const [];
        _knownClusterTopics = null;
        _isLoadingAssociatedTopics = false;
        _associatedTopicsError = null;
      });
      return;
    }

    final available = _resolveAvailableTopics();
    setState(() {
      _isLoadingAssociatedTopics = true;
      _associatedTopicsError = null;
      _knownClusterTopics = available;
    });

    try {
      final associated = await widget.controller.getAssociatedTopics(
        subject,
        available ?? const [],
      );
      if (!mounted) return;
      setState(() {
        _associatedTopics = associated;
        _isLoadingAssociatedTopics = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _associatedTopicsError = e;
        _isLoadingAssociatedTopics = false;
      });
    }
  }

  void _openReference(String subject, int version) {
    setState(() {
      _history.add(_current);
      _current = _ViewerTarget(subject: subject, version: version);
    });
    _loadAssociatedTopics();
  }

  void _goBack() {
    if (_history.isEmpty) return;
    setState(() {
      _current = _history.removeLast();
    });
    _loadAssociatedTopics();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width * 0.9,
          maxHeight: size.height * 0.9,
          minWidth: 800 > size.width * 0.9 ? size.width * 0.9 : 800,
          minHeight: 500 > size.height * 0.9 ? size.height * 0.9 : 500,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (_history.isNotEmpty) ...[
                    IconButton(
                      key: const Key('schema_viewer_back_button'),
                      icon: const Icon(Icons.arrow_back),
                      tooltip:
                          l10n?.schemaViewerBackTooltip ??
                          'Back to previous schema',
                      onPressed: _goBack,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(child: _buildHeader(context, l10n)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n?.close ?? 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (_current.subject != null)
              _buildAssociatedTopicsBar(context, l10n),
            const Divider(height: 1),
            Expanded(
              child: TopicSchemaInspectorView(
                key: ValueKey(
                  '${_current.topicName}|${_current.subject}|${_current.version}',
                ),
                profile: widget.profile,
                topicName: _current.topicName ?? _current.subject ?? '',
                initialSubject: _current.subject,
                initialVersion: _current.version,
                controller: widget.controller,
                onPinToColumn: widget.onPinToColumn,
                onFilterByField: widget.onFilterByField,
                onOpenReference: _openReference,
                onNavigateToTopic: widget.onNavigateToTopic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.schemaViewerTitle ?? 'Schema Viewer',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          _current.subject != null
              ? (l10n?.schemaViewerSubjectTitle(_current.subject!) ??
                    'Schema: ${_current.subject}')
              : '${l10n?.topicCol ?? 'Topic'}: ${_current.topicName}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildAssociatedTopicsBar(
    BuildContext context,
    AppLocalizations? l10n,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoadingAssociatedTopics) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              l10n?.schemaViewerAssociatedTopicsLoading ??
                  'Loading associated topics…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    if (_associatedTopicsError != null) {
      final description = l10n != null
          ? describeSchemaRegistryError(l10n, _associatedTopicsError!)
          : _associatedTopicsError.toString();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: colorScheme.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n?.schemaViewerAssociatedTopicsError(description) ??
                    'Failed to resolve associated topics: $description',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ),
            TextButton.icon(
              key: const Key('schema_viewer_retry_associations'),
              onPressed: _loadAssociatedTopics,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n?.schemaRetry ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    if (_associatedTopics.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final topic in _associatedTopics)
            if (_knownClusterTopics != null &&
                _knownClusterTopics!.contains(topic) &&
                widget.onNavigateToTopic != null)
              ActionChip(
                key: Key('associated_topic_open_$topic'),
                avatar: const Icon(Icons.topic_outlined, size: 16),
                label: Text(topic),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onNavigateToTopic!(topic);
                },
              )
            else
              Chip(
                key: Key('associated_topic_missing_$topic'),
                avatar: Icon(
                  Icons.link_off,
                  size: 16,
                  color: colorScheme.outline,
                ),
                label: Text(
                  _knownClusterTopics == null
                      ? topic
                      : (_knownClusterTopics!.contains(topic)
                            ? topic
                            : (l10n?.schemaViewerTopicNotOnCluster(topic) ??
                                  '$topic (not on cluster)')),
                  style: TextStyle(color: colorScheme.outline),
                ),
              ),
        ],
      ),
    );
  }
}
