import 'dart:async';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:group_button/group_button.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/search/domain/filter_terms.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/end_condition_configuration.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/start_condition_configuration.dart';
import 'package:kafkalyzer/src/rust/api/json_path.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_utils.dart';
import 'package:kafkalyzer/src/ui/timestamp_picker_field.dart';

/// Simplified topic search and consumption control bar.
///
/// Provides a compact single-row interface for standard searches with
/// preset scan modes, progressive disclosure for advanced filters,
/// filter summary chips, and context-sensitive action buttons.
class TopicSearchBar extends StatefulWidget {
  final TopicScanMode scanMode;
  final ValueChanged<TopicScanMode> onScanModeChanged;

  final TextEditingController quickFilterController;
  final TextEditingController fieldController;
  final FilterType filterType;
  final ValueChanged<FilterType> onFilterTypeChanged;
  final SearchScope searchScope;
  final ValueChanged<SearchScope> onSearchScopeChanged;

  final bool limitResults;
  final ValueChanged<bool> onLimitResultsChanged;
  final TextEditingController maxResultsController;
  final TextEditingController partitionController;
  final bool fastTraceEnabled;
  final ValueChanged<bool> onFastTraceEnabledChanged;
  final int? partitionCount;

  final MultiSearchStartStrategy startStrategy;
  final ValueChanged<MultiSearchStartStrategy> onStartStrategyChanged;
  final TextEditingController startOffsetController;
  final TextEditingController startTimestampController;

  final MultiSearchEndStrategy endStrategy;
  final ValueChanged<MultiSearchEndStrategy> onEndStrategyChanged;
  final TextEditingController endOffsetController;
  final TextEditingController endTimestampController;

  final VoidCallback onStart;

  final Future<List<String>> Function()? schemaFieldsFetcher;

  const TopicSearchBar({
    super.key,
    required this.scanMode,
    required this.onScanModeChanged,
    required this.quickFilterController,
    required this.fieldController,
    required this.filterType,
    required this.onFilterTypeChanged,
    required this.searchScope,
    required this.onSearchScopeChanged,
    required this.limitResults,
    required this.onLimitResultsChanged,
    required this.maxResultsController,
    required this.partitionController,
    required this.fastTraceEnabled,
    required this.onFastTraceEnabledChanged,
    this.partitionCount,
    required this.startStrategy,
    required this.onStartStrategyChanged,
    required this.startOffsetController,
    required this.startTimestampController,
    required this.endStrategy,
    required this.onEndStrategyChanged,
    required this.endOffsetController,
    required this.endTimestampController,
    required this.onStart,
    this.schemaFieldsFetcher,
  });

  @override
  State<TopicSearchBar> createState() => _TopicSearchBarState();
}

class _TopicSearchBarState extends State<TopicSearchBar> {
  bool _isAdvancedExpanded = false;

  static const List<int> _presetLimits = [50, 200, 500, 1000];

  // A regex term the scan engine cannot compile; validated by the same Rust
  // engine that will run the scan, so a term cannot silently degrade matching.
  String? _invalidPattern;
  Timer? _validationDebounce;
  Timer? _previewDebounce;
  int _previewRequestId = 0;
  int? _predictedPartition;
  bool _previewFailed = false;

  @override
  void initState() {
    super.initState();
    widget.quickFilterController.addListener(_onQuickFilterChanged);
    _validatePatterns();
    _updatePartitionPreview();
  }

  @override
  void didUpdateWidget(covariant TopicSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quickFilterController != oldWidget.quickFilterController) {
      oldWidget.quickFilterController.removeListener(_onQuickFilterChanged);
      widget.quickFilterController.addListener(_onQuickFilterChanged);
    }
    if (widget.filterType != oldWidget.filterType) {
      _validatePatterns();
    }
    if (widget.fastTraceEnabled != oldWidget.fastTraceEnabled ||
        widget.partitionCount != oldWidget.partitionCount ||
        widget.quickFilterController != oldWidget.quickFilterController) {
      _updatePartitionPreview();
    }
  }

  @override
  void dispose() {
    widget.quickFilterController.removeListener(_onQuickFilterChanged);
    _validationDebounce?.cancel();
    _previewDebounce?.cancel();
    super.dispose();
  }

  void _onQuickFilterChanged() {
    if (widget.fastTraceEnabled) {
      _schedulePartitionPreview();
    }
  }

  void _schedulePartitionPreview() {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(
      const Duration(milliseconds: 300),
      _updatePartitionPreview,
    );
  }

  Future<void> _updatePartitionPreview() async {
    final requestId = ++_previewRequestId;
    final count = widget.partitionCount;
    if (!widget.fastTraceEnabled || count == null || count <= 0) {
      if ((_predictedPartition != null || _previewFailed) && mounted) {
        setState(() {
          _predictedPartition = null;
          _previewFailed = false;
        });
      }
      return;
    }

    final terms = splitFilterTerms(widget.quickFilterController.text);
    if (terms.isEmpty) {
      if ((_predictedPartition != null || _previewFailed) && mounted) {
        setState(() {
          _predictedPartition = null;
          _previewFailed = false;
        });
      }
      return;
    }

    try {
      final partition = await predictDefaultPartition(
        key: terms.first,
        partitionCount: count,
      );
      if (!mounted || requestId != _previewRequestId) return;
      setState(() {
        _predictedPartition = partition;
        _previewFailed = partition == null;
      });
    } catch (e, stack) {
      if (GetIt.instance.isRegistered<Logger>()) {
        GetIt.instance<Logger>().w(
          'Fast Trace partition preview failed (partitionCount=$count)',
          error: e,
          stackTrace: stack,
        );
      }
      if (!mounted || requestId != _previewRequestId) return;
      setState(() {
        _predictedPartition = null;
        _previewFailed = true;
      });
    }
  }

  void _schedulePatternValidation() {
    _validationDebounce?.cancel();
    _validationDebounce = Timer(
      const Duration(milliseconds: 300),
      _validatePatterns,
    );
  }

  Future<void> _validatePatterns() async {
    final term = widget.quickFilterController.text.trim();
    if (widget.filterType != FilterType.regex || term.isEmpty) {
      if (_invalidPattern != null && mounted) {
        setState(() => _invalidPattern = null);
      }
      return;
    }

    final invalid = await validateFilterPatterns(terms: [term]);
    if (!mounted) return;
    setState(() => _invalidPattern = invalid.isEmpty ? null : invalid.first);
  }

  Future<void> _onStart() async {
    await _validatePatterns();
    if (!mounted || _invalidPattern != null) return;
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: colorScheme.surfaceContainerLowest,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 920;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildScanModeSelector(context, l10n, colorScheme),
                      const SizedBox(width: 8),
                      _buildLimitSelector(context, l10n, colorScheme),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickFilterField(l10n, colorScheme),
                      ),
                      const SizedBox(width: 8),
                      _buildAdvancedToggleButton(l10n, colorScheme),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildScanModeSelector(
                              context,
                              l10n,
                              colorScheme,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildLimitSelector(context, l10n, colorScheme),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickFilterField(l10n, colorScheme),
                          ),
                          const SizedBox(width: 8),
                          _buildAdvancedToggleButton(l10n, colorScheme),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
            if (!_isAdvancedExpanded && _hasActiveAdvancedFilters()) ...[
              const SizedBox(height: 6),
              _buildActiveFilterChips(context, l10n, colorScheme),
            ],
            if (widget.scanMode == TopicScanMode.timeRange) ...[
              const SizedBox(height: 10),
              _buildTimeRangeRow(context, colorScheme),
            ],
            if (widget.scanMode == TopicScanMode.offsetEarliest) ...[
              const SizedBox(height: 10),
              _buildOffsetEarliestRow(context, colorScheme),
            ],
            if (_isAdvancedExpanded)
              _buildAdvancedPanel(context, l10n, colorScheme),
          ],
        ),
      ),
    );
  }

  bool _hasActiveAdvancedFilters() {
    return widget.fieldController.text.isNotEmpty ||
        widget.filterType != FilterType.contains ||
        widget.searchScope != SearchScope.both ||
        widget.partitionController.text.isNotEmpty ||
        widget.fastTraceEnabled;
  }

  Widget _buildScanModeSelector(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TopicScanMode>(
          value: widget.scanMode,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          items: TopicScanMode.values.map((mode) {
            return DropdownMenuItem<TopicScanMode>(
              value: mode,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(mode.icon, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    mode.label(l10n),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (newMode) {
            if (newMode != null) {
              widget.onScanModeChanged(newMode);
              widget.onStartStrategyChanged(newMode.defaultStartStrategy);
              widget.onEndStrategyChanged(newMode.defaultEndStrategy);
            }
          },
        ),
      ),
    );
  }

  Widget _buildLimitSelector(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final currentVal = widget.limitResults
        ? int.tryParse(widget.maxResultsController.text)
        : null;

    final items = <DropdownMenuItem<int?>>[
      for (final p in _presetLimits)
        DropdownMenuItem<int?>(
          value: p,
          child: Text(
            "$p",
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      DropdownMenuItem<int?>(
        value: null,
        child: Text(
          l10n.limitAll,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    ];

    if (currentVal != null && !_presetLimits.contains(currentVal)) {
      items.insert(
        0,
        DropdownMenuItem<int?>(
          value: currentVal,
          child: Text(
            "$currentVal",
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: currentVal,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          hint: Text(
            "${l10n.limitLabel}: 200",
            style: const TextStyle(fontSize: 13),
          ),
          items: items,
          onChanged: (val) {
            if (val == null) {
              widget.onLimitResultsChanged(false);
            } else {
              widget.onLimitResultsChanged(true);
              widget.maxResultsController.text = val.toString();
            }
          },
        ),
      ),
    );
  }

  Widget _buildQuickFilterField(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final errorText = _invalidPattern == null
        ? null
        : l10n.invalidFilterPattern(_invalidPattern!);
    final borderColor = errorText == null
        ? colorScheme.outlineVariant.withValues(alpha: 0.8)
        : colorScheme.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 38,
          child: _buildQuickFilterInput(
            l10n.quickFilterPlaceholder,
            colorScheme,
            borderColor,
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              errorText,
              key: const Key('quick_filter_pattern_error'),
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                color: colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickFilterInput(
    String hintText,
    ColorScheme colorScheme,
    Color borderColor,
  ) {
    OutlineInputBorder outline(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );

    return TextField(
      controller: widget.quickFilterController,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: widget.quickFilterController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                tooltip: AppLocalizations.of(context)?.clear ?? 'Clear',
                splashRadius: 16,
                onPressed: () {
                  widget.quickFilterController.clear();
                  setState(() {});
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        filled: true,
        fillColor: colorScheme.surface,
        border: outline(borderColor),
        enabledBorder: outline(borderColor),
      ),
      onChanged: (_) {
        setState(() {});
        _schedulePatternValidation();
      },
      onSubmitted: (_) => _onStart(),
    );
  }

  Widget _buildAdvancedToggleButton(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final hasActiveFilters = _hasActiveAdvancedFilters();
    final tooltip = _isAdvancedExpanded
        ? l10n.collapseAdvancedFilters
        : l10n.expandAdvancedFilters;

    return Tooltip(
      message: tooltip,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: BorderSide(
            color: hasActiveFilters
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
          backgroundColor: hasActiveFilters
              ? colorScheme.primaryContainer.withValues(alpha: 0.2)
              : colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () =>
            setState(() => _isAdvancedExpanded = !_isAdvancedExpanded),
        icon: Icon(
          Icons.tune,
          size: 16,
          color: hasActiveFilters ? colorScheme.primary : null,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.advancedFiltersToggle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasActiveFilters
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: hasActiveFilters ? colorScheme.primary : null,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _isAdvancedExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterChips(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final chips = <Widget>[];

    if (widget.fieldController.text.isNotEmpty) {
      chips.add(
        InputChip(
          visualDensity: VisualDensity.compact,
          label: Text(
            l10n.chipField(widget.fieldController.text),
            style: const TextStyle(fontSize: 11),
          ),
          deleteIcon: const Icon(Icons.clear, size: 14),
          onDeleted: () {
            widget.fieldController.clear();
            setState(() {});
          },
        ),
      );
    }

    if (widget.filterType != FilterType.contains) {
      chips.add(
        InputChip(
          key: const Key('filter_type_chip'),
          visualDensity: VisualDensity.compact,
          avatar: _invalidPattern == null
              ? null
              : Icon(Icons.error, size: 14, color: colorScheme.error),
          label: Text(
            l10n.chipFilterType(widget.filterType.name),
            style: TextStyle(
              fontSize: 11,
              color: _invalidPattern == null ? null : colorScheme.error,
            ),
          ),
          deleteIcon: const Icon(Icons.clear, size: 14),
          onDeleted: () {
            widget.onFilterTypeChanged(FilterType.contains);
          },
        ),
      );
    }

    if (widget.searchScope != SearchScope.both) {
      chips.add(
        InputChip(
          visualDensity: VisualDensity.compact,
          label: Text(
            l10n.chipScope(widget.searchScope.name),
            style: const TextStyle(fontSize: 11),
          ),
          deleteIcon: const Icon(Icons.clear, size: 14),
          onDeleted: () {
            widget.onSearchScopeChanged(SearchScope.both);
          },
        ),
      );
    }

    if (widget.partitionController.text.isNotEmpty) {
      chips.add(
        InputChip(
          visualDensity: VisualDensity.compact,
          label: Text(
            l10n.chipPartition(widget.partitionController.text),
            style: const TextStyle(fontSize: 11),
          ),
          deleteIcon: const Icon(Icons.clear, size: 14),
          onDeleted: () {
            widget.partitionController.clear();
            setState(() {});
          },
        ),
      );
    }

    if (widget.fastTraceEnabled) {
      final chipLabel = _predictedPartition != null
          ? l10n.chipFastTracePartition(_predictedPartition!)
          : l10n.chipFastTrace;
      chips.add(
        InputChip(
          visualDensity: VisualDensity.compact,
          label: Text(chipLabel, style: const TextStyle(fontSize: 11)),
          deleteIcon: const Icon(Icons.clear, size: 14),
          onDeleted: () {
            widget.onFastTraceEnabledChanged(false);
          },
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }

  Widget _buildTimeRangeRow(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TimestampPickerField(
              controller: widget.startTimestampController,
              label: AppLocalizations.of(context)?.startTime ?? 'Start Time',
              showInlineChips: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TimestampPickerField(
              controller: widget.endTimestampController,
              label: AppLocalizations.of(context)?.endTime ?? 'End Time',
              showInlineChips: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffsetEarliestRow(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StartConditionConfiguration(
              startStrategy: widget.startStrategy,
              onStartStrategyChanged: widget.onStartStrategyChanged,
              startOffsetController: widget.startOffsetController,
              startTimestampController: widget.startTimestampController,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: EndConditionConfiguration(
              endStrategy: widget.endStrategy,
              onEndStrategyChanged: widget.onEndStrategyChanged,
              endOffsetController: widget.endOffsetController,
              endTimestampController: widget.endTimestampController,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedPanel(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildFieldAutocomplete(context)),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: widget.partitionController,
                  enabled: !widget.fastTraceEnabled,
                  decoration: InputDecoration(
                    labelText:
                        AppLocalizations.of(context)?.partitionOptional ??
                        'Partition (Opt.)',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
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
              _buildFilterTypeSelector(colorScheme),
              _buildSearchScopeSelector(colorScheme),
              Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  width: 200,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      l10n.fastTrace,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    value: widget.fastTraceEnabled,
                    onChanged: (val) {
                      widget.onFastTraceEnabledChanged(val);
                      if (val) {
                        widget.onFilterTypeChanged(FilterType.exact);
                        widget.onSearchScopeChanged(SearchScope.key);
                      }
                      setState(() {});
                    },
                  ),
                ),
              ),
            ],
          ),
          if (widget.fastTraceEnabled) ...[
            const SizedBox(height: 8),
            _buildFastTracePreview(context, l10n, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildFastTracePreview(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final terms = splitFilterTerms(widget.quickFilterController.text);
    final count = widget.partitionCount;

    final IconData statusIcon;
    final String statusText;
    if (terms.isEmpty) {
      statusIcon = Icons.info_outline;
      statusText = l10n.fastTraceEnterKeyHint;
    } else if (count == null || count <= 0 || _previewFailed) {
      statusIcon = Icons.help_outline;
      statusText = l10n.fastTracePartitionCountUnknown;
    } else if (_predictedPartition != null) {
      statusIcon = Icons.alt_route;
      statusText = l10n.fastTracePartitionPreview(_predictedPartition!, count);
    } else {
      statusIcon = Icons.hourglass_empty;
      statusText = l10n.fastTraceAssumptionSummary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusText,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Tooltip(
                message: l10n.fastTraceAssumptionCaveat,
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                  semanticLabel: l10n.fastTraceAssumptionInfoLabel,
                ),
              ),
            ],
          ),
          if (terms.length > 1) ...[
            const SizedBox(height: 4),
            Text(
              l10n.fastTraceFirstTermOnlyNote,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            l10n.fastTraceAssumptionSummary,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldAutocomplete(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) async {
        if (widget.schemaFieldsFetcher == null) return const [];
        final fields = await widget.schemaFieldsFetcher!();
        if (textEditingValue.text.isEmpty) return fields;
        return fields.where(
          (f) => f.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      onSelected: (selection) {
        widget.fieldController.text = selection;
        setState(() {});
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        if (textController.text != widget.fieldController.text) {
          textController.text = widget.fieldController.text;
        }
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText:
                AppLocalizations.of(context)?.fieldOptional ?? 'Field (Opt.)',
            isDense: true,
            prefixIcon: const Icon(Icons.data_object, size: 18),
          ),
          onChanged: (val) {
            widget.fieldController.text = val;
            setState(() {});
          },
        );
      },
    );
  }

  Widget _buildFilterTypeSelector(ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${AppLocalizations.of(context)?.type ?? 'Type'}:',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        GroupButton(
          isRadio: true,
          onSelected: (val, i, selected) {
            final newType = FilterType.values[i];
            widget.onFilterTypeChanged(newType);
            if (widget.fastTraceEnabled && newType != FilterType.exact) {
              widget.onFastTraceEnabledChanged(false);
            }
            setState(() {});
          },
          buttons: const ["Contains", "Regex", "Exact"],
          controller: GroupButtonController(
            selectedIndex: widget.filterType.index,
          ),
          options: GroupButtonOptions(
            borderRadius: BorderRadius.circular(8),
            buttonHeight: 30,
            textPadding: const EdgeInsets.symmetric(horizontal: 10),
            selectedColor: colorScheme.primaryContainer,
            selectedTextStyle: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 12,
            ),
            unselectedColor: colorScheme.surfaceContainerHigh,
            unselectedTextStyle: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
            mainGroupAlignment: MainGroupAlignment.start,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchScopeSelector(ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${AppLocalizations.of(context)?.scope ?? 'Scope'}:',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        GroupButton(
          isRadio: true,
          onSelected: (val, i, selected) {
            final newScope = SearchScope.values[i];
            widget.onSearchScopeChanged(newScope);
            if (widget.fastTraceEnabled && newScope != SearchScope.key) {
              widget.onFastTraceEnabledChanged(false);
            }
            setState(() {});
          },
          buttons: const ["Key", "Value", "Both"],
          controller: GroupButtonController(
            selectedIndex: widget.searchScope.index,
          ),
          options: GroupButtonOptions(
            borderRadius: BorderRadius.circular(8),
            buttonHeight: 30,
            textPadding: const EdgeInsets.symmetric(horizontal: 10),
            selectedColor: colorScheme.primaryContainer,
            selectedTextStyle: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 12,
            ),
            unselectedColor: colorScheme.surfaceContainerHigh,
            unselectedTextStyle: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
            mainGroupAlignment: MainGroupAlignment.start,
          ),
        ),
      ],
    );
  }
}
