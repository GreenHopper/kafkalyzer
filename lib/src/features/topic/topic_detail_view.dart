import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/search/domain/filter_field_suggestions.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/filter_expression_editing_controller.dart';
import 'package:kafkalyzer/src/features/topic/models/duplicate_navigation_target.dart';
import 'package:kafkalyzer/src/ui/messages/messages_view.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/local_schema_error_formatter.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/local_schema_assignment_dialog.dart';
import 'package:kafkalyzer/src/services/local_schema_assignment_service.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_partition_health_dialog.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_tag.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_config_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_facts_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_analysis_view.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/config/topic_config_view.dart'
    as config_ui;
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/services/time_display_settings.dart';
import 'package:kafkalyzer/src/services/topic_config_service.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart';
import 'package:kafkalyzer/src/ui/topic_progress_tile.dart';
import 'package:kafkalyzer/src/ui/widgets/dropped_messages_indicator.dart';
import 'package:kafkalyzer/src/features/search/domain/filter_terms.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/topic_search_bar.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';

enum StartStrategy { latest, earliest, customOffset, customTimestamp }

enum TopicViewMode { messages, analysis, config }

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
  final FilterExpressionEditingController _filterExpressionController =
      FilterExpressionEditingController();
  FilterFieldSuggestions? _filterSuggestions;
  final TextEditingController _offsetController = TextEditingController();
  final TextEditingController _timestampController = TextEditingController();

  late final ActiveConnectionController activeController;
  late final MessageStreamController streamController;
  late final TopicAnalysisController analysisController;
  late final TopicFactsController factsController;
  late final SchemaController schemaController;
  late final TimeDisplaySettings _timeDisplaySettings;
  TopicConfigController? _configController;
  LocalSchemaAssignmentService? _localSchemaService;
  StoredTopicLocalSchemas? _storedLocalSchemas;
  LocalSchemaStateResult? _localKeyState;
  LocalSchemaStateResult? _localValueState;

  TopicViewMode _viewMode = TopicViewMode.messages;
  final GlobalKey<MessagesViewState> _messagesViewKey =
      GlobalKey<MessagesViewState>();
  int _followResetToken = 0;

  MultiSearchStartStrategy _startStrategy = MultiSearchStartStrategy.latest;
  TopicScanMode _scanMode = TopicScanMode.latestN;

  void _openSchemaView() {
    if (_viewMode != TopicViewMode.messages) {
      setState(() => _viewMode = TopicViewMode.messages);
    }
    _messagesViewKey.currentState?.setActiveView('schema');
  }

  void _handleDuplicateNavigation(DuplicateNavigationTarget target) {
    setState(() {
      _viewMode = TopicViewMode.messages;
      _fastTraceEnabled = false;

      if (target.filterOccurrences) {
        // Clear partition constraint to scan all partitions
        _partitionController.clear();

        // Configure search filter
        if (target.key != null && target.key!.isNotEmpty) {
          _filterController.text = target.key!;
          _searchScope = SearchScope.key;
          _filterType = FilterType.exact;
        } else {
          final preview = target.payloadPreview.trim();
          _filterController.text = preview.length > 200
              ? preview.substring(0, 200)
              : preview;
          _searchScope = SearchScope.value;
          _filterType = FilterType.contains;
        }

        // Configure scan mode to offsetEarliest starting from offset 0
        _scanMode = TopicScanMode.offsetEarliest;
        _startStrategy = MultiSearchStartStrategy.earliest;
        _offsetController.text = '0';

        // Ensure sufficient result limit
        final defaultLimit = _defaultResultLimit();
        final currentMax =
            int.tryParse(_maxResultsController.text) ?? defaultLimit;
        final targetMax = math.max(
          currentMax,
          math.max(defaultLimit, target.count),
        );
        _limitResults = true;
        _maxResultsController.text = targetMax.toString();
      } else {
        // Jump to sample message coordinates
        _partitionController.text = target.samplePartition.toString();
        _offsetController.text = target.sampleOffset.toString();
        _scanMode = TopicScanMode.offsetEarliest;
        _startStrategy = MultiSearchStartStrategy.customOffset;
      }
    });
    startStreaming();
  }

  void _navigateToMessage(int partition, int offset) {
    setState(() {
      _viewMode = TopicViewMode.messages;
      _partitionController.text = partition.toString();
      _offsetController.text = offset.toString();
      _scanMode = TopicScanMode.offsetEarliest;
      _startStrategy = MultiSearchStartStrategy.customOffset;
      _fastTraceEnabled = false;
    });
    startStreaming();
  }

  int _defaultResultLimit() => getIt.isRegistered<SettingsService>()
      ? getIt<SettingsService>().defaultResultLimit.value
      : SettingsService.defaultResultLimitSetting.defaultValue;

  TopicController? topicController;

  TopicMetadata get _currentTopic =>
      topicController?.findTopic(widget.profile, widget.topic.name) ??
      widget.topic;

  @override
  void initState() {
    super.initState();
    _maxResultsController.text = _defaultResultLimit().toString();
    activeController = getIt<ActiveConnectionController>();
    final key = widget.tabId ?? '${widget.profile.name}:${widget.topic.name}';
    streamController = activeController.getStreamController(key);
    analysisController = activeController.getAnalysisController(key);
    factsController = activeController.getTopicFactsController(
      key,
      widget.profile,
      widget.topic.name,
    );
    _timeDisplaySettings = getIt.isRegistered<TimeDisplaySettings>()
        ? getIt<TimeDisplaySettings>()
        : TimeDisplaySettings.fallback;
    schemaController = getIt<SchemaController>();
    _localSchemaService = getIt.isRegistered<LocalSchemaAssignmentService>()
        ? getIt<LocalSchemaAssignmentService>()
        : null;
    _localSchemaService?.addListener(_onLocalSchemaChanged);
    _loadLocalSchemaTagState();
    topicController = getIt.isRegistered<TopicController>()
        ? getIt<TopicController>()
        : null;
    topicController?.ensureConfig(widget.profile, widget.topic.name);
    activeController.addListener(_onActiveConnectionChanged);
    _maybeLoadFactsIfActive();
  }

  bool _isTabActive() {
    final active = activeController.activeTopic;
    if (active == null) return false;
    if (widget.tabId != null) {
      return active.id == widget.tabId;
    }
    return active.topic.name == widget.topic.name &&
        active.profile.name == widget.profile.name;
  }

  void _onLocalSchemaChanged() {
    _loadLocalSchemaTagState();
  }

  Future<void> _loadLocalSchemaTagState({bool refresh = false}) async {
    final service = _localSchemaService;
    if (service == null) return;
    final stored = await service.getForTopic(
      widget.profile.name,
      widget.topic.name,
    );
    LocalSchemaStateResult? keyState;
    LocalSchemaStateResult? valueState;
    if (stored.key != null) {
      keyState = await service.stateFor(
        widget.profile.name,
        widget.topic.name,
        LocalSchemaSide.key,
        refresh: refresh,
      );
    }
    if (stored.value != null) {
      valueState = await service.stateFor(
        widget.profile.name,
        widget.topic.name,
        LocalSchemaSide.value,
        refresh: refresh,
      );
    }
    if (!mounted) return;
    setState(() {
      _storedLocalSchemas = stored;
      _localKeyState = keyState;
      _localValueState = valueState;
    });
  }

  String _shortFormatLabel(
    AppLocalizations? l10n,
    LocalSchemaFormatDto format,
  ) {
    return switch (format) {
      LocalSchemaFormatDto.avro => l10n?.schemaTypeAvro ?? 'Avro',
      LocalSchemaFormatDto.protobufSource ||
      LocalSchemaFormatDto.protobufDescriptor =>
        l10n?.schemaTypeProtobuf ?? 'Protobuf',
      LocalSchemaFormatDto.jsonSchema => l10n?.schemaTypeJson ?? 'JSON Schema',
    };
  }

  Future<void> _openLocalSchemaDialogFromHeader(LocalSchemaSide side) async {
    final service = _localSchemaService;
    if (service == null) return;
    final existing = _storedLocalSchemas?.forSide(side);
    await showDialog<bool>(
      context: context,
      builder: (context) => LocalSchemaAssignmentDialog(
        side: side,
        existing: existing,
        onSave: (assignment) async {
          await service.saveSide(
            widget.profile.name,
            widget.topic.name,
            side,
            assignment,
          );
          await _loadLocalSchemaTagState(refresh: true);
        },
        onRemove: () async {
          await service.removeSide(
            widget.profile.name,
            widget.topic.name,
            side,
          );
          await _loadLocalSchemaTagState(refresh: true);
        },
      ),
    );
  }

  Widget? _buildLocalSchemaHeaderTag(
    BuildContext context,
    AppLocalizations? l10n,
  ) {
    final stored = _storedLocalSchemas;
    if (stored == null || !stored.hasAny || l10n == null) return null;

    final side = stored.value != null
        ? LocalSchemaSide.value
        : LocalSchemaSide.key;
    final assignment = stored.forSide(side)!;
    final stateResult = side == LocalSchemaSide.value
        ? _localValueState
        : _localKeyState;
    final state = stateResult?.state ?? LocalSchemaAssignmentState.unknown;
    final hasError =
        state != LocalSchemaAssignmentState.usable &&
        state != LocalSchemaAssignmentState.unknown;

    final typeLabel = _shortFormatLabel(l10n, assignment.format);
    final baseText = l10n.localSchemaTagPrefix(typeLabel);
    final text = hasError ? '$baseText !' : baseText;
    final tooltip = stateResult?.error != null
        ? describeLocalDecodeError(
            l10n,
            stateResult!.error!.kind,
            stateResult.error!.detail,
          )
        : assignment.path.split(RegExp(r'[/\\]')).last;

    return Tooltip(
      message: tooltip,
      child: TopicTag(
        text,
        key: const Key('topic_local_schema_tag'),
        isSchema: true,
        onTap: () => _openLocalSchemaDialogFromHeader(side),
      ),
    );
  }

  void _onActiveConnectionChanged() {
    _maybeLoadFactsIfActive();
  }

  void _maybeLoadFactsIfActive() {
    if (_isTabActive()) {
      factsController.loadFacts();
    }
  }

  @override
  void dispose() {
    _localSchemaService?.removeListener(_onLocalSchemaChanged);
    activeController.removeListener(_onActiveConnectionChanged);
    _filterController.dispose();
    _filterFieldController.dispose();
    _filterExpressionController.dispose();
    _offsetController.dispose();
    _timestampController.dispose();
    _maxResultsController.dispose();
    _partitionController.dispose();
    _endOffsetController.dispose();
    _endTimestampController.dispose();
    _configController?.dispose();
    super.dispose();
  }

  TopicConfigController _ensureConfigController() {
    final existing = _configController;
    if (existing != null) {
      existing.ensureLoaded();
      return existing;
    }
    final controller = TopicConfigController(
      service: getIt<TopicConfigService>(),
      leftProfile: widget.profile,
      leftTopic: widget.topic.name,
    )..ensureLoaded();
    _configController = controller;
    return controller;
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
      animation: Listenable.merge([
        activeController,
        streamController,
        ?topicController,
      ]),
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
                partitionCount: _currentTopic.metadataKnown
                    ? _currentTopic.partitionCount
                    : null,
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
                filterExpressionController: _filterExpressionController,
                filterSuggestions: _filterSuggestions,
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
                  errorMessage: streamController.error,
                  profile: widget.profile,
                  showFollowControl: true,
                  followResetToken: _followResetToken,
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
            ] else if (_viewMode == TopicViewMode.analysis) ...[
              Expanded(
                child: TopicAnalysisView(
                  topic: widget.topic,
                  profile: widget.profile,
                  controller: analysisController,
                  onNavigateToTarget: _handleDuplicateNavigation,
                  onNavigateToMessage: _navigateToMessage,
                ),
              ),
            ] else ...[
              Expanded(
                child: config_ui.TopicConfigView(
                  controller: _ensureConfigController(),
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
        final compact = constraints.maxWidth < 1220;
        final iconOnly = constraints.maxWidth < 700;

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
          const SizedBox(width: 2),
          _TopicModeButton(
            icon: Icons.tune,
            label: l10n?.topicModeConfig ?? 'Configuration',
            isSelected: _viewMode == TopicViewMode.config,
            showLabel: !iconOnly,
            onTap: () {
              _ensureConfigController();
              setState(() => _viewMode = TopicViewMode.config);
            },
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
        IconButton(
          key: const Key('topic_header_refresh_facts_button'),
          icon: const Icon(Icons.refresh, size: 18),
          tooltip:
              l10n?.topicHeaderRefreshFactsTooltip ?? 'Refresh topic facts',
          onPressed: () {
            topicController?.fetchTopics(widget.profile, force: true);
            factsController.refresh();
          },
        ),
      ],
    );
  }

  void _openPartitionHealthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => TopicPartitionHealthDialog(
        profile: widget.profile,
        topicName: widget.topic.name,
        cleanupPolicy: _currentTopic.cleanupPolicy,
        onOpenAnalysis: () {
          Navigator.of(dialogContext).pop();
          if (mounted) {
            setState(() {
              _viewMode = TopicViewMode.analysis;
            });
          }
        },
      ),
    );
  }

  Widget _buildTopicTags(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final topic = _currentTopic;
    final healthTooltip =
        l10n?.partitionHealthTooltip ??
        'View partition replication & health details';

    if (!topic.metadataKnown) {
      final err = topic.metadataError!;
      final reason = switch (err.kind) {
        TopicMetadataErrorKind.notFound =>
          l10n?.topicMetadataNotFound ?? 'topic not found',
        TopicMetadataErrorKind.notAuthorized =>
          l10n?.topicConfigNotReadable ?? 'not readable — permission?',
        TopicMetadataErrorKind.other =>
          l10n?.topicConfigLoadFailed ?? 'could not be loaded',
      };
      final schemaLabel = resolveTopicSchemaLabel(
        l10n,
        schemaController,
        widget.profile,
        topic.name,
      );
      final localSchemaTag = _buildLocalSchemaHeaderTag(context, l10n);
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          TopicTag(reason, key: const Key('topic_metadata_error_tag')),
          if (schemaLabel != null)
            TopicTag(
              schemaLabel,
              key: const Key('topic_schema_tag'),
              isSchema: true,
            ),
          ?localSchemaTag,
        ],
      );
    }

    final unhealthy =
        (topic.underReplicatedPartitions ?? 0) +
        (topic.leaderlessPartitions ?? 0);
    final configView = topicController?.configFor(widget.profile, topic.name);

    return ListenableBuilder(
      listenable: Listenable.merge([
        factsController,
        _timeDisplaySettings,
        schemaController,
      ]),
      builder: (context, _) {
        final schemaLabel = resolveTopicSchemaLabel(
          l10n,
          schemaController,
          widget.profile,
          topic.name,
        );
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Tooltip(
              message: healthTooltip,
              child: TopicTag(
                l10n?.topicPartitionsLabel(topic.partitionCount) ??
                    "${topic.partitionCount} Partitions",
                key: const Key('topic_partitions_tag'),
                onTap: () => _openPartitionHealthDialog(context),
              ),
            ),
            Tooltip(
              message: healthTooltip,
              child: TopicTag(
                l10n?.topicRfLabel(topic.replicationFactor) ??
                    "RF: ${topic.replicationFactor}",
                key: const Key('topic_rf_tag'),
                onTap: () => _openPartitionHealthDialog(context),
              ),
            ),
            if (unhealthy > 0)
              Tooltip(
                message: healthTooltip,
                child: TopicTag(
                  l10n?.topicHealthWarning(
                        topic.underReplicatedPartitions ?? 0,
                        topic.leaderlessPartitions ?? 0,
                      ) ??
                      'Unhealthy partitions',
                  key: const Key('topic_health_tag'),
                  onTap: () => _openPartitionHealthDialog(context),
                ),
              ),
            ..._buildEstimateTags(context, l10n, topic),
            if (configView != null) ...[
              switch (configView.state) {
                TopicConfigViewState.loading =>
                  topic.cleanupPolicy != null || topic.retentionMs != null
                      ? const SizedBox.shrink()
                      : TopicTag(
                          l10n?.topicConfigLoading ?? 'loading',
                          key: const Key('topic_config_loading_tag'),
                          isConfig: true,
                        ),
                TopicConfigViewState.available => const SizedBox.shrink(),
                TopicConfigViewState.notReadable => TopicTag(
                  l10n?.topicConfigNotReadable ?? 'not readable — permission?',
                  key: const Key('topic_config_not_readable_tag'),
                  isConfig: true,
                ),
                TopicConfigViewState.failed => TopicTag(
                  '${l10n?.topicConfigLoadFailed ?? 'could not be loaded'} · ${l10n?.retry ?? 'Retry'}',
                  key: const Key('topic_config_failed_tag'),
                  isConfig: true,
                  onTap: () =>
                      topicController!.retryConfig(widget.profile, topic.name),
                ),
              },
            ],
            ..._buildRetentionAndPolicyTags(context, l10n, topic, configView),
            _buildTimeRangeWidget(context, l10n, topic),
            if (schemaLabel != null)
              TopicTag(
                schemaLabel,
                key: const Key('topic_schema_tag'),
                isSchema: true,
              ),
            ?_buildLocalSchemaHeaderTag(context, l10n),
          ],
        );
      },
    );
  }

  List<Widget> _buildEstimateTags(
    BuildContext context,
    AppLocalizations? l10n,
    TopicMetadata topic,
  ) {
    final offsets = factsController.offsets;
    switch (offsets.status) {
      case TopicFactStatus.idle:
        return const [];
      case TopicFactStatus.loading:
        return [
          TopicTag(
            l10n?.topicConfigLoading ?? 'loading',
            key: const Key('topic_estimate_loading_tag'),
            isConfig: true,
          ),
        ];
      case TopicFactStatus.error:
        if (offsets.notReadable) {
          return [
            TopicTag(
              l10n?.topicHeaderEstimateNotReadable ?? 'Messages: not readable',
              key: const Key('topic_estimate_not_readable_tag'),
              isConfig: true,
            ),
          ];
        }
        return [
          Tooltip(
            message: offsets.error ?? '',
            child: TopicTag(
              l10n?.topicHeaderEstimateUnknown ?? 'Messages: unknown',
              key: const Key('topic_estimate_unknown_tag'),
              isConfig: true,
            ),
          ),
        ];
      case TopicFactStatus.value:
        final est = offsets.data!;
        if (est.notReadable) {
          return [
            Tooltip(
              message: est.unreadableReason ?? '',
              child: TopicTag(
                l10n?.topicHeaderEstimateNotReadable ??
                    'Messages: not readable',
                key: const Key('topic_estimate_not_readable_tag'),
                isConfig: true,
              ),
            ),
          ];
        }
        if (est.totalSpan == null) {
          return [
            Tooltip(
              message: est.unreadableReason ?? '',
              child: TopicTag(
                l10n?.topicHeaderEstimateUnknown ?? 'Messages: unknown',
                key: const Key('topic_estimate_unknown_tag'),
                isConfig: true,
              ),
            ),
          ];
        }
        final locale = Localizations.localeOf(context).toString();
        final formattedCount = NumberFormat.decimalPattern(
          locale,
        ).format(est.totalSpan!);
        final label =
            l10n?.topicHeaderEstimateValue(formattedCount) ??
            '≈ $formattedCount messages (estimate)';
        final policy =
            factsController.configs.data?.cleanupPolicy ?? topic.cleanupPolicy;
        final isCompactedOrUnknown =
            policy == null || policy.isEmpty || policy.contains('compact');
        final tag = TopicTag(
          label,
          key: const Key('topic_estimate_tag'),
          isConfig: true,
        );
        if (isCompactedOrUnknown && l10n != null) {
          return [
            Tooltip(
              key: const Key('topic_estimate_compaction_tooltip'),
              message: l10n.topicHeaderEstimateCompactedNote,
              child: tag,
            ),
          ];
        }
        return [tag];
    }
  }

  List<Widget> _buildRetentionAndPolicyTags(
    BuildContext context,
    AppLocalizations? l10n,
    TopicMetadata topic,
    TopicConfigView? configView,
  ) {
    final configs = factsController.configs;
    if (configs.status == TopicFactStatus.error && configs.notReadable) {
      if (configView?.state == TopicConfigViewState.notReadable) {
        return const [];
      }
      return [
        TopicTag(
          l10n?.topicHeaderRetentionLabel(
                l10n.topicHeaderRetentionNotReadable,
              ) ??
              'Retention: not readable',
          key: const Key('topic_retention_not_readable_tag'),
          isConfig: true,
        ),
      ];
    }

    final policy =
        configs.data?.cleanupPolicy ??
        configView?.cleanupPolicy ??
        topic.cleanupPolicy;
    final retentionMs =
        configs.data?.retentionMs ??
        configView?.retentionMs ??
        topic.retentionMs;
    final retentionBytes = configs.data?.retentionBytes;

    return [
      if (policy != null && policy.isNotEmpty)
        TopicTag(splitPolicy(policy), isConfig: true),
      if (retentionMs != null && retentionMs.isNotEmpty && l10n != null)
        TopicTag(
          l10n.topicHeaderRetentionLabel(
            formatRetentionDuration(retentionMs, l10n),
          ),
          key: const Key('topic_retention_tag'),
          isConfig: true,
        ),
      if (retentionBytes != null && retentionBytes.isNotEmpty && l10n != null)
        TopicTag(
          l10n.topicHeaderRetentionBytesLabel(
            formatRetentionBytes(retentionBytes, l10n),
          ),
          key: const Key('topic_retention_bytes_tag'),
          isConfig: true,
        ),
    ];
  }

  Widget _buildTimeRangeWidget(
    BuildContext context,
    AppLocalizations? l10n,
    TopicMetadata topic,
  ) {
    final tr = factsController.timeRange;
    switch (tr.status) {
      case TopicFactStatus.idle:
        return Tooltip(
          message:
              l10n?.topicHeaderLoadTimeRangeTooltip(topic.partitionCount) ??
              'Read oldest & newest message timestamps across ${topic.partitionCount} partitions',
          child: OutlinedButton.icon(
            key: const Key('topic_load_time_range_button'),
            onPressed: factsController.loadTimeRange,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(24, 24),
            ),
            icon: const Icon(Icons.schedule, size: 14),
            label: Text(
              l10n?.topicHeaderLoadTimeRange ?? 'Load time range',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        );
      case TopicFactStatus.loading:
        return TopicTag(
          l10n?.topicHeaderTimeRangeLoading ?? 'Loading time range…',
          key: const Key('topic_time_range_loading_tag'),
          isConfig: true,
        );
      case TopicFactStatus.error:
        return TopicTag(
          '${l10n?.topicHeaderTimeRangeError(tr.error ?? '') ?? 'Time range failed'} · ${l10n?.retry ?? 'Retry'}',
          key: const Key('topic_time_range_error_tag'),
          isConfig: true,
          onTap: factsController.loadTimeRange,
        );
      case TopicFactStatus.value:
        final range = tr.data!;
        if (range.allEmpty) {
          return TopicTag(
            l10n?.topicHeaderTimeRangeEmpty ?? 'No messages',
            key: const Key('topic_time_range_empty_tag'),
            isConfig: true,
          );
        }
        final oldest = range.oldest;
        final newest = range.newest;
        if (oldest == null || newest == null) {
          return TopicTag(
            l10n?.topicHeaderTimeRangeUnknown ?? 'Time range: unknown',
            key: const Key('topic_time_range_unknown_tag'),
            isConfig: true,
          );
        }
        final oldestStr = _formatZoneTimestamp(
          context,
          oldest.timestampMs.toInt(),
        );
        final newestStr = _formatZoneTimestamp(
          context,
          newest.timestampMs.toInt(),
        );
        final tooltipLines = <String>[
          'P${oldest.partition} @ ${oldest.offset} (${oldest.timestampType.name})',
          'P${newest.partition} @ ${newest.offset} (${newest.timestampType.name})',
        ];
        final nonFoundReasons = <String>[];
        for (final probe in range.probes) {
          if (probe.oldest.kind != ProbeOutcomeKind.found &&
              probe.oldest.kind != ProbeOutcomeKind.empty) {
            nonFoundReasons.add(
              'P${probe.partition} oldest: ${probe.oldest.reason ?? probe.oldest.kind.name}',
            );
          }
          if (probe.newest.kind != ProbeOutcomeKind.found &&
              probe.newest.kind != ProbeOutcomeKind.empty) {
            nonFoundReasons.add(
              'P${probe.partition} newest: ${probe.newest.reason ?? probe.newest.kind.name}',
            );
          }
        }
        final valueText =
            l10n?.topicHeaderTimeRangeValue(oldestStr, newestStr) ??
            '$oldestStr – $newestStr';
        final mainTag = Tooltip(
          message: tooltipLines.join('\n'),
          child: TopicTag(
            valueText,
            key: const Key('topic_time_range_tag'),
            isConfig: true,
          ),
        );
        if (nonFoundReasons.isEmpty) {
          return mainTag;
        }
        final partialText =
            l10n?.topicHeaderTimeRangePartial(
              range.oldestKnown,
              range.newestKnown,
              range.partitionsTotal,
            ) ??
            'Partial (${range.oldestKnown}/${range.partitionsTotal} oldest, ${range.newestKnown}/${range.partitionsTotal} newest)';
        return Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            mainTag,
            Tooltip(
              key: const Key('topic_time_range_partial_tooltip'),
              message: nonFoundReasons.join('\n'),
              child: TopicTag(
                partialText,
                key: const Key('topic_time_range_partial_tag'),
                isConfig: true,
              ),
            ),
          ],
        );
    }
  }

  String _formatZoneTimestamp(BuildContext context, int timestampMs) {
    final utc = DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true);
    final dt = _timeDisplaySettings.isUtc ? utc : utc.toLocal();
    final formatted = DateFormatUtils.formatDateTime(context, dt);
    if (_timeDisplaySettings.isUtc) {
      return '$formatted UTC';
    }
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absMinutes = offset.inMinutes.abs();
    final hours = absMinutes ~/ 60;
    final mins = absMinutes % 60;
    final offsetLabel = mins == 0
        ? 'UTC$sign$hours'
        : 'UTC$sign$hours:${mins.toString().padLeft(2, '0')}';
    return '$formatted $offsetLabel';
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
    final droppedCount = streamController.droppedCount;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Row(
        children: [
          Expanded(
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
              matchCount: streamController.receivedCount,
              contentPadding: EdgeInsets.zero,
              dense: true,
              extraSubtitle: droppedCount > 0
                  ? DroppedMessagesIndicator(
                      droppedCount: droppedCount,
                      bufferLimit: streamController.bufferLimit,
                    )
                  : null,
              trailing: const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: _buildProgressActions(context, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildProgressActions(BuildContext context, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    final showPauseResume =
        streamController.isStreaming || streamController.isPaused;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showPauseResume)
          if (streamController.isPaused)
            Tooltip(
              message:
                  l10n?.resumeViewTooltip ?? 'Resume updating the message view',
              child: OutlinedButton.icon(
                onPressed: streamController.resume,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: Text(
                  l10n?.resumeViewWithNew(streamController.pendingCount) ??
                      'Resume · ${streamController.pendingCount} new',
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            )
          else
            Tooltip(
              message:
                  l10n?.pauseViewTooltip ??
                  'Pause view updates while keeping the stream active',
              child: OutlinedButton.icon(
                onPressed: streamController.pause,
                icon: const Icon(Icons.pause, size: 16),
                label: Text(l10n?.pauseView ?? 'Pause view'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
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
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
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
    setState(() {
      _followResetToken++;
    });
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

    final parsedTerms = splitFilterTerms(_filterController.text);
    final exprText = _filterExpressionController.text.trim();
    streamController.startStreaming(
      widget.profile,
      widget.topic.name,
      filterTerms: parsedTerms.isNotEmpty ? parsedTerms : null,
      filterField: _filterFieldController.text.isNotEmpty
          ? _filterFieldController.text
          : null,
      filterType: _filterType,
      searchScope: _searchScope,
      filterExpression: exprText.isNotEmpty ? exprText : null,
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
