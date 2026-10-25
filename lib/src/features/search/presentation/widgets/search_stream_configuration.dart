import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:group_button/group_button.dart';
import 'package:uuid/uuid.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/search/models/topic_search_preset.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/saved_searches_service.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/start_condition_configuration.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/end_condition_configuration.dart';

class SearchStreamConfiguration extends StatefulWidget {
  final TopicScanMode scanMode;
  final ValueChanged<TopicScanMode> onScanModeChanged;
  final bool initiallyExpanded;

  // Filter Options
  final FilterType filterType;
  final ValueChanged<FilterType> onFilterTypeChanged;
  final SearchScope searchScope;
  final ValueChanged<SearchScope> onSearchScopeChanged;
  final Widget? filterInput;

  // Fast Trace & Limit
  final bool fastTraceEnabled;
  final ValueChanged<bool> onFastTraceChanged;
  final bool limitResults;
  final ValueChanged<bool> onLimitResultsChanged;
  final TextEditingController maxResultsController;
  final TextEditingController partitionController;

  // Start Strategy
  final MultiSearchStartStrategy startStrategy;
  final ValueChanged<MultiSearchStartStrategy> onStartStrategyChanged;
  final TextEditingController startOffsetController;
  final TextEditingController startTimestampController;

  // Stop Strategy
  final MultiSearchEndStrategy endStrategy;
  final ValueChanged<MultiSearchEndStrategy> onEndStrategyChanged;
  final TextEditingController endOffsetController;
  final TextEditingController endTimestampController;

  final Widget? Function(TextEditingController)? variableSuffixBuilder;
  final String? clusterName;
  final String? topicName;
  final TextEditingController? filterTermController;
  final ValueChanged<TopicSearchPreset>? onPresetApplied;

  const SearchStreamConfiguration({
    super.key,
    required this.scanMode,
    required this.onScanModeChanged,
    this.initiallyExpanded = false,
    required this.filterType,
    required this.onFilterTypeChanged,
    required this.searchScope,
    required this.onSearchScopeChanged,
    this.filterInput,
    required this.fastTraceEnabled,
    required this.onFastTraceChanged,
    required this.limitResults,
    required this.onLimitResultsChanged,
    required this.maxResultsController,
    required this.partitionController,
    required this.startStrategy,
    required this.onStartStrategyChanged,
    required this.startOffsetController,
    required this.startTimestampController,
    required this.endStrategy,
    required this.onEndStrategyChanged,
    required this.endOffsetController,
    required this.endTimestampController,
    this.variableSuffixBuilder,
    this.clusterName,
    this.topicName,
    this.filterTermController,
    this.onPresetApplied,
  });

  @override
  State<SearchStreamConfiguration> createState() =>
      _SearchStreamConfigurationState();
}

class _SearchStreamConfigurationState extends State<SearchStreamConfiguration> {
  late bool _isAdvancedExpanded;
  List<TopicSearchPreset> _presets = [];
  TopicSearchPreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _isAdvancedExpanded =
        widget.initiallyExpanded ||
        widget.filterType != FilterType.contains ||
        widget.searchScope != SearchScope.both ||
        widget.fastTraceEnabled;
    _loadPresets();
  }

  @override
  void didUpdateWidget(covariant SearchStreamConfiguration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clusterName != oldWidget.clusterName ||
        widget.topicName != oldWidget.topicName) {
      _loadPresets();
    }
  }

  Future<void> _loadPresets() async {
    if (widget.clusterName == null || widget.topicName == null) return;
    try {
      final presets = await getIt<SavedSearchesService>().getPresets(
        clusterName: widget.clusterName!,
        topicName: widget.topicName!,
      );
      if (mounted) {
        setState(() {
          _presets = presets;
        });
      }
    } catch (_) {}
  }

  void _applyPreset(TopicSearchPreset preset) {
    setState(() => _selectedPreset = preset);
    widget.onScanModeChanged(preset.scanMode);
    widget.onFilterTypeChanged(preset.filterType);
    widget.onSearchScopeChanged(preset.searchScope);
    if (widget.filterTermController != null) {
      widget.filterTermController!.text = preset.filterTerm;
    }
    widget.onFastTraceChanged(preset.fastTraceEnabled);
    widget.onLimitResultsChanged(preset.limitResults);
    widget.maxResultsController.text = preset.maxResults;
    widget.partitionController.text = preset.partition;
    widget.onStartStrategyChanged(preset.startStrategy);
    widget.startOffsetController.text = preset.startOffset;
    widget.startTimestampController.text = preset.startTimestamp;
    widget.onEndStrategyChanged(preset.endStrategy);
    widget.endOffsetController.text = preset.endOffset;
    widget.endTimestampController.text = preset.endTimestamp;
    widget.onPresetApplied?.call(preset);
  }

  Future<void> _showSavePresetDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(
      text: _selectedPreset?.name ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.savePresetDialogTitle ?? 'Save Search Preset'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n?.presetNameLabel ?? 'Preset Name',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );

    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      final name = nameController.text.trim();
      final preset = TopicSearchPreset(
        id: _selectedPreset?.name == name
            ? _selectedPreset!.id
            : const Uuid().v4(),
        name: name,
        clusterName: widget.clusterName ?? '',
        topicName: widget.topicName ?? '',
        scanMode: widget.scanMode,
        filterType: widget.filterType,
        searchScope: widget.searchScope,
        filterTerm: widget.filterTermController?.text ?? '',
        fastTraceEnabled: widget.fastTraceEnabled,
        limitResults: widget.limitResults,
        maxResults: widget.maxResultsController.text,
        partition: widget.partitionController.text,
        startStrategy: widget.startStrategy,
        startOffset: widget.startOffsetController.text,
        startTimestamp: widget.startTimestampController.text,
        endStrategy: widget.endStrategy,
        endOffset: widget.endOffsetController.text,
        endTimestamp: widget.endTimestampController.text,
        createdAt: DateTime.now(),
      );

      await getIt<SavedSearchesService>().savePreset(preset);
      await _loadPresets();
      setState(() => _selectedPreset = preset);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.presetSaved ?? 'Preset saved')),
        );
      }
    }
  }

  Future<void> _deletePreset(TopicSearchPreset preset) async {
    final l10n = AppLocalizations.of(context);
    await getIt<SavedSearchesService>().deletePreset(
      clusterName: preset.clusterName,
      topicName: preset.topicName,
      presetId: preset.id,
    );
    await _loadPresets();
    if (_selectedPreset?.id == preset.id) {
      setState(() => _selectedPreset = null);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.presetDeleted ?? 'Preset deleted')),
      );
    }
  }

  Widget _buildPresetBar(BuildContext context, AppLocalizations? l10n) {
    if (widget.clusterName == null || widget.topicName == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.bookmarks_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n?.searchPresets ?? 'Presets:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String?>(
                value: _selectedPreset?.id,
                isExpanded: true,
                underline: const SizedBox(),
                hint: Text(
                  l10n?.defaultPreset ?? 'Default',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      l10n?.defaultPreset ?? 'Default',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  ..._presets.map(
                    (p) => DropdownMenuItem<String?>(
                      value: p.id,
                      child: Text(
                        p.name,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (id) {
                  if (id == null) {
                    setState(() => _selectedPreset = null);
                  } else {
                    final match = _presets.firstWhere((p) => p.id == id);
                    _applyPreset(match);
                  }
                },
              ),
            ),
            Tooltip(
              message: l10n?.saveSearchPreset ?? 'Save Current Search...',
              child: IconButton(
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () => _showSavePresetDialog(context),
              ),
            ),
            if (_selectedPreset != null)
              Tooltip(
                message: l10n?.deletePreset ?? 'Delete preset',
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deletePreset(_selectedPreset!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPresetBar(context, l10n),
        if (widget.filterInput != null) ...[
          widget.filterInput!,
          const SizedBox(height: 12),
        ],
        _buildScanModeSelector(context, l10n),
        const SizedBox(height: 12),
        _buildModeSpecificControls(context, l10n),
        const SizedBox(height: 8),
        _buildAdvancedToggle(context, l10n),
        if (_isAdvancedExpanded) ...[
          const SizedBox(height: 12),
          _buildFilterOptions(context, l10n),
          const SizedBox(height: 12),
          _buildFastTraceToggle(l10n),
          const SizedBox(height: 16),
          _buildConditions(),
        ],
      ],
    );
  }

  Widget _buildScanModeSelector(BuildContext context, AppLocalizations? l10n) {
    return DropdownButtonFormField<TopicScanMode>(
      initialValue: widget.scanMode,
      decoration: InputDecoration(
        labelText: l10n?.scanModeLabel ?? "Mode",
        isDense: true,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(widget.scanMode.icon),
      ),
      items: TopicScanMode.values.map((mode) {
        return DropdownMenuItem<TopicScanMode>(
          value: mode,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(mode.icon, size: 18),
              const SizedBox(width: 8),
              Text(l10n != null ? mode.label(l10n) : mode.name),
            ],
          ),
        );
      }).toList(),
      onChanged: (newMode) {
        if (newMode != null) {
          widget.onScanModeChanged(newMode);
        }
      },
    );
  }

  Widget _buildModeSpecificControls(
    BuildContext context,
    AppLocalizations? l10n,
  ) {
    switch (widget.scanMode) {
      case TopicScanMode.latestN:
        return _buildLimitAndPartition(l10n);
      case TopicScanMode.liveTail:
        return Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sensors,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n?.scanModeLiveTail ?? "Live Stream",
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 140, child: _buildPartitionField(l10n)),
          ],
        );
      case TopicScanMode.timeRange:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.startTimestampController,
                    decoration: InputDecoration(
                      labelText: l10n?.startTimestamp ?? "Start Timestamp",
                      hintText: "YYYY-MM-DDTHH:mm:ss",
                      isDense: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.schedule, size: 18),
                      suffixIcon: widget.variableSuffixBuilder?.call(
                        widget.startTimestampController,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.endTimestampController,
                    decoration: InputDecoration(
                      labelText: l10n?.endTimestamp ?? "End Timestamp",
                      hintText: "YYYY-MM-DDTHH:mm:ss",
                      isDense: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.schedule, size: 18),
                      suffixIcon: widget.variableSuffixBuilder?.call(
                        widget.endTimestampController,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildPartitionField(l10n),
          ],
        );
      case TopicScanMode.offsetEarliest:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.startOffsetController,
                    decoration: InputDecoration(
                      labelText: l10n?.startOffset ?? "Start Offset",
                      isDense: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.tag, size: 18),
                      suffixIcon: widget.variableSuffixBuilder?.call(
                        widget.startOffsetController,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.endOffsetController,
                    decoration: InputDecoration(
                      labelText: l10n?.endOffset ?? "End Offset",
                      isDense: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.tag, size: 18),
                      suffixIcon: widget.variableSuffixBuilder?.call(
                        widget.endOffsetController,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildPartitionField(l10n),
          ],
        );
    }
  }

  Widget _buildPartitionField(AppLocalizations? l10n) {
    return TextField(
      controller: widget.partitionController,
      enabled: !widget.fastTraceEnabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: l10n?.partitionOptional ?? "Partition (Optional)",
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: widget.variableSuffixBuilder?.call(
          widget.partitionController,
        ),
      ),
    );
  }

  Widget _buildAdvancedToggle(BuildContext context, AppLocalizations? l10n) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _isAdvancedExpanded = !_isAdvancedExpanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isAdvancedExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              _isAdvancedExpanded
                  ? (l10n?.collapseAdvancedFilters ??
                        "Collapse advanced filters")
                  : (l10n?.advancedFiltersSection ?? "Advanced Filters"),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOptions(BuildContext context, AppLocalizations? l10n) {
    final typeLabel = l10n?.type ?? "Type";
    final containsLabel = l10n?.contains ?? "Contains";
    final regexLabel = l10n?.regex ?? "Regex";
    final exactLabel = l10n?.exact ?? "Exact";
    final scopeLabel = l10n?.scope ?? "Scope";
    final keyLabel = l10n?.key ?? "Key";
    final valueLabel = l10n?.value ?? "Value";
    final bothLabel = l10n?.both ?? "Both";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(typeLabel, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        GroupButton(
          isRadio: true,
          onSelected: (val, i, selected) =>
              widget.onFilterTypeChanged(FilterType.values[i]),
          buttons: [containsLabel, regexLabel, exactLabel],
          controller: GroupButtonController(
            selectedIndex: widget.filterType.index,
          ),
          options: GroupButtonOptions(
            borderRadius: BorderRadius.circular(8),
            buttonHeight: 28,
            selectedColor: Theme.of(context).colorScheme.secondaryContainer,
            selectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontSize: 11,
            ),
            unselectedColor: Theme.of(context).colorScheme.surface,
            unselectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
            mainGroupAlignment: MainGroupAlignment.start,
          ),
        ),
        const SizedBox(height: 12),
        Text(scopeLabel, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        GroupButton(
          isRadio: true,
          onSelected: (val, i, selected) =>
              widget.onSearchScopeChanged(SearchScope.values[i]),
          buttons: [keyLabel, valueLabel, bothLabel],
          controller: GroupButtonController(
            selectedIndex: widget.searchScope.index,
          ),
          options: GroupButtonOptions(
            borderRadius: BorderRadius.circular(8),
            buttonHeight: 28,
            selectedColor: Theme.of(context).colorScheme.tertiaryContainer,
            selectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onTertiaryContainer,
              fontSize: 11,
            ),
            unselectedColor: Theme.of(context).colorScheme.surface,
            unselectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
            mainGroupAlignment: MainGroupAlignment.start,
          ),
        ),
      ],
    );
  }

  Widget _buildFastTraceToggle(AppLocalizations? l10n) {
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          l10n?.fastTrace ?? "Fast Trace",
          style: const TextStyle(fontSize: 13),
        ),
        value: widget.fastTraceEnabled,
        onChanged: widget.onFastTraceChanged,
        dense: true,
      ),
    );
  }

  Widget _buildLimitAndPartition(AppLocalizations? l10n) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: TextField(
            controller: widget.maxResultsController,
            enabled: widget.limitResults,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n?.limit ?? "Limit",
              isDense: true,
              border: const OutlineInputBorder(),
              prefixIcon: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: widget.limitResults,
                  onChanged: (v) => widget.onLimitResultsChanged(v ?? false),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              suffixIcon: widget.variableSuffixBuilder?.call(
                widget.maxResultsController,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildPartitionField(l10n)),
      ],
    );
  }

  Widget _buildConditions() {
    return Column(
      children: [
        StartConditionConfiguration(
          startStrategy: widget.startStrategy,
          onStartStrategyChanged: widget.onStartStrategyChanged,
          startOffsetController: widget.startOffsetController,
          startTimestampController: widget.startTimestampController,
          variableSuffixBuilder: widget.variableSuffixBuilder,
        ),
        const SizedBox(height: 16),
        EndConditionConfiguration(
          endStrategy: widget.endStrategy,
          onEndStrategyChanged: widget.onEndStrategyChanged,
          endOffsetController: widget.endOffsetController,
          endTimestampController: widget.endTimestampController,
          variableSuffixBuilder: widget.variableSuffixBuilder,
        ),
      ],
    );
  }
}
