import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/utils/schema_type_labels.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:kafkalyzer/src/ui/widgets/error_banner.dart';

/// Sidebar browser for Schema Registry subjects, with case-insensitive
/// substring filtering, global compatibility header, and memoised topic/side
/// associations per row.
class SubjectBrowserList extends StatefulWidget {
  final ClusterProfile profile;
  final SchemaController schemaController;
  final List<String> topicNames;
  final ValueChanged<String> onSelectSubject;
  final VoidCallback? onOpenClusterSettings;

  const SubjectBrowserList({
    super.key,
    required this.profile,
    required this.schemaController,
    required this.topicNames,
    required this.onSelectSubject,
    this.onOpenClusterSettings,
  });

  @override
  State<SubjectBrowserList> createState() => _SubjectBrowserListState();
}

class _SubjectBrowserListState extends State<SubjectBrowserList> {
  late final TextEditingController _filterController;
  String _filterQuery = '';

  List<String>? _lastSubjects;
  List<String> _lastTopics = const [];
  String _lastQuery = '';
  List<api.SubjectAssociationDto> _filteredRows = const [];

  bool get _hasRegistryConfigured =>
      widget.profile.schemaRegistryUrl != null &&
      widget.profile.schemaRegistryUrl!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController();
    _ensureLoaded();
  }

  @override
  void didUpdateWidget(covariant SubjectBrowserList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profile.name != oldWidget.profile.name ||
        widget.profile.schemaRegistryUrl !=
            oldWidget.profile.schemaRegistryUrl) {
      _lastSubjects = null;
      _ensureLoaded();
    }
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _ensureLoaded() {
    if (!_hasRegistryConfigured) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.schemaController.fetchSchemas(widget.profile);
      widget.schemaController
          .fetchGlobalCompatibility(widget.profile)
          .catchError((_) => '');
    });
  }

  void _refresh() {
    if (!_hasRegistryConfigured) return;
    widget.schemaController.fetchSchemas(widget.profile, force: true);
    widget.schemaController
        .fetchGlobalCompatibility(widget.profile, force: true)
        .catchError((_) => '');
  }

  void _recomputeRowsIfNeeded(List<String>? subjects) {
    if (subjects == null) {
      _lastSubjects = null;
      _filteredRows = const [];
      return;
    }

    final sameInputs =
        identical(subjects, _lastSubjects) &&
        identical(widget.topicNames, _lastTopics) &&
        _filterQuery == _lastQuery;
    if (sameInputs) return;

    _lastSubjects = subjects;
    _lastTopics = widget.topicNames;
    _lastQuery = _filterQuery;

    final associations = widget.schemaController.associatedTopics(
      widget.profile,
      widget.topicNames,
    );
    if (_filterQuery.isEmpty) {
      _filteredRows = associations;
    } else {
      final needle = _filterQuery.toLowerCase();
      _filteredRows = associations
          .where((a) => a.subject.toLowerCase().contains(needle))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (!_hasRegistryConfigured) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 40,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n?.schemaNoRegistryConfigured ??
                      'No Schema Registry configured for this cluster.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (widget.onOpenClusterSettings != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('subject_browser_configure_registry'),
                    onPressed: widget.onOpenClusterSettings,
                    icon: const Icon(Icons.settings, size: 16),
                    label: Text(
                      l10n?.schemaConfigureRegistryAction ??
                          'Configure Cluster',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: ListenableBuilder(
        listenable: widget.schemaController,
        builder: (context, _) {
          final subjects = widget.schemaController.getSchemas(widget.profile);
          final isLoading = widget.schemaController.isLoading(widget.profile);
          final errorObj =
              widget.schemaController.errorObjectFor(widget.profile) ??
              widget.schemaController.errorFor(widget.profile);
          final globalCompat = widget.schemaController.globalCompatibilityFor(
            widget.profile,
          );

          _recomputeRowsIfNeeded(subjects);

          final countText = errorObj != null && subjects == null
              ? (l10n?.subjectBrowserCountUnknown ?? 'Subjects: unknown')
              : (l10n?.subjectBrowserCount(
                      _filteredRows.length,
                      subjects?.length ?? 0,
                    ) ??
                    '${_filteredRows.length} of ${subjects?.length ?? 0}');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        countText,
                        key: const Key('subject_browser_count'),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    IconButton(
                      key: const Key('subject_browser_refresh'),
                      icon: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      tooltip:
                          l10n?.subjectBrowserRefreshTooltip ??
                          'Refresh subjects',
                      onPressed: isLoading ? null : _refresh,
                    ),
                  ],
                ),
              ),
              if (globalCompat != null && globalCompat.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Text(
                    l10n?.subjectBrowserGlobalCompatibility(globalCompat) ??
                        'Global compatibility: $globalCompat',
                    key: const Key('subject_browser_global_compat'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  key: const Key('subject_browser_filter'),
                  controller: _filterController,
                  onChanged: (value) {
                    setState(() {
                      _filterQuery = value.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText:
                        l10n?.subjectBrowserFilterHint ?? 'Filter subjects…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _filterQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            tooltip: l10n?.clear ?? 'Clear',
                            onPressed: () {
                              _filterController.clear();
                              setState(() {
                                _filterQuery = '';
                              });
                            },
                          )
                        : null,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: _buildBody(
                  context,
                  l10n,
                  colorScheme,
                  subjects: subjects,
                  isLoading: isLoading,
                  errorObj: errorObj,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations? l10n,
    ColorScheme colorScheme, {
    required List<String>? subjects,
    required bool isLoading,
    required Object? errorObj,
  }) {
    if (isLoading && subjects == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorObj != null && subjects == null) {
      final msg = l10n != null
          ? describeSchemaRegistryError(l10n, errorObj)
          : errorObj.toString();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            title: msg,
            onRetry: _refresh,
            retryLabel: l10n?.schemaRetry ?? 'Retry',
          ),
        ),
      );
    }

    if (subjects != null && subjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n?.subjectBrowserEmptyRegistry ??
                'No subjects registered in Schema Registry.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.outline),
          ),
        ),
      );
    }

    if (_filteredRows.isEmpty && _filterQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n?.subjectBrowserNoMatch(_filterQuery) ??
                'No subjects match "$_filterQuery".',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.outline),
          ),
        ),
      );
    }

    return ListView.builder(
      key: const Key('subject_browser_list'),
      itemCount: _filteredRows.length,
      itemBuilder: (context, index) {
        final row = _filteredRows[index];
        final typeState = widget.schemaController.schemaTypeFor(
          widget.profile,
          row.subject,
        );
        final typeLabel = typeState is SchemaTypeKnown
            ? schemaKindLabel(
                l10n,
                typeState.kind,
                otherName: typeState.otherName,
              )
            : null;
        final sideLabel = switch (row.side) {
          api.TopicSideDto.key => l10n?.subjectBrowserSideKey ?? 'Key',
          api.TopicSideDto.value => l10n?.subjectBrowserSideValue ?? 'Value',
          api.TopicSideDto.none => null,
        };
        final subtitleParts = <String>[
          if (row.topic != null)
            row.onCluster
                ? row.topic!
                : (l10n?.schemaViewerTopicNotOnCluster(row.topic!) ??
                      '${row.topic!} (not on cluster)'),
          ?sideLabel,
          ?typeLabel,
        ];

        return ListTile(
          dense: true,
          leading: const Icon(Icons.schema_outlined, size: 18),
          title: Text(
            row.subject,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: subtitleParts.isNotEmpty
              ? Text(
                  subtitleParts.join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          onTap: () => widget.onSelectSubject(row.subject),
        );
      },
    );
  }
}
