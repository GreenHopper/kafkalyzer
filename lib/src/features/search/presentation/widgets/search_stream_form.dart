import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/topic_selection_dialog.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/search_stream_configuration.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/cluster_dropdown.dart';

class SearchStreamForm extends StatefulWidget {
  final Function(List<SearchTarget>) onAddStreams;

  const SearchStreamForm({super.key, required this.onAddStreams});

  @override
  State<SearchStreamForm> createState() => _SearchStreamFormState();
}

class _SearchStreamFormState extends State<SearchStreamForm> {
  ClusterProfile? _selectedCluster;
  List<TopicMetadata> _selectedTopics = [];

  final TextEditingController _filterController = TextEditingController();
  final TextEditingController _filterFieldController =
      TextEditingController(); // ADDED
  FilterType _filterType = FilterType.contains;
  SearchScope _searchScope = SearchScope.both;
  bool _fastTraceEnabled = false;
  final TextEditingController _partitionController = TextEditingController();

  MultiSearchStartStrategy _startStrategy = MultiSearchStartStrategy.earliest;
  final TextEditingController _offsetController = TextEditingController();
  final TextEditingController _timestampController = TextEditingController();

  MultiSearchEndStrategy _endStrategy = MultiSearchEndStrategy.latest;
  final TextEditingController _endOffsetController = TextEditingController();
  final TextEditingController _endTimestampController = TextEditingController();

  bool _limitResults = true;
  final TextEditingController _maxResultsController = TextEditingController(
    text: "200",
  );

  @override
  void dispose() {
    _filterController.dispose();
    _filterFieldController.dispose();
    _offsetController.dispose();
    _timestampController.dispose();
    _partitionController.dispose();
    _endOffsetController.dispose();
    _endTimestampController.dispose();
    _maxResultsController.dispose();
    super.dispose();
  }

  int? _convertToTimestamp(String text) {
    if (text.isEmpty) return null;
    final date = DateFormatUtils.parseDateTime(context, text);
    if (date != null) return date.millisecondsSinceEpoch;
    return int.tryParse(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final clusterController = getIt<ClusterListController>();
    final topicController = getIt<TopicController>();

    return AnimatedBuilder(
      animation: Listenable.merge([clusterController, topicController]),
      builder: (context, child) {
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              l10n.newSearchStream,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerLowest,
            collapsedBackgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHigh,
            childrenPadding: const EdgeInsets.all(16),
            children: [
              _buildClusterSelection(l10n, topicController),
              if (_selectedCluster != null) ...[
                const SizedBox(height: 12),
                _buildTopicSelectionField(l10n, topicController),
                if (_selectedTopics.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildSelectedTopicsChips(),
                ],
              ],
              const SizedBox(height: 12),
              _buildFilterFields(l10n),
              const SizedBox(height: 12),
              _buildStreamConfiguration(),
              const SizedBox(height: 16),
              _buildStartSearchButton(l10n),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClusterSelection(
    AppLocalizations l10n,
    TopicController topicController,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClusterDropdown(
            value: _selectedCluster,
            labelText: l10n.cluster,
            onChanged: (val) {
              setState(() {
                _selectedCluster = val;
                _selectedTopics = [];
              });
              if (val != null && topicController.getTopics(val) == null) {
                topicController.fetchTopics(val);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.reloadTopics,
            onPressed:
                (_selectedCluster == null ||
                    topicController.isLoading(_selectedCluster!))
                ? null
                : () {
                    setState(() => _selectedTopics = []);
                    topicController.fetchTopics(_selectedCluster!, force: true);
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildTopicSelectionField(
    AppLocalizations l10n,
    TopicController topicController,
  ) {
    return TextFormField(
      readOnly: true,
      enabled: !topicController.isLoading(_selectedCluster!),
      controller: TextEditingController(
        text: (topicController.isLoading(_selectedCluster!))
            ? l10n.loadingTopics
            : "Select Topics (${_selectedTopics.length} selected)",
      ),
      decoration: InputDecoration(
        labelText: l10n.topics,
        hintText: l10n.selectTopic,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: (topicController.isLoading(_selectedCluster!))
            ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.arrow_drop_down),
      ),
      onTap: () async => await _handleTopicSelectionTap(topicController),
    );
  }

  Future<void> _handleTopicSelectionTap(TopicController topicController) async {
    if (topicController.isLoading(_selectedCluster!)) return;
    final topics = topicController.getTopics(_selectedCluster!) ?? [];
    final selected = await showDialog<List<TopicMetadata>>(
      context: context,
      builder: (c) => TopicSelectionDialog(
        topics: topics,
        clusterProfile: _selectedCluster,
        multiSelect: true,
        initialSelection: _selectedTopics.map((t) => t.name).toList(),
      ),
    );
    if (selected != null) {
      setState(() => _selectedTopics = selected);
    }
  }

  Widget _buildSelectedTopicsChips() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: _selectedTopics.map((topic) {
        return Chip(
          label: Text(topic.name),
          onDeleted: () => setState(() => _selectedTopics.remove(topic)),
        );
      }).toList(),
    );
  }

  Widget _buildFilterFields(AppLocalizations l10n) {
    return Column(
      children: [
        Autocomplete<String>(
          optionsBuilder: (textEditingValue) async {
            if (_selectedCluster == null || _selectedTopics.isEmpty) return [];
            final fields = await getIt<SchemaController>().fetchSchemaFields(
              _selectedCluster!,
              _selectedTopics.first.name,
            );
            if (textEditingValue.text.isEmpty) return fields;
            return fields.where(
              (f) =>
                  f.toLowerCase().contains(textEditingValue.text.toLowerCase()),
            );
          },
          onSelected: (selection) => _filterFieldController.text = selection,
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
                if (textController.text != _filterFieldController.text) {
                  textController.text = _filterFieldController.text;
                }
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  onChanged: (val) => _filterFieldController.text = val,
                  decoration: InputDecoration(
                    labelText: l10n.fieldOptional,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.data_object, size: 18),
                  ),
                );
              },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _filterController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.valuesCommaSeparated,
            border: const OutlineInputBorder(),
            isDense: true,
            prefixIcon: const Icon(Icons.filter_alt, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildStreamConfiguration() {
    return SearchStreamConfiguration(
      filterType: _filterType,
      onFilterTypeChanged: (v) => setState(() {
        _filterType = v;
        if (_fastTraceEnabled && _filterType != FilterType.exact) {
          _fastTraceEnabled = false;
        }
      }),
      searchScope: _searchScope,
      onSearchScopeChanged: (v) => setState(() {
        _searchScope = v;
        if (_fastTraceEnabled && _searchScope != SearchScope.key) {
          _fastTraceEnabled = false;
        }
      }),
      fastTraceEnabled: _fastTraceEnabled,
      onFastTraceChanged: (v) => setState(() {
        _fastTraceEnabled = v;
        if (_fastTraceEnabled) {
          _filterType = FilterType.exact;
          _searchScope = SearchScope.key;
        }
      }),
      limitResults: _limitResults,
      onLimitResultsChanged: (v) => setState(() => _limitResults = v),
      maxResultsController: _maxResultsController,
      partitionController: _partitionController,
      startStrategy: _startStrategy,
      onStartStrategyChanged: (v) => setState(() => _startStrategy = v),
      startOffsetController: _offsetController,
      startTimestampController: _timestampController,
      endStrategy: _endStrategy,
      onEndStrategyChanged: (v) => setState(() => _endStrategy = v),
      endOffsetController: _endOffsetController,
      endTimestampController: _endTimestampController,
    );
  }

  Widget _buildStartSearchButton(AppLocalizations l10n) {
    return FilledButton.icon(
      onPressed: (_selectedCluster != null && _selectedTopics.isNotEmpty)
          ? _handleSearch
          : null,
      icon: const Icon(Icons.play_arrow),
      label: Text(l10n.startSearch),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  void _handleSearch() {
    int? startOffset;
    int? startTimestamp;
    if (_startStrategy == MultiSearchStartStrategy.earliest) startOffset = 0;
    if (_startStrategy == MultiSearchStartStrategy.customOffset) {
      startOffset = int.tryParse(_offsetController.text);
    }
    if (_startStrategy == MultiSearchStartStrategy.customTimestamp) {
      startTimestamp = _convertToTimestamp(_timestampController.text);
    }

    final terms = _filterController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final targets = <SearchTarget>[];
    final searchJobId = DateTime.now().millisecondsSinceEpoch.toString();
    for (final topic in _selectedTopics) {
      targets.add(
        SearchTarget(
          profile: _selectedCluster!,
          topic: topic,
          filterTerms: terms.isNotEmpty ? terms : null,
          filterField: _filterFieldController.text.isNotEmpty
              ? _filterFieldController.text
              : null,
          filterType: _filterType,
          filterTerm: terms.isNotEmpty ? terms.first : null, // Legacy support
          scope: _searchScope,
          startOffset: startOffset,
          startTimestamp: startTimestamp,
          startPartition: _fastTraceEnabled
              ? null
              : int.tryParse(_partitionController.text),
          fastTraceEnabled: _fastTraceEnabled,
          endStrategy: _endStrategy,
          endOffset: int.tryParse(_endOffsetController.text),
          endTimestamp: _convertToTimestamp(_endTimestampController.text),
          maxResults: _limitResults
              ? int.tryParse(_maxResultsController.text)
              : null,
          searchJobId: searchJobId,
        ),
      );
    }
    widget.onAddStreams(targets);
  }
}
