import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/ui/smart_tree/schema_path_utils.dart';
import 'package:kafkalyzer/src/services/time_display_settings.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/ui/smart_tree/copyable_node_text.dart';
import 'package:kafkalyzer/src/ui/smart_tree/json_tree_flattener.dart';
import 'package:kafkalyzer/src/ui/smart_tree/smart_composite_badge.dart';
import 'package:kafkalyzer/src/ui/smart_tree/virtual_json_node.dart';
import 'package:kafkalyzer/src/ui/widgets/decode_l10n_helper.dart';
import 'package:kafkalyzer/src/utils/app_fonts.dart';
import 'package:kafkalyzer/src/utils/nested_value_decoder.dart';
import 'package:kafkalyzer/src/utils/payload_processing_isolate.dart';

/// A flat, virtualized JSON tree widget rendering only visible rows for optimal 60 FPS performance.
///
/// Supports progressive disclosure with smart badges, context windowing (matches ±1) for long arrays,
/// and indentation flattening for unbranched hierarchy chains.
class SmartVirtualJsonTree extends StatefulWidget {
  final dynamic json;
  final String? searchQuery;
  final ValueChanged<int>? onMatchCountChanged;
  final int? focusedMatchIndex;
  final bool enableContextWindowing;
  final bool enableIndentationFlattening;
  final bool hideNullFields;
  final bool autoExpandSingleItemCollections;
  final int contextRadius;
  final ValueChanged<String>? onPinToColumn;
  final ValueChanged<String>? onFilterByField;
  final bool shrinkWrap;

  const SmartVirtualJsonTree({
    super.key,
    required this.json,
    this.searchQuery,
    this.onMatchCountChanged,
    this.focusedMatchIndex,
    this.enableContextWindowing = true,
    this.enableIndentationFlattening = true,
    this.hideNullFields = false,
    this.autoExpandSingleItemCollections = true,
    this.contextRadius = 1,
    this.onPinToColumn,
    this.onFilterByField,
    this.shrinkWrap = false,
  });

  @override
  State<SmartVirtualJsonTree> createState() => SmartVirtualJsonTreeState();
}

class SmartVirtualJsonTreeState extends State<SmartVirtualJsonTree> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final Set<String> _expandedPaths = {};
  final Set<String> _manuallyCollapsedPaths = {};
  final Set<String> _manuallyExpandedRanges = {};
  final Set<String> _forcedShowAllArrays = {};

  late FlattenResult _flattenResult;
  int _lastReportedMatchCount = -1;
  int _activeMatchIndex = -1;
  final Map<String, _NodeDecodeState> _decodes = {};
  int _decodeGeneration = 0;
  late final TimeDisplaySettings _timeDisplaySettings;

  @override
  void initState() {
    super.initState();
    _timeDisplaySettings = getIt.isRegistered<TimeDisplaySettings>()
        ? getIt<TimeDisplaySettings>()
        : TimeDisplaySettings.fallback;
    _timeDisplaySettings.addListener(_onTimeDisplayChanged);
    _recalculateFlattening();
  }

  @override
  void dispose() {
    _timeDisplaySettings.removeListener(_onTimeDisplayChanged);
    super.dispose();
  }

  void _onTimeDisplayChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant SmartVirtualJsonTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.json != oldWidget.json ||
        widget.searchQuery != oldWidget.searchQuery ||
        widget.enableContextWindowing != oldWidget.enableContextWindowing ||
        widget.enableIndentationFlattening !=
            oldWidget.enableIndentationFlattening ||
        widget.hideNullFields != oldWidget.hideNullFields ||
        widget.autoExpandSingleItemCollections !=
            oldWidget.autoExpandSingleItemCollections ||
        widget.contextRadius != oldWidget.contextRadius) {
      if (widget.json != oldWidget.json) {
        _decodes.clear();
        _decodeGeneration++;
      }
      if (widget.searchQuery != oldWidget.searchQuery) {
        _manuallyExpandedRanges.clear();
        _forcedShowAllArrays.clear();
        _activeMatchIndex = -1;
      }
      _recalculateFlattening();
    }
  }

  Map<String, DecodedTreeEntry> _decodedValuesForFlattener() {
    final map = <String, DecodedTreeEntry>{};
    for (final entry in _decodes.entries) {
      final result = entry.value.result;
      if (result == null || result is DecodeFailure) continue;
      map[entry.key] = (kind: entry.value.kind, result: result);
    }
    return map;
  }

  Future<void> _triggerDecode(
    String path,
    Object input,
    DecodeKind kind,
  ) async {
    final generation = _decodeGeneration;
    setState(() {
      _decodes[path] = _NodeDecodeState.pending(kind);
    });

    final result = await decodeValueAsync(input, kind);
    if (!mounted || generation != _decodeGeneration) return;

    setState(() {
      if (result is DecodeFailure) {
        _decodes[path] = _NodeDecodeState.error(kind, result.error);
      } else {
        _decodes[path] = _NodeDecodeState.done(kind, result);
        _expandedPaths.add(path);
        _manuallyCollapsedPaths.remove(path);
        _recalculateFlattening();
      }
    });
  }

  void _clearDecode(String path) {
    setState(() {
      _decodes.removeWhere(
        (key, _) =>
            key == path || key.startsWith('$path.') || key.startsWith('$path['),
      );
      _recalculateFlattening();
    });
  }

  void _dismissDecodeError(String path) {
    if (_decodes[path]?.error == null) return;
    setState(() {
      _decodes.remove(path);
    });
  }

  void _recalculateFlattening() {
    _flattenResult = JsonTreeFlattener.flatten(
      widget.json,
      expandedPaths: _expandedPaths,
      manuallyCollapsedPaths: _manuallyCollapsedPaths,
      searchQuery: widget.searchQuery,
      enableContextWindowing: widget.enableContextWindowing,
      contextRadius: widget.contextRadius,
      manuallyExpandedRanges: _manuallyExpandedRanges,
      forcedShowAllArrays: _forcedShowAllArrays,
      enableIndentationFlattening: widget.enableIndentationFlattening,
      hideNullFields: widget.hideNullFields,
      autoExpandSingleItemCollections: widget.autoExpandSingleItemCollections,
      decodedValues: _decodedValuesForFlattener(),
    );

    _expandedPaths.addAll(_flattenResult.expandedPaths);

    final matchCount = _flattenResult.matchNodeIndices.length;
    if (matchCount != _lastReportedMatchCount) {
      _lastReportedMatchCount = matchCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onMatchCountChanged?.call(matchCount);
        }
      });
    }
  }

  /// Programmatically scrolls the tree to center on the match at [matchIndex].
  void jumpToMatch(int matchIndex) {
    if (matchIndex >= 0 &&
        matchIndex < _flattenResult.matchNodeIndices.length) {
      final targetRowIndex = _flattenResult.matchNodeIndices[matchIndex];
      setState(() {
        _activeMatchIndex = matchIndex;
      });
      if (_itemScrollController.isAttached) {
        _itemScrollController.scrollTo(
          index: targetRowIndex,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void expandAll() {
    setState(() {
      _manuallyCollapsedPaths.clear();
      _collectAllExpandablePaths(widget.json, 'root', _expandedPaths);
      _recalculateFlattening();
    });
  }

  void collapseAll() {
    setState(() {
      _expandedPaths.clear();
      _expandedPaths.add('root');
      _manuallyCollapsedPaths.clear();
      _collectAllExpandablePaths(widget.json, 'root', _manuallyCollapsedPaths);
      _manuallyExpandedRanges.clear();
      _forcedShowAllArrays.clear();
      _recalculateFlattening();
    });
  }

  void _collectAllExpandablePaths(
    dynamic current,
    String path,
    Set<String> paths,
  ) {
    paths.add(path);
    if (current is Map) {
      for (final entry in current.entries) {
        _collectAllExpandablePaths(entry.value, '$path.${entry.key}', paths);
      }
    } else if (current is List) {
      for (int i = 0; i < current.length; i++) {
        _collectAllExpandablePaths(current[i], '$path[$i]', paths);
      }
    }
  }

  void _toggleExpand(String path) {
    setState(() {
      if (_expandedPaths.contains(path)) {
        _expandedPaths.remove(path);
        _manuallyCollapsedPaths.add(path);
      } else {
        _expandedPaths.add(path);
        _manuallyCollapsedPaths.remove(path);
      }
      _recalculateFlattening();
    });
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _flattenResult.nodes;
    if (nodes.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(child: Text(l10n?.emptyJson ?? 'Empty JSON'));
    }

    return ScrollablePositionedList.builder(
      shrinkWrap: widget.shrinkWrap,
      itemCount: nodes.length,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      itemBuilder: (context, index) {
        final node = nodes[index];
        final isFocusedMatch =
            (widget.focusedMatchIndex != null &&
                widget.focusedMatchIndex! >= 0 &&
                widget.focusedMatchIndex! <
                    _flattenResult.matchNodeIndices.length &&
                _flattenResult.matchNodeIndices[widget.focusedMatchIndex!] ==
                    index) ||
            (_activeMatchIndex >= 0 &&
                _activeMatchIndex < _flattenResult.matchNodeIndices.length &&
                _flattenResult.matchNodeIndices[_activeMatchIndex] == index);

        return _buildNodeRow(context, node, index, isFocusedMatch);
      },
    );
  }

  Widget _buildNodeRow(
    BuildContext context,
    VirtualJsonNode node,
    int rowIndex,
    bool isFocusedMatch,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (node.type == JsonNodeType.collapsedRange) {
      return _buildCollapsedRangeRow(context, node, colorScheme);
    }

    Color? backgroundColor;
    Border? border;

    if (isFocusedMatch) {
      backgroundColor = Colors.orange.withValues(alpha: 0.18);
      border = Border.all(color: Colors.orange.shade800, width: 1.5);
    } else if (node.isMatch) {
      backgroundColor = colorScheme.tertiaryContainer.withValues(alpha: 0.3);
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: _canDecodeNode(node)
          ? (details) =>
                _showDecodeContextMenu(context, details.globalPosition, node)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: border,
          borderRadius: isFocusedMatch ? BorderRadius.circular(4) : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Indentation guides
            if (node.depth > 0)
              SizedBox(
                width: node.depth * 16.0,
                height: 22,
                child: CustomPaint(
                  painter: _IndentationGuidePainter(
                    depth: node.depth,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),

            // Active match indicator icon
            if (isFocusedMatch)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Text('🎯', style: const TextStyle(fontSize: 12)),
              ),

            // Expand / Collapse chevron
            if (node.hasChildren)
              IconButton(
                icon: Icon(
                  node.isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                tooltip: node.isExpanded
                    ? (AppLocalizations.of(context)?.collapseTooltip ??
                          'Collapse')
                    : (AppLocalizations.of(context)?.expandTooltip ?? 'Expand'),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                visualDensity: VisualDensity.compact,
                onPressed: () => _toggleExpand(node.path),
              )
            else
              const SizedBox(width: 24),

            // Key name or compound breadcrumb key
            if (node.key.isNotEmpty) ...[
              InkWell(
                onTap: node.hasChildren ? () => _toggleExpand(node.path) : null,
                child: _buildKeyWidget(node, colorScheme),
              ),
              const SizedBox(width: 4),
            ],

            // Value content
            Expanded(child: _buildNodeValue(context, node, colorScheme)),

            // Inline decode status (pending spinner, active chip, or error)
            ..._buildDecodeStatusChips(context, node, colorScheme),

            // Decode as… menu for string/binary rows
            if (_canDecodeNode(node))
              _buildDecodeButton(context, node, colorScheme),

            // Quick copy action on row
            IconButton(
              icon: const Icon(Icons.copy, size: 13),
              tooltip:
                  (node.type == JsonNodeType.binary && node.value is Uint8List)
                  ? (AppLocalizations.of(context)?.copyAsHex ?? 'Copy as hex')
                  : (AppLocalizations.of(context)?.copyValueTooltip ??
                        'Copy value'),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                final valStr =
                    (node.type == JsonNodeType.binary &&
                        node.value is Uint8List)
                    ? formatHexBytes(node.value as Uint8List)
                    : copyableNodeText(node.value);
                Clipboard.setData(ClipboardData(text: valStr));
                final l10n = AppLocalizations.of(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n?.valueCopiedToClipboard ??
                          'Value copied to clipboard',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            if (!node.insideDecoded &&
                widget.onPinToColumn != null &&
                node.path.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.push_pin_outlined, size: 14),
                tooltip: (widget.onFilterByField != null)
                    ? (AppLocalizations.of(context)?.schemaPinAsColumnTooltip ??
                          'Pin as table column')
                    : (AppLocalizations.of(context)?.pinAsColumn ??
                          'Pin as Column'),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final normalized = normalizeSchemaFieldPath(node.path);
                  if (normalized.isNotEmpty) {
                    widget.onPinToColumn!(normalized);
                  }
                },
              ),
            if (!node.insideDecoded &&
                widget.onFilterByField != null &&
                node.path.isNotEmpty)
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return IconButton(
                    icon: const Icon(Icons.filter_alt_outlined, size: 14),
                    tooltip:
                        l10n?.schemaFilterByFieldTooltip ??
                        'Filter by this field',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final normalized = normalizeSchemaFieldPath(node.path);
                      if (normalized.isNotEmpty) {
                        widget.onFilterByField!(normalized);
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyWidget(VirtualJsonNode node, ColorScheme colorScheme) {
    if (node.compoundPathKey != null) {
      final parts = node.key.split(' . ');
      final spans = <InlineSpan>[];
      for (int i = 0; i < parts.length; i++) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: AppFonts.robotoMono(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );
        if (i < parts.length - 1) {
          spans.add(
            TextSpan(
              text: ' › ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.outline,
              ),
            ),
          );
        }
      }
      return Text.rich(
        TextSpan(children: spans),
        overflow: TextOverflow.ellipsis,
      );
    }

    return _buildHighlightedText(
      '${node.key}: ',
      AppFonts.robotoMono(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurfaceVariant,
      ),
      colorScheme,
    );
  }

  Widget _buildCollapsedRangeRow(
    BuildContext context,
    VirtualJsonNode node,
    ColorScheme colorScheme,
  ) {
    final l10n = AppLocalizations.of(context);
    final count = node.collapsedCount ?? 0;
    final start = node.collapsedRangeStart ?? 0;
    final end = node.collapsedRangeEnd ?? 0;
    final text =
        l10n?.collapsedRangeLabel(count, start, end) ??
        '… $count hidden items (Index $start to $end)';

    return Container(
      padding: EdgeInsets.only(
        left: (node.depth * 16.0) + 8.0,
        right: 8.0,
        top: 2.0,
        bottom: 2.0,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _manuallyExpandedRanges.add(node.path);
                _recalculateFlattening();
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.more_horiz, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeValue(
    BuildContext context,
    VirtualJsonNode node,
    ColorScheme colorScheme,
  ) {
    switch (node.type) {
      case JsonNodeType.collapsedRange:
        return const SizedBox.shrink();

      case JsonNodeType.compositeBadge:
        return Align(
          alignment: Alignment.centerLeft,
          child: SmartCompositeBadge(
            keyName: '',
            data: node.value,
            badgeInfo: node.badgeData!,
          ),
        );

      case JsonNodeType.object:
        return Text(
          '{ ${node.childCount} ${node.childCount == 1 ? "key" : "keys"} }',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.outline,
            fontFamily: 'monospace',
          ),
        );

      case JsonNodeType.array:
        final list = node.value is List ? node.value as List : const [];
        final hasSearch =
            widget.searchQuery != null && widget.searchQuery!.trim().isNotEmpty;
        final isForcedShowAll = _forcedShowAllArrays.contains(node.path);
        int arrayMatchCount = 0;
        if (hasSearch && widget.enableContextWindowing) {
          final query = widget.searchQuery!.trim().toLowerCase();
          for (final item in list) {
            if (JsonTreeFlattener.hasMatchInSubtree(item, query)) {
              arrayMatchCount++;
            }
          }
        }

        final l10n = AppLocalizations.of(context);
        final baseCountText =
            '[ ${node.childCount} ${node.childCount == 1 ? "item" : "items"} ]';

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                baseCountText,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.outline,
                  fontFamily: 'monospace',
                ),
              ),
              if (hasSearch &&
                  arrayMatchCount > 0 &&
                  widget.enableContextWindowing) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n?.matchesContextBadge(arrayMatchCount) ??
                        '$arrayMatchCount matches (Focus: ±1)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.brown.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isForcedShowAll) {
                        _forcedShowAllArrays.remove(node.path);
                      } else {
                        _forcedShowAllArrays.add(node.path);
                      }
                      _recalculateFlattening();
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      isForcedShowAll
                          ? (l10n?.reduceToMatchContext ?? 'Focus matches (±1)')
                          : (l10n?.showAllArrayItems(node.childCount) ??
                                'Show all ${node.childCount}'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );

      case JsonNodeType.primitive:
        return _buildPrimitiveNode(context, node, colorScheme);

      case JsonNodeType.binary:
        return _buildBinaryNode(context, node, colorScheme);
    }
  }

  static final RegExp _iso8601Regex = RegExp(
    r'^\d{4}-\d{2}-\d{2}(?:[T\s]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:?\d{2})?)?$',
  );

  Widget _buildPrimitiveNode(
    BuildContext context,
    VirtualJsonNode node,
    ColorScheme colorScheme,
  ) {
    final value = node.value;

    // Check for datetime string pattern
    if (value is String &&
        value.length >= 10 &&
        _iso8601Regex.hasMatch(value)) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return _buildSmartTimestampWidget(context, value, parsed, colorScheme);
      }
    }

    final epoch = guessEpoch(value);
    if (epoch != null) {
      return _buildEpochTooltipWidget(context, value, epoch, colorScheme);
    }

    return _buildPrimitiveText(value, colorScheme);
  }

  Widget _buildBinaryNode(
    BuildContext context,
    VirtualJsonNode node,
    ColorScheme colorScheme,
  ) {
    final l10n = AppLocalizations.of(context);
    final bytes = node.value is Uint8List
        ? node.value as Uint8List
        : Uint8List(0);
    final summary =
        l10n?.binaryBytesSummary(bytes.length) ?? '${bytes.length} bytes';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.memory, size: 13, color: colorScheme.secondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            summary,
            style: AppFonts.robotoMono(
              fontSize: 12,
              color: colorScheme.secondary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEpochTooltipWidget(
    BuildContext context,
    dynamic value,
    EpochGuess epoch,
    ColorScheme colorScheme,
  ) {
    final l10n = AppLocalizations.of(context);
    final localFormatted = DateFormatUtils.formatDateTime(
      context,
      epoch.utc.toLocal(),
    );
    final utcFormatted = epoch.utc.toUtc().toIso8601String();
    final localLabel = l10n?.localTimestampLabel ?? 'Local';
    final utcLabel = l10n?.utcTimestampLabel ?? 'UTC';
    final unitLabel = switch (epoch.unit) {
      EpochUnit.seconds => l10n?.epochUnitSeconds ?? 'seconds',
      EpochUnit.milliseconds => l10n?.epochUnitMilliseconds ?? 'milliseconds',
      EpochUnit.microseconds => l10n?.epochUnitMicroseconds ?? 'microseconds',
      EpochUnit.nanoseconds => l10n?.epochUnitNanoseconds ?? 'nanoseconds',
    };
    final isUtc = _timeDisplaySettings.value == TimeDisplayMode.utc;
    final primary = isUtc
        ? '$utcLabel: $utcFormatted'
        : '$localLabel: $localFormatted';
    final secondary = isUtc
        ? '$localLabel: $localFormatted'
        : '$utcLabel: $utcFormatted';
    final message =
        l10n?.epochTooltip(primary, secondary, unitLabel) ??
        '$primary\n$secondary\nAssumed unit: $unitLabel';

    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 300),
      child: _buildPrimitiveText(value, colorScheme),
    );
  }

  bool _canDecodeNode(VirtualJsonNode node) {
    if (node.type == JsonNodeType.binary && node.value is Uint8List) {
      return true;
    }
    return node.type == JsonNodeType.primitive && node.value is String;
  }

  Object? _decodeInputForNode(VirtualJsonNode node) {
    if (node.value is Uint8List) return node.value as Uint8List;
    if (node.value is String) return node.value as String;
    return null;
  }

  List<PopupMenuEntry<String>> _buildDecodeMenuEntries(
    BuildContext context,
    VirtualJsonNode node,
  ) {
    final l10n = AppLocalizations.of(context);
    return [
      PopupMenuItem<String>(
        value: 'json',
        child: Text(l10n?.decodeAsJson ?? 'JSON'),
      ),
      PopupMenuItem<String>(
        value: 'base64',
        child: Text(l10n?.decodeAsBase64 ?? 'Base64'),
      ),
      PopupMenuItem<String>(
        value: 'gzip',
        child: Text(l10n?.decodeAsGzip ?? 'Gzip'),
      ),
      if (node.decodedKind != null) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'clear',
          child: Text(l10n?.showOriginalOnly ?? 'Show original only'),
        ),
      ],
    ];
  }

  void _handleDecodeMenuSelection(VirtualJsonNode node, String selection) {
    if (selection == 'clear') {
      _clearDecode(node.path);
      return;
    }
    final input = _decodeInputForNode(node);
    if (input == null) return;
    final kind = switch (selection) {
      'json' => DecodeKind.json,
      'base64' => DecodeKind.base64,
      'gzip' => DecodeKind.gzip,
      _ => null,
    };
    if (kind != null) {
      _triggerDecode(node.path, input, kind);
    }
  }

  Future<void> _showDecodeContextMenu(
    BuildContext context,
    Offset globalPosition,
    VirtualJsonNode node,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: _buildDecodeMenuEntries(context, node),
    );
    if (selection != null && mounted) {
      _handleDecodeMenuSelection(node, selection);
    }
  }

  Widget _buildDecodeButton(
    BuildContext context,
    VirtualJsonNode node,
    ColorScheme colorScheme,
  ) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: l10n?.decodeAs ?? 'Decode as…',
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.transform,
        size: 14,
        color: node.decodedKind != null
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
      ),
      itemBuilder: (ctx) => _buildDecodeMenuEntries(ctx, node),
      onSelected: (selection) => _handleDecodeMenuSelection(node, selection),
    );
  }

  List<Widget> _buildDecodeStatusChips(
    BuildContext context,
    VirtualJsonNode node,
    ColorScheme colorScheme,
  ) {
    final l10n = AppLocalizations.of(context);
    final decodeState = _decodes[node.path];
    final widgets = <Widget>[];

    if (decodeState?.pending == true) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    } else if (decodeState?.error != null) {
      final msg = decodeErrorMessage(l10n, decodeState!.error!);
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _dismissDecodeError(node.path),
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (node.decodedKind != null) {
      final label = decodeKindLabel(l10n, node.decodedKind!);
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _clearDecode(node.path),
                  child: Tooltip(
                    message: l10n?.showOriginalOnly ?? 'Show original only',
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildSmartTimestampWidget(
    BuildContext context,
    String rawValue,
    DateTime parsedDate,
    ColorScheme colorScheme,
  ) {
    final l10n = AppLocalizations.of(context);
    final localFormatted = DateFormatUtils.formatDateTime(
      context,
      parsedDate.toLocal(),
    );
    final utcFormatted = parsedDate.toUtc().toIso8601String();
    final rawLabel = l10n?.rawTimestampLabel ?? 'Raw';
    final localLabel = l10n?.localTimestampLabel ?? 'Local';
    final utcLabel = l10n?.utcTimestampLabel ?? 'UTC';

    final tooltipMessage =
        '$localLabel: $localFormatted\n$utcLabel: $utcFormatted\n$rawLabel: $rawValue';

    return Tooltip(
      message: tooltipMessage,
      waitDuration: const Duration(milliseconds: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 13, color: Colors.amber.shade800),
          const SizedBox(width: 4),
          Flexible(
            child: _buildHighlightedText(
              localFormatted,
              AppFonts.robotoMono(
                fontSize: 13,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              colorScheme,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(${parsedDate.timeZoneOffset.isNegative ? '-' : '+'}${parsedDate.timeZoneOffset.inHours.abs().toString().padLeft(2, '0')}:00)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.outline,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimitiveText(dynamic value, ColorScheme colorScheme) {
    Color valueColor;
    FontWeight fontWeight = FontWeight.normal;
    FontStyle fontStyle = FontStyle.normal;
    String displayStr;

    if (value is String) {
      valueColor = colorScheme.primary;
      displayStr = '"$value"';
    } else if (value is num) {
      valueColor = Colors.teal;
      fontWeight = FontWeight.w600;
      displayStr = value.toString();
    } else if (value is bool) {
      valueColor = Colors.deepOrange;
      fontWeight = FontWeight.w600;
      displayStr = value.toString();
    } else if (value == null) {
      valueColor = colorScheme.outline;
      fontStyle = FontStyle.italic;
      displayStr = 'null';
    } else {
      valueColor = colorScheme.onSurface;
      displayStr = value.toString();
    }

    return _buildHighlightedText(
      displayStr,
      AppFonts.robotoMono(
        fontSize: 13,
        color: valueColor,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
      ),
      colorScheme,
    );
  }

  Widget _buildHighlightedText(
    String text,
    TextStyle baseStyle,
    ColorScheme colorScheme,
  ) {
    final query = widget.searchQuery?.trim();
    if (query == null || query.isEmpty) {
      return Text(text, style: baseStyle, overflow: TextOverflow.ellipsis);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    if (!lowerText.contains(lowerQuery)) {
      return Text(text, style: baseStyle, overflow: TextOverflow.ellipsis);
    }

    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        }
        break;
      }

      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }

      final matchText = text.substring(index, index + query.length);
      spans.add(
        TextSpan(
          text: matchText,
          style: baseStyle.copyWith(
            backgroundColor: colorScheme.tertiaryContainer,
            color: colorScheme.onTertiaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Converts internal tree node hierarchy paths (e.g. `root.leistungen[0].transportId`)
  /// into normalized standard JSON paths (e.g. `leistungen[0].transportId`).
  static String normalizeTreePath(String path) {
    var p = path.trim();
    if (p.startsWith('root.')) {
      p = p.substring(5);
    } else if (p == 'root') {
      p = '';
    }
    return p;
  }
}

class _IndentationGuidePainter extends CustomPainter {
  final int depth;
  final Color color;

  const _IndentationGuidePainter({required this.depth, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    for (int i = 0; i < depth; i++) {
      final x = (i * 16.0) + 8.0;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IndentationGuidePainter oldDelegate) {
    return oldDelegate.depth != depth || oldDelegate.color != color;
  }
}

class _NodeDecodeState {
  final DecodeKind kind;
  final bool pending;
  final DecodeResult? result;
  final DecodeError? error;

  const _NodeDecodeState._({
    required this.kind,
    this.pending = false,
    this.result,
    this.error,
  });

  factory _NodeDecodeState.pending(DecodeKind kind) =>
      _NodeDecodeState._(kind: kind, pending: true);

  factory _NodeDecodeState.done(DecodeKind kind, DecodeResult result) =>
      _NodeDecodeState._(kind: kind, result: result);

  factory _NodeDecodeState.error(DecodeKind kind, DecodeError error) =>
      _NodeDecodeState._(kind: kind, error: error);
}
