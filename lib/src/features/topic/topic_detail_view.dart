import 'dart:math' as math;
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
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_detail_fact_tags.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_detail_tags.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_detail_progress_tile.dart';
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
import 'package:kafkalyzer/src/features/search/domain/filter_terms.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/topic_search_bar.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';

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

  ({Widget? tag, bool isPinned, double estimatedWidth})
  _buildLocalSchemaFactItem(BuildContext context, AppLocalizations? l10n) {
    final stored = _storedLocalSchemas;
    if (stored == null || !stored.hasAny || l10n == null) {
      return (tag: null, isPinned: false, estimatedWidth: 0);
    }

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

    return (
      tag: Tooltip(
        message: tooltip,
        child: TopicTag(
          text,
          key: const Key('topic_local_schema_tag'),
          isSchema: true,
          onTap: () => _openLocalSchemaDialogFromHeader(side),
        ),
      ),
      isPinned: hasError,
      estimatedWidth: estimateTagWidth(text),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTopicTitleRow(context),
                        const SizedBox(height: 8),
                        TopicDetailTags(
                profile: widget.profile,
                topic: _currentTopic,
                topicController: topicController,
                factsController: factsController,
                schemaController: schemaController,
                timeDisplaySettings: _timeDisplaySettings,
                localSchemaFact: _buildLocalSchemaFactItem(
                  context,
                  AppLocalizations.of(context),
                ),
                onOpenPartitionHealthDialog: () =>
                    _openPartitionHealthDialog(context),
              ),
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
          child: TopicDetailProgressTile(
              stream: streamController,
              onStart: startStreaming,
            ),
        );

        if (!compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  closeButton,
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(child: _buildTopicTitleRow(context)),
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
                  const SizedBox(width: 16),
                  Flexible(child: progressTile),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: TopicDetailTags(
                profile: widget.profile,
                topic: _currentTopic,
                topicController: topicController,
                factsController: factsController,
                schemaController: schemaController,
                timeDisplaySettings: _timeDisplaySettings,
                localSchemaFact: _buildLocalSchemaFactItem(
                  context,
                  AppLocalizations.of(context),
                ),
                onOpenPartitionHealthDialog: () =>
                    _openPartitionHealthDialog(context),
              ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                closeButton,
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(child: _buildTopicTitleRow(context)),
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
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: TopicDetailTags(
                profile: widget.profile,
                topic: _currentTopic,
                topicController: topicController,
                factsController: factsController,
                schemaController: schemaController,
                timeDisplaySettings: _timeDisplaySettings,
                localSchemaFact: _buildLocalSchemaFactItem(
                  context,
                  AppLocalizations.of(context),
                ),
                onOpenPartitionHealthDialog: () =>
                    _openPartitionHealthDialog(context),
              ),
            ),
            const SizedBox(height: 8),
            progressTile,
          ],
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
