import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/search/domain/filter_field_suggestions.dart';
import 'package:kafkalyzer/src/features/search/domain/filter_terms.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/filter_expression_editing_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/end_condition_configuration.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/filter_expression_editor.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/start_condition_configuration.dart';
import 'package:kafkalyzer/src/rust/api/json_path.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_utils.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
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
  final FilterExpressionEditingController? filterExpressionController;
  final FilterFieldSuggestions? filterSuggestions;

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
    this.filterExpressionController,
    this.filterSuggestions,
  });

  @override
  State<TopicSearchBar> createState() => _TopicSearchBarState();
}

class _TopicSearchBarState extends State<TopicSearchBar> {
  bool _isAdvancedExpanded = false;
  final OverlayPortalController _moreFiltersPortalController =
      OverlayPortalController();
  final LayerLink _moreFiltersLayerLink = LayerLink();
  final FocusNode _popoverFocusNode = FocusNode(
    debugLabel: 'MoreFiltersPopover',
  );

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
    widget.startTimestampController.addListener(_onTimestampBoundChanged);
    widget.endTimestampController.addListener(_onTimestampBoundChanged);
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
    if (widget.startTimestampController != oldWidget.startTimestampController) {
      oldWidget.startTimestampController.removeListener(
        _onTimestampBoundChanged,
      );
      widget.startTimestampController.addListener(_onTimestampBoundChanged);
    }
    if (widget.endTimestampController != oldWidget.endTimestampController) {
      oldWidget.endTimestampController.removeListener(_onTimestampBoundChanged);
      widget.endTimestampController.addListener(_onTimestampBoundChanged);
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
    widget.startTimestampController.removeListener(_onTimestampBoundChanged);
    widget.endTimestampController.removeListener(_onTimestampBoundChanged);
    _validationDebounce?.cancel();
    _previewDebounce?.cancel();
    _popoverFocusNode.dispose();
    super.dispose();
  }

  void _onTimestampBoundChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  DateTime? _parseBoundTimestamp(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateFormatUtils.parseDateTime(context, trimmed);
    if (parsed != null) return parsed;
    final epoch = int.tryParse(trimmed);
    if (epoch != null) return DateTime.fromMillisecondsSinceEpoch(epoch);
    return null;
  }

  ({String? startError, String? endError}) _validateTimeBounds(
    AppLocalizations l10n,
  ) {
    final checkStart =
        widget.scanMode == TopicScanMode.timeRange ||
        (widget.scanMode == TopicScanMode.offsetEarliest &&
            widget.startStrategy == MultiSearchStartStrategy.customTimestamp);
    final checkEnd =
        widget.scanMode == TopicScanMode.timeRange ||
        (widget.scanMode == TopicScanMode.offsetEarliest &&
            widget.endStrategy == MultiSearchEndStrategy.customTimestamp);

    String? startErr;
    String? endErr;
    DateTime? startDt;
    DateTime? endDt;

    if (checkStart && widget.startTimestampController.text.trim().isNotEmpty) {
      startDt = _parseBoundTimestamp(widget.startTimestampController.text);
      if (startDt == null) {
        startErr = l10n.timeRangeInvalidTimestampError;
      }
    }
    if (checkEnd && widget.endTimestampController.text.trim().isNotEmpty) {
      endDt = _parseBoundTimestamp(widget.endTimestampController.text);
      if (endDt == null) {
        endErr = l10n.timeRangeInvalidTimestampError;
      }
    }
    if (startDt != null && endDt != null && endDt.isBefore(startDt)) {
      endErr = l10n.timeRangeEndBeforeStartError;
    }
    return (startError: startErr, endError: endErr);
  }

  void _openMoreFiltersPopover() {
    if (!_moreFiltersPortalController.isShowing) {
      _moreFiltersPortalController.show();
    }
    setState(() => _isAdvancedExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isAdvancedExpanded) {
        _popoverFocusNode.requestFocus();
      }
    });
  }

  void _closeMoreFiltersPopover() {
    if (_moreFiltersPortalController.isShowing) {
      _moreFiltersPortalController.hide();
    }
    if (_isAdvancedExpanded && mounted) {
      setState(() => _isAdvancedExpanded = false);
    }
  }

  void _toggleMoreFiltersPopover() {
    if (_isAdvancedExpanded) {
      _closeMoreFiltersPopover();
    } else {
      _openMoreFiltersPopover();
    }
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
    final l10n = AppLocalizations.of(context)!;
    final boundsErrors = _validateTimeBounds(l10n);
    if (boundsErrors.startError != null || boundsErrors.endError != null) {
      setState(() {});
      return;
    }
    final exprCtrl = widget.filterExpressionController;
    if (exprCtrl != null && !exprCtrl.validateNow()) {
      _openMoreFiltersPopover();
      return;
    }
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
          ],
        ),
      ),
    );
  }

  int _activePopoverFiltersCount() {
    int count = 0;
    if (widget.fieldController.text.isNotEmpty) count++;
    if (widget.partitionController.text.isNotEmpty) count++;
    if (widget.fastTraceEnabled) count++;
    if (widget.filterExpressionController?.text.trim().isNotEmpty ?? false) {
      count++;
    }
    return count;
  }

  bool _hasActiveAdvancedFilters() {
    return _activePopoverFiltersCount() > 0 ||
        widget.filterType != FilterType.contains ||
        widget.searchScope != SearchScope.both;
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

  String _localizedScopeLabel(AppLocalizations l10n, SearchScope scope) {
    return switch (scope) {
      SearchScope.key => l10n.key,
      SearchScope.value => l10n.value,
      SearchScope.both => l10n.both,
    };
  }

  String _localizedTypeLabel(AppLocalizations l10n, FilterType type) {
    return switch (type) {
      FilterType.contains => l10n.contains,
      FilterType.regex => l10n.regex,
      FilterType.exact => l10n.exact,
    };
  }

  String _fetchFilterPlaceholder(AppLocalizations l10n, SearchScope scope) {
    return switch (scope) {
      SearchScope.key => l10n.fetchFilterPlaceholderKey,
      SearchScope.value => l10n.fetchFilterPlaceholderValue,
      SearchScope.both => l10n.fetchFilterPlaceholderBoth,
    };
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
        Tooltip(
          message: l10n.fetchFilterTooltip,
          child: SizedBox(
            height: 38,
            child: _buildQuickFilterInput(
              _fetchFilterPlaceholder(l10n, widget.searchScope),
              l10n,
              colorScheme,
              borderColor,
            ),
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
    AppLocalizations l10n,
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
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.quickFilterController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 16),
                tooltip: l10n.clear,
                splashRadius: 16,
                onPressed: () {
                  widget.quickFilterController.clear();
                  setState(() {});
                },
              ),
            _buildInlineScopeTypeMenu(l10n, colorScheme),
            const SizedBox(width: 4),
          ],
        ),
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

  Widget _buildInlineScopeTypeMenu(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final hasInvalidRegex = _invalidPattern != null;
    final summary = l10n.fetchFilterScopeTypeSummary(
      _localizedScopeLabel(l10n, widget.searchScope),
      _localizedTypeLabel(l10n, widget.filterType),
    );
    final isNonDefault =
        widget.searchScope != SearchScope.both ||
        widget.filterType != FilterType.contains;

    return MenuAnchor(
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Text(
            l10n.scope,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final scope in SearchScope.values)
          MenuItemButton(
            leadingIcon: Icon(
              widget.searchScope == scope
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 16,
              color: widget.searchScope == scope
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              widget.onSearchScopeChanged(scope);
              if (widget.fastTraceEnabled && scope != SearchScope.key) {
                widget.onFastTraceEnabledChanged(false);
              }
              setState(() {});
            },
            child: Text(_localizedScopeLabel(l10n, scope)),
          ),
        const Divider(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
          child: Text(
            l10n.type,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final type in FilterType.values)
          MenuItemButton(
            leadingIcon: Icon(
              widget.filterType == type
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 16,
              color: widget.filterType == type
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              widget.onFilterTypeChanged(type);
              if (widget.fastTraceEnabled && type != FilterType.exact) {
                widget.onFastTraceEnabledChanged(false);
              }
              setState(() {});
            },
            child: Text(_localizedTypeLabel(l10n, type)),
          ),
      ],
      builder: (context, controller, child) {
        return Semantics(
          label: l10n.fetchFilterMenuTooltip,
          button: true,
          child: Tooltip(
            message: l10n.fetchFilterMenuTooltip,
            child: InkWell(
              key: const Key('fetch_filter_scope_type_menu'),
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 26),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasInvalidRegex
                      ? colorScheme.errorContainer
                      : (isNonDefault
                            ? colorScheme.primaryContainer.withValues(
                                alpha: 0.5,
                              )
                            : colorScheme.surfaceContainerHigh),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasInvalidRegex) ...[
                      Icon(
                        Icons.error,
                        key: const Key('fetch_filter_invalid_regex_icon'),
                        size: 14,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      summary,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isNonDefault
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: hasInvalidRegex
                            ? colorScheme.onErrorContainer
                            : (isNonDefault
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: hasInvalidRegex
                          ? colorScheme.onErrorContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdvancedToggleButton(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final activeCount = _activePopoverFiltersCount();
    final hasActiveFilters = activeCount > 0;
    final tooltip = _isAdvancedExpanded
        ? l10n.moreFiltersCloseTooltip
        : l10n.moreFiltersOpenTooltip;
    final labelText = activeCount > 0
        ? l10n.moreFiltersButtonWithCount(activeCount)
        : l10n.moreFiltersButton;

    return CompositedTransformTarget(
      link: _moreFiltersLayerLink,
      child: OverlayPortal(
        controller: _moreFiltersPortalController,
        overlayChildBuilder: (overlayContext) =>
            _buildMoreFiltersPopoverOverlay(context, l10n, colorScheme),
        child: Tooltip(
          message: tooltip,
          child: OutlinedButton.icon(
            key: const Key('more_filters_button'),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _toggleMoreFiltersPopover,
            icon: Icon(
              Icons.tune,
              size: 16,
              color: hasActiveFilters ? colorScheme.primary : null,
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labelText,
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
        ),
      ),
    );
  }

  Widget _buildMoreFiltersPopoverOverlay(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final mediaSize = MediaQuery.sizeOf(context);
    final maxHeight = (mediaSize.height * 0.75).clamp(220.0, 640.0);
    final maxWidth = (mediaSize.width - 32.0).clamp(320.0, 680.0);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('more_filters_popover_barrier'),
            behavior: HitTestBehavior.translucent,
            onTap: _closeMoreFiltersPopover,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: _moreFiltersLayerLink,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 6),
          child: Focus(
            focusNode: _popoverFocusNode,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                _closeMoreFiltersPopover();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(10),
              color: colorScheme.surface,
              child: Container(
                key: const Key('more_filters_popover'),
                width: maxWidth,
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.8),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: _buildMoreFiltersPopoverContent(
                    context,
                    l10n,
                    colorScheme,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
          onPressed: _openMoreFiltersPopover,
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

    if (widget.filterExpressionController != null &&
        widget.filterExpressionController!.text.trim().isNotEmpty) {
      final exprText = widget.filterExpressionController!.text.trim();
      final hasErr = !widget.filterExpressionController!.isValid;
      chips.add(
        Tooltip(
          message: hasErr
              ? '${l10n.filterExpressionInvalidTooltip}: $exprText'
              : exprText,
          child: InputChip(
            key: const Key('filter_expression_chip'),
            visualDensity: VisualDensity.compact,
            avatar: hasErr
                ? Icon(Icons.error, size: 14, color: colorScheme.error)
                : null,
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                l10n.filterExpressionChipSummary(exprText),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: hasErr ? colorScheme.error : null,
                ),
              ),
            ),
            onPressed: _openMoreFiltersPopover,
            deleteIcon: const Icon(Icons.clear, size: 14),
            onDeleted: () {
              widget.filterExpressionController!.setText('');
              setState(() {});
            },
          ),
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
          onPressed: _openMoreFiltersPopover,
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
          onPressed: _openMoreFiltersPopover,
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
    final l10n = AppLocalizations.of(context)!;
    final errors = _validateTimeBounds(l10n);

    final startField = TimestampPickerField(
      controller: widget.startTimestampController,
      label: l10n.startTime,
      compactPresets: true,
      errorText: errors.startError,
    );
    final endField = TimestampPickerField(
      controller: widget.endTimestampController,
      label: l10n.endTime,
      compactPresets: true,
      errorText: errors.endError,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide =
              !constraints.maxWidth.isFinite || constraints.maxWidth >= 640;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: startField),
                const SizedBox(width: 12),
                Expanded(child: endField),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [startField, const SizedBox(height: 8), endField],
          );
        },
      ),
    );
  }

  Widget _buildOffsetEarliestRow(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final startConfig = StartConditionConfiguration(
      startStrategy: widget.startStrategy,
      onStartStrategyChanged: widget.onStartStrategyChanged,
      startOffsetController: widget.startOffsetController,
      startTimestampController: widget.startTimestampController,
      compactPresets: true,
    );
    final endConfig = EndConditionConfiguration(
      endStrategy: widget.endStrategy,
      onEndStrategyChanged: widget.onEndStrategyChanged,
      endOffsetController: widget.endOffsetController,
      endTimestampController: widget.endTimestampController,
      compactPresets: true,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide =
              !constraints.maxWidth.isFinite || constraints.maxWidth >= 640;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: startConfig),
                const SizedBox(width: 12),
                Expanded(child: endConfig),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [startConfig, const SizedBox(height: 8), endConfig],
          );
        },
      ),
    );
  }

  Widget _buildMoreFiltersPopoverContent(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
        Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: 220,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                l10n.fastTrace,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
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
        if (widget.fastTraceEnabled) ...[
          const SizedBox(height: 8),
          _buildFastTracePreview(context, l10n, colorScheme),
        ],
        if (widget.filterExpressionController != null) ...[
          const SizedBox(height: 12),
          FilterExpressionEditor(
            controller: widget.filterExpressionController!,
            suggestions: widget.filterSuggestions,
          ),
        ],
      ],
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
}
