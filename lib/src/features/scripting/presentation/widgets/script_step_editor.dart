import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/topic_selection_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/search_stream_configuration.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/cluster_dropdown.dart';

class ScriptStepEditor extends StatefulWidget {
  final ScriptStep step;
  final List<ScriptVariable> variables;
  final Function(ScriptStep) onSave;

  const ScriptStepEditor({
    super.key,
    required this.step,
    required this.variables,
    required this.onSave,
  });

  @override
  State<ScriptStepEditor> createState() => _ScriptStepEditorState();
}

class _ScriptStepEditorState extends State<ScriptStepEditor> {
  late TextEditingController _nameController;
  late TextEditingController
  _filterTemplateController; // Renamed from _filterController

  ClusterProfile? _selectedCluster;
  List<String> _selectedTopics =
      []; // Changed from _selectedTopicName to _selectedTopics

  // Filter
  FilterType _selectedFilterType =
      FilterType.contains; // Renamed from _filterType
  SearchScope _selectedSearchScope =
      SearchScope.both; // Renamed from _searchScope

  late TextEditingController _startOffsetController;
  late TextEditingController _startTimestampController;
  late TextEditingController _startPartitionController;
  late TextEditingController _endOffsetController;
  late TextEditingController _endTimestampController;
  late TextEditingController _maxResultsController;

  late TopicScanMode _scanMode;
  MultiSearchStartStrategy _startStrategy = MultiSearchStartStrategy.latest;
  MultiSearchEndStrategy _endStrategy = MultiSearchEndStrategy.latest;
  bool _limitResults = true;
  bool _fastTraceEnabled = false;

  late List<ScriptExtraction> _extractions;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.step.name);
    _selectedTopics = List.from(
      widget.step.topicNames,
    ); // Initialize with topicNames
    _filterTemplateController = TextEditingController(
      text: widget.step.filterTemplate,
    ); // Initialize renamed controller
    _selectedFilterType = widget.step.filterType; // Initialize renamed variable
    _selectedSearchScope = widget.step.scope; // Initialize renamed variable

    // Strategies
    _startStrategy = widget.step.startStrategy;
    _endStrategy = widget.step.endStrategy;
    _fastTraceEnabled = widget.step.fastTraceEnabled;
    _scanMode = TopicScanMode.fromStrategies(
      startStrategy: _startStrategy,
      endStrategy: _endStrategy,
    );

    // Controllers
    _startOffsetController = TextEditingController(
      text: widget.step.startOffset,
    );
    _startTimestampController = TextEditingController(
      text: widget.step.startTimestamp,
    );
    _startPartitionController = TextEditingController(
      text: widget.step.startPartition,
    );
    _endOffsetController = TextEditingController(text: widget.step.endOffset);
    _endTimestampController = TextEditingController(
      text: widget.step.endTimestamp,
    );

    _limitResults = widget.step.maxResults != null;
    _maxResultsController = TextEditingController(
      text: widget.step.maxResults ?? "200",
    );

    // Resolve cluster object if possible
    final clusters = getIt<ClusterListController>().clusters;
    try {
      _selectedCluster = clusters.firstWhere(
        (c) => c.name == widget.step.clusterName,
      );
    } catch (_) {}

    // _selectedTopicName = widget.step.topicName.isNotEmpty ? widget.step.topicName : null; // Removed

    // If cluster resolved, fetch topics?
    if (_selectedCluster != null) {
      getIt<TopicController>().fetchTopics(_selectedCluster!);
    }

    _extractions = List.from(widget.step.extractions);
  }

  void _insertVariable(TextEditingController controller, String variable) {
    final text = controller.text;
    final selection = controller.selection;

    // If no selection or invalid, append to end
    int start = selection.isValid ? selection.start : text.length;
    int end = selection.isValid ? selection.end : text.length;

    final newText = text.replaceRange(start, end, '{{$variable}}');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + variable.length + 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Edit Step", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _buildStepNameField(),
          const SizedBox(height: 12),
          _buildClusterSelection(),
          const SizedBox(height: 12),
          _buildTopicSelection(),
          const SizedBox(height: 12),
          _buildSearchConfiguration(),
          const SizedBox(height: 24),
          _buildExtractionsList(),
          const SizedBox(height: 8),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStepNameField() {
    return TextField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: "Step Name",
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildClusterSelection() {
    final topicController = getIt<TopicController>();

    return ClusterDropdown(
      value: _selectedCluster,
      labelText: "Cluster",
      isExpanded: true,
      onChanged: (val) {
        setState(() {
          _selectedCluster = val;
          _selectedTopics = []; // Reset topics when cluster changes
        });
        if (val != null) {
          topicController.fetchTopics(val);
        }
      },
    );
  }

  Widget _buildTopicSelection() {
    final topicController = getIt<TopicController>();

    if (_selectedCluster == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: topicController,
      builder: (context, _) {
        return _buildTopicField(topicController);
      },
    );
  }

  Widget _buildTopicField(TopicController topicController) {
    final l10n = AppLocalizations.of(context);
    final isLoading = topicController.isLoading(_selectedCluster!);
    final loadingHint = l10n?.topicLoadingHint ?? "Loading topics...";
    final selectHint =
        l10n?.selectTopicsCount(_selectedTopics.length) ??
        "Select Topics (${_selectedTopics.length} selected)";
    final emptyHint = l10n?.selectTopicsCount(0) ?? "Select Topics";
    final topicsLabel = l10n?.topics ?? "Topics";
    final addTopicTooltip = l10n?.addTopicManually ?? "Add Topic Manually";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                readOnly: true,
                enabled: !isLoading,
                controller: TextEditingController(
                  text: isLoading ? loadingHint : selectHint,
                ),
                decoration: InputDecoration(
                  labelText: topicsLabel,
                  hintText: emptyHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: isLoading
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
                onTap: () async {
                  if (isLoading) return;
                  final topics =
                      topicController.getTopics(_selectedCluster!) ?? [];
                  final selected = await showDialog<List<TopicMetadata>>(
                    context: context,
                    builder: (c) => TopicSelectionDialog(
                      topics: topics,
                      multiSelect: true,
                      initialSelection: _selectedTopics,
                      clusterProfile: _selectedCluster,
                    ),
                  );
                  if (selected != null) {
                    setState(() {
                      _selectedTopics = selected.map((t) => t.name).toList();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: addTopicTooltip,
              onPressed: _promptAddManualTopic,
            ),
          ],
        ),
        if (_selectedTopics.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _selectedTopics.map((topic) {
              return Chip(
                label: Text(topic),
                onDeleted: () {
                  setState(() {
                    _selectedTopics.remove(topic);
                  });
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _promptAddManualTopic() async {
    final l10n = AppLocalizations.of(context);
    final title = l10n?.addTopicManually ?? "Add Topic Manually";
    final prompt = l10n?.manualTopicNamePrompt ?? "Enter topic name";
    final cancel = l10n?.cancel ?? "Cancel";
    final addAction = l10n?.addTopicAction ?? "Add Topic";

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: prompt,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(addAction),
          ),
        ],
      ),
    );

    if (result != null &&
        result.isNotEmpty &&
        !_selectedTopics.contains(result)) {
      setState(() {
        _selectedTopics.add(result);
      });
    }
  }

  Widget _buildSearchConfiguration() {
    return SearchStreamConfiguration(
      scanMode: _scanMode,
      onScanModeChanged: (newMode) => setState(() {
        _scanMode = newMode;
        _startStrategy = newMode.defaultStartStrategy;
        _endStrategy = newMode.defaultEndStrategy;
        if (newMode == TopicScanMode.latestN) {
          _limitResults = true;
          if (_maxResultsController.text.isEmpty) {
            _maxResultsController.text = "200";
          }
        } else if (newMode == TopicScanMode.liveTail) {
          _limitResults = false;
        }
      }),
      filterInput: _buildTextFieldWithVar(
        "Filter Template",
        _filterTemplateController,
        icon: Icons.filter_alt,
      ),
      filterType: _selectedFilterType,
      onFilterTypeChanged: (v) => setState(() {
        _selectedFilterType = v;
        if (_fastTraceEnabled && _selectedFilterType != FilterType.exact) {
          _fastTraceEnabled = false;
        }
      }),
      searchScope: _selectedSearchScope,
      onSearchScopeChanged: (v) => setState(() {
        _selectedSearchScope = v;
        if (_fastTraceEnabled && _selectedSearchScope != SearchScope.key) {
          _fastTraceEnabled = false;
        }
      }),
      fastTraceEnabled: _fastTraceEnabled,
      onFastTraceChanged: (v) => setState(() {
        _fastTraceEnabled = v;
        if (_fastTraceEnabled) {
          _selectedFilterType = FilterType.exact;
          _selectedSearchScope = SearchScope.key;
        }
      }),
      limitResults: _limitResults,
      onLimitResultsChanged: (v) => setState(() => _limitResults = v),
      maxResultsController: _maxResultsController,
      partitionController: _startPartitionController,
      startStrategy: _startStrategy,
      onStartStrategyChanged: (v) => setState(() => _startStrategy = v),
      startOffsetController: _startOffsetController,
      startTimestampController: _startTimestampController,
      endStrategy: _endStrategy,
      onEndStrategyChanged: (v) => setState(() => _endStrategy = v),
      endOffsetController: _endOffsetController,
      endTimestampController: _endTimestampController,
      variableSuffixBuilder: _buildVariableSuffix,
    );
  }

  Widget _buildExtractionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Value Extractions",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_extractions.isEmpty)
          const Text(
            "No extractions defined",
            style: TextStyle(color: Colors.grey),
          ),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _extractions.length,
          separatorBuilder: (c, i) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _buildExtractionItem(index),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text("Add Extraction"),
          onPressed: () => setState(
            () => _extractions.add(
              const ScriptExtraction(jsonPath: "", variableName: ""),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExtractionItem(int index) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildExtractionHeader(index),
          const SizedBox(height: 8),
          _buildExtractionJsonPath(index),
        ],
      ),
    );
  }

  Widget _buildExtractionHeader(int index) {
    final extraction = _extractions[index];
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        if (_selectedTopics.length > 1) ...[
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue:
                  extraction.topic != null &&
                      _selectedTopics.contains(extraction.topic)
                  ? extraction.topic
                  : null,
              decoration: InputDecoration(
                labelText: l10n?.extractionTopic ?? "Topic",
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
              items: _selectedTopics
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Tooltip(
                        message: t,
                        child: Text(
                          t,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(
                () => _extractions[index] = extraction.copyWith(topic: val),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: 120,
          child: DropdownButtonFormField<ScriptExtractionSource>(
            isExpanded: true,
            initialValue: extraction.source,
            decoration: InputDecoration(
              labelText: l10n?.extractionSource ?? "Source",
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
            ),
            items: ScriptExtractionSource.values
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s.name.toUpperCase(),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(
                  () => _extractions[index] = extraction.copyWith(source: val),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            decoration: InputDecoration(
              labelText: l10n?.extractionVariableName ?? "Variable Name",
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
            ),
            controller: TextEditingController(text: extraction.variableName)
              ..selection = TextSelection.collapsed(
                offset: extraction.variableName.length,
              ),
            onChanged: (val) =>
                _extractions[index] = extraction.copyWith(variableName: val),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => setState(() => _extractions.removeAt(index)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildExtractionJsonPath(int index) {
    final extraction = _extractions[index];
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<String>(
          initialValue: TextEditingValue(text: extraction.jsonPath),
          optionsBuilder: (textEditingValue) async {
            if (_selectedCluster == null || _selectedTopics.isEmpty) {
              return [];
            }
            final topic = extraction.topic ?? _selectedTopics.first;
            final fields = await getIt<SchemaController>().fetchSchemaFields(
              _selectedCluster!,
              topic,
            );
            if (textEditingValue.text.isEmpty) {
              return fields;
            }
            return fields.where((option) {
              return option.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              );
            });
          },
          onSelected: (selection) => setState(
            () =>
                _extractions[index] = extraction.copyWith(jsonPath: selection),
          ),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: l10n?.extractionJsonPath ?? "JSON Path",
                hintText: "e.g. data.id",
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: (val) => setState(
                () => _extractions[index] = extraction.copyWith(jsonPath: val),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: 200,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        title: Text(option),
                        onTap: () {
                          onSelected(option);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            if (_selectedCluster == null || _selectedTopics.isEmpty) {
              return;
            }

            final newStep = widget.step.copyWith(
              name: _nameController.text,
              clusterName: _selectedCluster!.name,
              topicNames: _selectedTopics,
              filterTemplate: _filterTemplateController.text,
              filterType: _selectedFilterType,
              scope: _selectedSearchScope,
              startStrategy: _startStrategy,
              endStrategy: _endStrategy,
              startOffset:
                  _startStrategy == MultiSearchStartStrategy.customOffset
                  ? _startOffsetController.text
                  : null,
              startTimestamp:
                  _startStrategy == MultiSearchStartStrategy.customTimestamp
                  ? _startTimestampController.text
                  : null,
              startPartition:
                  (!_fastTraceEnabled &&
                      _startPartitionController.text.isNotEmpty)
                  ? _startPartitionController.text
                  : null,
              fastTraceEnabled: _fastTraceEnabled,
              endOffset: _endStrategy == MultiSearchEndStrategy.customOffset
                  ? _endOffsetController.text
                  : null,
              endTimestamp:
                  _endStrategy == MultiSearchEndStrategy.customTimestamp
                  ? _endTimestampController.text
                  : null,
              maxResults: _limitResults ? _maxResultsController.text : null,
              extractions: _extractions,
            );
            widget.onSave(newStep);
          },
          child: const Text("Save"),
        ),
      ],
    );
  }

  Widget _buildTextFieldWithVar(
    String label,
    TextEditingController controller, {
    IconData? icon,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        border: const OutlineInputBorder(),
        suffixIcon: _buildVariableSuffix(controller),
      ),
    );
  }

  Widget? _buildVariableSuffix(TextEditingController controller) {
    return widget.variables.isNotEmpty
        ? PopupMenuButton<String>(
            icon: const Icon(Icons.data_object, size: 18),
            tooltip: "Insert Variable",
            onSelected: (v) => _insertVariable(controller, v),
            itemBuilder: (context) => widget.variables
                .map((v) => PopupMenuItem(value: v.name, child: Text(v.name)))
                .toList(),
          )
        : null;
  }
}
