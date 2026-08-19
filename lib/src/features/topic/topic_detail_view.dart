import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:group_button/group_button.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/messages/messages_view.dart';
import 'package:kafkalyzer/src/ui/message_details_dialog.dart';

import 'package:kafkalyzer/src/ui/date_format_utils.dart';

import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_tag.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_analysis_view.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/schema_viewer_dialog.dart';
import 'package:kafkalyzer/src/ui/topic_progress_tile.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/end_condition_configuration.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/start_condition_configuration.dart';
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

  MultiSearchStartStrategy _startStrategy = MultiSearchStartStrategy.earliest;

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

  // ADDED State
  FilterType _filterType = FilterType.contains;
  SearchScope _searchScope = SearchScope.both;
  bool _fastTraceEnabled = false;
  final TextEditingController _partitionController =
      TextEditingController(); // ADDED

  MultiSearchEndStrategy _endStrategy = MultiSearchEndStrategy.latest;
  final TextEditingController _endOffsetController = TextEditingController();
  final TextEditingController _endTimestampController = TextEditingController();

  bool _limitResults = true; // ADDED
  final TextEditingController _maxResultsController = TextEditingController(
    text: "200",
  ); // ADDED

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
              _buildSettings(context, colorScheme, startStreaming),
              const Divider(height: 1),
              Expanded(
                child: MessagesView(
                  preferencesKey: "topic_detail_view_mode",
                  messages: messages,
                  onMessageTap: (msg) {
                    showDialog(
                      context: context,
                      builder: (context) => MessageDetailsDialog(message: msg),
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

    return Row(
      children: [
        IconButton(
          onPressed: () {
            if (widget.tabId != null) {
              activeController.closeTopicTab(widget.tabId!);
            } else {
              activeController.closeTopic(widget.topic, widget.profile.name);
            }
          },
          icon: const Icon(Icons.close),
          tooltip: l10n?.closeTab ?? "Close Tab",
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHigh,
          ),
        ),
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
        _buildTopicModeSwitcher(context, colorScheme, l10n),
        const SizedBox(width: 16),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _viewMode == TopicViewMode.messages
                ? _buildProgressTile(context, colorScheme)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicModeSwitcher(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
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
            onTap: () => setState(() => _viewMode = TopicViewMode.messages),
          ),
          const SizedBox(width: 2),
          _TopicModeButton(
            icon: Icons.analytics_outlined,
            label: l10n?.topicAnalysis ?? 'Analysis',
            isSelected: _viewMode == TopicViewMode.analysis,
            onTap: () => setState(() => _viewMode = TopicViewMode.analysis),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicTitleRow(BuildContext context) {
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
          tooltip: "Copy Topic Name",
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.topic.name));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Topic name copied"),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopicTags(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        TopicTag("${widget.topic.partitionCount} Partitions"),
        TopicTag("RF: ${widget.topic.replicationFactor}"),
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
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => SchemaViewerDialog(
              profile: widget.profile,
              topicName: widget.topic.name,
              controller: schemaController,
            ),
          );
        },
        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
        icon: const Icon(Icons.visibility, size: 16),
        label: const Text("Schema"),
      ),
    );
  }

  Widget _buildProgressTile(BuildContext context, ColorScheme colorScheme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: TopicProgressTile(
        topic: "Scan Progress",
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (streamController.isStreaming)
          FilledButton.icon(
            onPressed: () => streamController.stopStreaming(),
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('Stop'),
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
            label: const Text('Stream'),
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
          tooltip: "Clear Messages",
          style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }

  Widget _buildSettings(
    BuildContext context,
    ColorScheme colorScheme,
    VoidCallback onStart,
  ) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: const Text(
        "Search Configuration",
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.tune, size: 20),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      backgroundColor: colorScheme.surfaceContainerLowest,
      collapsedBackgroundColor: colorScheme.surface,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 850;
            final filterSection = _buildFilterSection(
              context,
              colorScheme,
              onStart,
            );
            final strategySection = _buildStrategySection(context);

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: filterSection),
                  const SizedBox(width: 24),
                  Container(
                    width: 1,
                    height: 100, // Approximate height
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: strategySection),
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  filterSection,
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  strategySection,
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildFilterSection(
    BuildContext context,
    ColorScheme colorScheme,
    VoidCallback onStart,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 1, child: _buildFieldAutocomplete(context)),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _filterController,
                decoration: InputDecoration(
                  labelText: 'Values (comma sep.)',
                  hintText: "Enter keywords...",
                  isDense: true,
                  prefixIcon: const Icon(Icons.filter_alt),
                  suffixIcon: _filterController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _filterController.clear()),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => onStart(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildFilterTypeSelector(context, colorScheme),
            _buildSearchScopeSelector(context, colorScheme),
          ],
        ),
        const SizedBox(height: 12),
        _buildLimitAndPartitionRow(),
        const SizedBox(height: 12),
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              "Fast Trace (Hash Key)",
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            value: _fastTraceEnabled,
            onChanged: (val) => setState(() {
              _fastTraceEnabled = val;
              if (_fastTraceEnabled) {
                _filterType = FilterType.exact;
                _searchScope = SearchScope.key;
              }
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldAutocomplete(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) async {
        final fields = await schemaController.fetchSchemaFields(
          widget.profile,
          widget.topic.name,
        );
        if (textEditingValue.text.isEmpty) {
          return fields;
        }
        return fields.where(
          (f) => f.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      onSelected: (selection) => _filterFieldController.text = selection,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        if (textController.text != _filterFieldController.text) {
          textController.text = _filterFieldController.text;
        }
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Field (Opt.)',
            isDense: true,
            prefixIcon: Icon(Icons.data_object, size: 18),
          ),
          onChanged: (val) => _filterFieldController.text = val,
        );
      },
    );
  }

  Widget _buildFilterTypeSelector(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Type:",
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        GroupButton(
          isRadio: true,
          onSelected: (val, i, selected) => setState(() {
            _filterType = FilterType.values[i];
            if (_fastTraceEnabled && _filterType != FilterType.exact) {
              _fastTraceEnabled = false;
            }
          }),
          buttons: const ["Contains", "Regex", "Exact"],
          controller: GroupButtonController(selectedIndex: _filterType.index),
          options: GroupButtonOptions(
            borderRadius: BorderRadius.circular(8),
            buttonHeight: 32,
            textPadding: const EdgeInsets.symmetric(horizontal: 12),
            selectedColor: colorScheme.primaryContainer,
            selectedTextStyle: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 13,
            ),
            unselectedColor: colorScheme.surfaceContainerHigh,
            unselectedTextStyle: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
            mainGroupAlignment: MainGroupAlignment.start,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchScopeSelector(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Scope:",
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        GroupButton(
          isRadio: true,
          onSelected: (val, i, selected) => setState(() {
            _searchScope = SearchScope.values[i];
            if (_fastTraceEnabled && _searchScope != SearchScope.key) {
              _fastTraceEnabled = false;
            }
          }),
          buttons: const ["Key", "Value", "Both"],
          controller: GroupButtonController(selectedIndex: _searchScope.index),
          options: GroupButtonOptions(
            borderRadius: BorderRadius.circular(8),
            buttonHeight: 32,
            textPadding: const EdgeInsets.symmetric(horizontal: 12),
            selectedColor: colorScheme.primaryContainer,
            selectedTextStyle: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 13,
            ),
            unselectedColor: colorScheme.surfaceContainerHigh,
            unselectedTextStyle: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
            mainGroupAlignment: MainGroupAlignment.start,
          ),
        ),
      ],
    );
  }

  Widget _buildLimitAndPartitionRow() {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: TextField(
            controller: _maxResultsController,
            enabled: _limitResults,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Limit',
              isDense: true,
              prefix: Checkbox(
                value: _limitResults,
                onChanged: (v) => setState(() => _limitResults = v!),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: _partitionController,
            enabled: !_fastTraceEnabled,
            decoration: const InputDecoration(
              labelText: "Partition (Opt.)",
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStrategySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: StartConditionConfiguration(
                startStrategy: _startStrategy,
                onStartStrategyChanged: (val) =>
                    setState(() => _startStrategy = val),
                startOffsetController: _offsetController,
                startTimestampController: _timestampController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: EndConditionConfiguration(
                endStrategy: _endStrategy,
                onEndStrategyChanged: (val) =>
                    setState(() => _endStrategy = val),
                endOffsetController: _endOffsetController,
                endTimestampController: _endTimestampController,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void startStreaming() {
    {
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
      );
    }
  }
}

class _TopicModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TopicModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
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
        ),
      ),
    );
  }
}
