import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/messages/messages_view.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_partition_health_dialog.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_tag.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_analysis_view.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart';
import 'package:kafkalyzer/src/ui/topic_progress_tile.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/topic_search_bar.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';

enum StartStrategy { latest, earliest, customOffset, customTimestamp }

enum TopicViewMode { messages, analysis }

class TopicDetailView extends StatefulWidget {
  final TopicMetadata topic;
  final ClusterProfile profile;
  final String? tabId;

  const TopicDetailView({
    super.key,
    required this.topic,
    required this.profile,
    this.tabId,
  });

  @override
  State<TopicDetailView> createState() => _TopicDetailViewState();
}

class _TopicDetailViewState extends State<TopicDetailView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _filterController = TextEditingController();
  final TextEditingController _filterFieldController = TextEditingController();
  final TextEditingController _offsetController = TextEditingController();
  final TextEditingController _timestampController = TextEditingController();

  late final ActiveConnectionController activeController;
  late final MessageStreamController streamController;
  late final TopicAnalysisController analysisController;
  late final SchemaController schemaController;

  TopicViewMode _viewMode = TopicViewMode.messages;
  final GlobalKey<MessagesViewState> _messagesViewKey =
      GlobalKey<MessagesViewState>();

  MultiSearchStartStrategy _startStrategy = MultiSearchStartStrategy.latest;
  TopicScanMode _scanMode = TopicScanMode.latestN;

  void _openSchemaView() {
    if (_viewMode != TopicViewMode.messages) {
      setState(() => _viewMode = TopicViewMode.messages);
    }
    _messagesViewKey.currentState?.setActiveView('schema');
  }

  @override
  void initState() {
    super.initState();
    activeController = getIt<ActiveConnectionController>();
    final key = widget.tabId ?? '${widget.profile.name}:${widget.topic.name}';
    streamController = activeController.getStreamController(key);
    analysisController = activeController.getAnalysisController(key);
    schemaController = getIt<SchemaController>();
  }

  @override
  void dispose() {
    _filterController.dispose();
    _filterFieldController.dispose();
    _offsetController.dispose();
    _timestampController.dispose();
    _maxResultsController.dispose();
    _partitionController.dispose();
    _endOffsetController.dispose();
    _endTimestampController.dispose();
    super.dispose();
  }

  // State
  FilterType _filterType = FilterType.contains;
  SearchScope _searchScope = SearchScope.both;
  bool _fastTraceEnabled = false;
  final TextEditingController _partitionController = TextEditingController();

  MultiSearchEndStrategy _endStrategy = MultiSearchEndStrategy.latest;
  final TextEditingController _endOffsetController = TextEditingController();
  final TextEditingController _endTimestampController = TextEditingController();

  bool _limitResults = true;
  final TextEditingController _maxResultsController = TextEditingController(
    text: "200",
  );

  int? _convertToTimestamp(String text) {
    if (text.isEmpty) return null;
    final date = DateFormatUtils.parseDateTime(context, text);
    if (date != null) return date.millisecondsSinceEpoch;
    return int.tryParse(text);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: Listenable.merge([activeController, streamController]),
      builder: (context, child) {
        final messages = streamController.messages;
        final colorScheme = Theme.of(context).colorScheme;

        return Column(
          children: [
            Material(
              color: colorScheme.surface,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: _buildHeader(context),
              ),
            ),
            if (_viewMode == TopicViewMode.messages) ...[
              TopicSearchBar(
                scanMode: _scanMode,
                onScanModeChanged: (mode) => setState(() => _scanMode = mode),
                quickFilterController: _filterController,
                fieldController: _filterFieldController,
                filterType: _filterType,
                onFilterTypeChanged: (type) =>
                    setState(() => _filterType = type),
                searchScope: _searchScope,
                onSearchScopeChanged: (scope) =>
                    setState(() => _searchScope = scope),
                limitResults: _limitResults,
                onLimitResultsChanged: (limit) =>
                    setState(() => _limitResults = limit),
                maxResultsController: _maxResultsController,
                partitionController: _partitionController,
                fastTraceEnabled: _fastTraceEnabled,
                onFastTraceEnabledChanged: (val) =>
                    setState(() => _fastTraceEnabled = val),
                startStrategy: _startStrategy,
                onStartStrategyChanged: (strategy) =>
                    setState(() => _startStrategy = strategy),
                startOffsetController: _offsetController,
                startTimestampController: _timestampController,
                endStrategy: _endStrategy,
                onEndStrategyChanged: (strategy) =>
                    setState(() => _endStrategy = strategy),
                endOffsetController: _endOffsetController,
                endTimestampController: _endTimestampController,
                onStart: startStreaming,
                schemaFieldsFetcher: () => schemaController.fetchSchemaFields(
                  widget.profile,
                  widget.topic.name,
                ),
              ),
              Expanded(
                child: MessagesView(
                  key: _messagesViewKey,
                  preferencesKey: "topic_detail_view_mode",
                  messages: messages,
                  onFetchLatest: startStreaming,
                  isStreaming: streamController.isStreaming,
                  profile: widget.profile,
                  schemaViewBuilderWithPin:
                      (context, searchPhrase, onPinToColumn) {
                        return TopicSchemaInspectorView(
                          profile: widget.profile,
                          topicName: widget.topic.name,
                          searchPhrase: searchPhrase,
                          controller: schemaController,
                          onPinToColumn: onPinToColumn,
                          onFilterByField: (field) {
                            setState(() {
                              _filterFieldController.text = field;
                            });
                          },
                        );
                      },
                ),
              ),
            ] else ...[
              Expanded(
                child: TopicAnalysisView(
                  topic: widget.topic,
                  profile: widget.profile,
                  controller: analysisController,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final closeButton = IconButton(
      onPressed: () {
        final isRunning =
            streamController.isStreaming || analysisController.isAnalyzing;
        confirmCloseTab(
          context,
          isOperationRunning: isRunning,
          onClose: () {
            if (widget.tabId != null) {
              activeController.closeTopicTab(widget.tabId!);
            } else {
              activeController.closeTopic(widget.topic, widget.profile.name);
            }
          },
        );
      },
      icon: const Icon(Icons.close),
      tooltip: l10n?.closeTab ?? "Close Tab",
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHigh,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // shortcut: fixed breakpoints, raise the second one if the pane gets wider sidebars
        final compact = constraints.maxWidth < 1100;
        final iconOnly = constraints.maxWidth < 620;

        final identityRow = Row(
          children: [
            closeButton,
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTopicTitleRow(context),
                        const SizedBox(height: 8),
                        _buildTopicTags(context),
                      ],
                    ),
                  ),
                  if (hasSchema(
                    schemaController,
                    widget.profile,
                    widget.topic.name,
                  )) ...[
                    const SizedBox(width: 12),
                    _buildSchemaButton(context),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildTopicModeSwitcher(context, colorScheme, l10n, iconOnly),
          ],
        );

        if (_viewMode != TopicViewMode.messages) {
          return identityRow;
        }

        final progressTile = Align(
          alignment: Alignment.centerRight,
          child: _buildProgressTile(context, colorScheme),
        );

        if (!compact) {
          return Row(
            children: [
              ...identityRow.children,
              const SizedBox(width: 16),
              Expanded(child: progressTile),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [identityRow, const SizedBox(height: 8), progressTile],
        );
      },
    );
  }

  Widget _buildTopicModeSwitcher(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
    bool iconOnly,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TopicModeButton(
            icon: Icons.list_alt_rounded,
            label: l10n?.messagesView ?? 'Messages',
            isSelected: _viewMode == TopicViewMode.messages,
            showLabel: !iconOnly,
            onTap: () => setState(() => _viewMode = TopicViewMode.messages),
          ),
          const SizedBox(width: 2),
          _TopicModeButton(
            icon: Icons.analytics_outlined,
            label: l10n?.topicAnalysis ?? 'Analysis',
            isSelected: _viewMode == TopicViewMode.analysis,
            showLabel: !iconOnly,
            onTap: () => setState(() => _viewMode = TopicViewMode.analysis),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicTitleRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            widget.topic.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          tooltip: l10n?.copyTopicName ?? "Copy Topic Name",
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.topic.name));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n?.topicNameCopied ?? "Topic name copied"),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }

  void _openPartitionHealthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => TopicPartitionHealthDialog(
        profile: widget.profile,
        topicName: widget.topic.name,
      ),
    );
  }

  Widget _buildTopicTags(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unhealthy =
        (widget.topic.underReplicatedPartitions ?? 0) +
        (widget.topic.leaderlessPartitions ?? 0);
    final healthTooltip =
        l10n?.partitionHealthTooltip ??
        'View partition replication & health details';

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        Tooltip(
          message: healthTooltip,
          child: TopicTag(
            "${widget.topic.partitionCount} Partitions",
            key: const Key('topic_partitions_tag'),
            onTap: () => _openPartitionHealthDialog(context),
          ),
        ),
        Tooltip(
          message: healthTooltip,
          child: TopicTag(
            "RF: ${widget.topic.replicationFactor}",
            key: const Key('topic_rf_tag'),
            onTap: () => _openPartitionHealthDialog(context),
          ),
        ),
        if (unhealthy > 0)
          Tooltip(
            message: healthTooltip,
            child: TopicTag(
              l10n?.topicHealthWarning(
                    widget.topic.underReplicatedPartitions ?? 0,
                    widget.topic.leaderlessPartitions ?? 0,
                  ) ??
                  'Unhealthy partitions',
              key: const Key('topic_health_tag'),
              onTap: () => _openPartitionHealthDialog(context),
            ),
          ),
        if (widget.topic.cleanupPolicy != null)
          TopicTag(splitPolicy(widget.topic.cleanupPolicy!), isConfig: true),
        if (widget.topic.retentionMs != null)
          TopicTag(formatRetention(widget.topic.retentionMs!), isConfig: true),
        if (hasSchema(schemaController, widget.profile, widget.topic.name))
          const TopicTag("Avro", isSchema: true),
      ],
    );
  }

  Widget _buildSchemaButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: OutlinedButton.icon(
        onPressed: _openSchemaView,
        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
        icon: const Icon(Icons.schema_outlined, size: 16),
        label: Text(AppLocalizations.of(context)?.schemaAction ?? "Schema"),
      ),
    );
  }

  Widget _buildProgressTile(BuildContext context, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: TopicProgressTile(
        topic: l10n?.scanProgressTitle ?? "Scan Progress",
        status: streamController.isStreaming
            ? StepStatus.running
            : (streamController.totalConsumed > 0
                  ? StepStatus.completed
                  : StepStatus.pending),
        progress: SearchProgress(
          streamController.totalConsumed,
          streamController.totalToScan,
          startTime: streamController.startTime,
        ),
        matchCount: streamController.messages.length,
        contentPadding: EdgeInsets.zero,
        dense: true,
        trailing: _buildProgressActions(context, colorScheme),
      ),
    );
  }

  Widget _buildProgressActions(BuildContext context, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (streamController.isStreaming)
          FilledButton.icon(
            onPressed: () => streamController.stopStreaming(),
            icon: const Icon(Icons.stop, size: 16),
            label: Text(l10n?.stop ?? 'Stop'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          )
        else
          FilledButton.icon(
            onPressed: startStreaming,
            icon: const Icon(Icons.play_arrow, size: 16),
            label: Text(l10n?.stream ?? 'Stream'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: streamController.clearMessages,
          icon: const Icon(Icons.delete_sweep, size: 16),
          tooltip: l10n?.clearMessagesTooltip ?? "Clear Messages",
          style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }

  void startStreaming() {
    int? startOffset;
    int? startTimestamp;

    if (_startStrategy == MultiSearchStartStrategy.customOffset) {
      startOffset = int.tryParse(_offsetController.text);
    } else if (_startStrategy == MultiSearchStartStrategy.customTimestamp) {
      final date = DateFormatUtils.parseDateTime(
        context,
        _timestampController.text,
      );
      if (date != null) {
        startTimestamp = date.millisecondsSinceEpoch;
      } else {
        startTimestamp = int.tryParse(_timestampController.text);
      }
    } else if (_startStrategy == MultiSearchStartStrategy.earliest) {
      startOffset = 0;
    }

    int? endOffset;
    int? endTimestamp;

    if (_endStrategy == MultiSearchEndStrategy.customOffset) {
      endOffset = int.tryParse(_endOffsetController.text);
    } else if (_endStrategy == MultiSearchEndStrategy.customTimestamp) {
      endTimestamp = _convertToTimestamp(_endTimestampController.text);
    }

    streamController.startStreaming(
      widget.profile,
      widget.topic.name,
      filterTerms: _filterController.text.isNotEmpty
          ? _filterController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : null,
      filterField: _filterFieldController.text.isNotEmpty
          ? _filterFieldController.text
          : null,
      filterType: _filterType,
      searchScope: _searchScope,
      fastTraceEnabled: _fastTraceEnabled,
      startOffset: startOffset,
      startTimestamp: startTimestamp,
      startPartition: _fastTraceEnabled
          ? null
          : int.tryParse(_partitionController.text),
      maxResults: _limitResults
          ? int.tryParse(_maxResultsController.text)
          : null,
      endOffset: endOffset,
      endTimestamp: endTimestamp,
      runForever: _endStrategy == MultiSearchEndStrategy.live,
      startFromTail: _startStrategy == MultiSearchStartStrategy.latest,
    );
  }
}

class _TopicModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback onTap;

  const _TopicModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            if (!showLabel) const SizedBox(width: 4),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
