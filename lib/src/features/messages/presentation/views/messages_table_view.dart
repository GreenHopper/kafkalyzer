import 'dart:collection';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/messages/domain/message_reference.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/messages/presentation/incremental_sorted_merge.dart';
import 'package:kafkalyzer/src/features/messages/presentation/message_sort_utils.dart';
import 'package:kafkalyzer/src/features/messages/presentation/models/projected_column.dart';
import 'package:kafkalyzer/src/features/messages/presentation/models/table_column_config.dart';
import 'package:kafkalyzer/src/rust/api/json_path.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/features/messages/domain/script_result_message.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/ui/color_utils.dart';
import 'package:kafkalyzer/src/ui/highlight_text_utils.dart';
import 'package:kafkalyzer/src/ui/text_preview_utils.dart';
import 'package:kafkalyzer/src/utils/app_fonts.dart';

class _TableRowData {
  final KafkaMessage message;
  final String dateStr;
  final String stepStr;
  final String contentPreview;
  final String keyString;
  final Map<String, String> projectedValues;
  int filterRevision = -1;
  bool filterPassed = true;

  _TableRowData({
    required this.message,
    required this.dateStr,
    required this.stepStr,
    required this.contentPreview,
    required this.keyString,
    required this.projectedValues,
  });
}

/// Descriptor for an active visible column in the table.
class _ActiveColumnInfo {
  final String id;
  final String title;
  final bool isProjected;
  final ProjectedColumn? projectedColumn;
  final int
  logicalIndex; // 0: Timestamp, 1: Partition, 2: Offset, 3: Key, 4: Content, 5: Topic, 6: Step, or 100+ for projected

  _ActiveColumnInfo({
    required this.id,
    required this.title,
    required this.isProjected,
    this.projectedColumn,
    required this.logicalIndex,
  });
}

class MessagesTableView extends StatefulWidget {
  final List<KafkaMessage> messages;
  final bool showTopic;
  final bool showStep;
  final String? searchPhrase;
  final bool showNonMatches;
  final Function(KafkaMessage)? onMessageTap;
  final KafkaMessage? selectedMessage;
  final List<ProjectedColumn> projectedColumns;
  final ValueChanged<ProjectedColumn>? onRemoveProjectedColumn;
  final TableColumnConfig columnConfig;
  final void Function(String columnId, double width)? onColumnWidthChanged;
  final void Function(String columnId)? onToggleColumnVisibility;
  final ValueChanged<List<KafkaMessage>>? onVisualOrderChanged;
  final ClusterProfile? clusterProfile;
  final bool showFollowControl;
  final Object? followResetToken;
  final String inputSortField;
  final bool inputSortAscending;
  @visibleForTesting
  final void Function(KafkaMessage message)? onRowBuilt;
  @visibleForTesting
  final void Function(KafkaMessage message)? onColumnFilterEvaluated;

  const MessagesTableView({
    super.key,
    required this.messages,
    this.showTopic = false,
    this.showStep = false,
    this.searchPhrase,
    this.showNonMatches = false,
    this.onMessageTap,
    this.selectedMessage,
    this.projectedColumns = const [],
    this.onRemoveProjectedColumn,
    this.columnConfig = const TableColumnConfig(),
    this.onColumnWidthChanged,
    this.onToggleColumnVisibility,
    this.onVisualOrderChanged,
    this.clusterProfile,
    this.showFollowControl = false,
    this.followResetToken,
    this.inputSortField = 'timestamp',
    this.inputSortAscending = false,
    this.onRowBuilt,
    this.onColumnFilterEvaluated,
  });

  @override
  State<MessagesTableView> createState() => _MessagesTableViewState();
}

class _MessagesTableViewState extends State<MessagesTableView> {
  // Sort and Filter State
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final Map<int, String> _columnFilters = {};

  // Cache the generated rows to avoid quadratic rebuilding
  List<_TableRowData> _cachedData = [];
  bool _needsRebuildRows = true;
  Expando<_TableRowData> _rowCache = Expando<_TableRowData>('tableRowData');
  int _filterRevision = 0;
  bool _forceFullSort = false;
  Locale? _lastLocale;

  // Projected values come from one batched resolver call per message batch.
  final Map<KafkaMessage, Map<String, String>> _projectedValues =
      Map<KafkaMessage, Map<String, String>>.identity();
  bool _projectionDirty = false;
  bool _projectionInFlight = false;

  List<ProjectedColumn> get _activeProjected =>
      widget.projectedColumns.isNotEmpty
      ? widget.projectedColumns
      : widget.columnConfig.projectedColumns;

  // Local interactive column widths for smooth live-dragging
  final Map<String, double> _liveColumnWidths = {};

  final ScrollController _verticalScrollController = ScrollController();

  late bool _followNewest;
  bool _programmaticScroll = false;
  KafkaMessage? _pendingAnchorMessage;
  int _pendingAnchorOldIndex = -1;

  bool get _isTimestampOrder =>
      (_sortColumnIndex == null && widget.inputSortField == 'timestamp') ||
      _sortColumnIndex == 0;

  bool get _effectiveSortAscending =>
      _sortColumnIndex == 0 ? _sortAscending : widget.inputSortAscending;

  void _runProgrammaticScroll(VoidCallback action) {
    _programmaticScroll = true;
    try {
      action();
    } finally {
      _programmaticScroll = false;
    }
  }

  void _scheduleJumpToNewest() {
    if (!_followNewest || !_isTimestampOrder) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_verticalScrollController.hasClients) return;
      if (!_followNewest || !_isTimestampOrder) return;
      final target = _effectiveSortAscending
          ? _verticalScrollController.position.maxScrollExtent
          : 0.0;
      if ((_verticalScrollController.offset - target).abs() > 0.5) {
        _runProgrammaticScroll(() {
          _verticalScrollController.jumpTo(target);
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _followNewest = widget.showFollowControl;
    _projectionDirty = _activeProjected.isNotEmpty;
    _syncLiveWidths();
    _scrollToSelectedMessage(animate: false);
    if (_followNewest && _isTimestampOrder && _effectiveSortAscending) {
      _scheduleJumpToNewest();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.maybeLocaleOf(context);
    if (locale != _lastLocale) {
      _lastLocale = locale;
      _rowCache = Expando<_TableRowData>('tableRowData');
      _forceFullSort = true;
      _needsRebuildRows = true;
    }
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _syncLiveWidths() {
    _liveColumnWidths.clear();
    for (final entry in widget.columnConfig.columnWidths.entries) {
      _liveColumnWidths[entry.key] = entry.value;
    }
  }

  bool _projectedColumnsEqual(
    List<ProjectedColumn> a,
    List<ProjectedColumn> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].path != b[i].path || a[i].label != b[i].label) return false;
    }
    return true;
  }

  void _pruneProjectedValues(List<KafkaMessage> messages) {
    if (_projectedValues.isEmpty) return;
    final currentSet = HashSet<KafkaMessage>.identity()..addAll(messages);
    _projectedValues.removeWhere((msg, _) => !currentSet.contains(msg));
  }

  bool _hasUnresolvedProjected(List<KafkaMessage> messages) {
    for (final msg in messages) {
      if (!_projectedValues.containsKey(msg)) return true;
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant MessagesTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldProjected = oldWidget.projectedColumns.isNotEmpty
        ? oldWidget.projectedColumns
        : oldWidget.columnConfig.projectedColumns;
    final projectedChanged = !_projectedColumnsEqual(
      oldProjected,
      _activeProjected,
    );
    final rowFormatChanged =
        widget.showTopic != oldWidget.showTopic ||
        widget.showStep != oldWidget.showStep ||
        projectedChanged;

    if (projectedChanged) {
      _projectedValues.clear();
    } else if (widget.messages != oldWidget.messages) {
      _pruneProjectedValues(widget.messages);
    }

    if (rowFormatChanged) {
      _rowCache = Expando<_TableRowData>('tableRowData');
      _forceFullSort = true;
    }

    if (widget.followResetToken != oldWidget.followResetToken) {
      _followNewest = true;
      _scheduleJumpToNewest();
    }

    if (widget.messages != oldWidget.messages &&
        widget.showFollowControl &&
        !(_followNewest && _isTimestampOrder) &&
        _verticalScrollController.hasClients &&
        _cachedData.isNotEmpty &&
        _verticalScrollController.offset > 0) {
      final firstVisible = ((_verticalScrollController.offset - 40.0) / 44.0)
          .floor()
          .clamp(0, _cachedData.length - 1);
      _pendingAnchorMessage = _cachedData[firstVisible].message;
      _pendingAnchorOldIndex = firstVisible;
    }

    if (widget.messages != oldWidget.messages ||
        widget.searchPhrase != oldWidget.searchPhrase ||
        widget.showTopic != oldWidget.showTopic ||
        widget.showStep != oldWidget.showStep ||
        widget.showNonMatches != oldWidget.showNonMatches ||
        projectedChanged) {
      _needsRebuildRows = true;
      _projectionDirty =
          _activeProjected.isNotEmpty &&
          _hasUnresolvedProjected(widget.messages);
    }

    if (_followNewest &&
        _isTimestampOrder &&
        (widget.messages != oldWidget.messages ||
            widget.inputSortAscending != oldWidget.inputSortAscending ||
            widget.inputSortField != oldWidget.inputSortField)) {
      _scheduleJumpToNewest();
    }

    if (widget.columnConfig.columnWidths !=
        oldWidget.columnConfig.columnWidths) {
      _syncLiveWidths();
    }

    if (widget.selectedMessage != oldWidget.selectedMessage) {
      _scrollToSelectedMessage();
    }
  }

  void _scrollToSelectedMessage({bool animate = true}) {
    if (widget.selectedMessage == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_verticalScrollController.hasClients) return;
      if (_needsRebuildRows) {
        _cachedData = _filterAndSortMessages(widget.messages);
        _needsRebuildRows = false;
      }
      final dataIndex = _cachedData.indexWhere(
        (d) => d.message == widget.selectedMessage,
      );
      if (dataIndex < 0) return;

      // Header height is 40.0, row height is 44.0
      final rowTop = 40.0 + dataIndex * 44.0;
      final rowBottom = rowTop + 44.0;

      final currentOffset = _verticalScrollController.offset;
      final viewportHeight =
          _verticalScrollController.position.viewportDimension;
      if (viewportHeight <= 0) return;

      double? targetOffset;
      if (rowTop < currentOffset) {
        targetOffset = (rowTop - 20.0).clamp(
          0.0,
          _verticalScrollController.position.maxScrollExtent,
        );
      } else if (rowBottom > currentOffset + viewportHeight) {
        targetOffset = (rowBottom - viewportHeight + 20.0).clamp(
          0.0,
          _verticalScrollController.position.maxScrollExtent,
        );
      }

      if (targetOffset != null && (targetOffset - currentOffset).abs() > 1.0) {
        if (animate) {
          _programmaticScroll = true;
          _verticalScrollController
              .animateTo(
                targetOffset,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
              )
              .whenComplete(() {
                if (mounted) _programmaticScroll = false;
              });
        } else {
          _runProgrammaticScroll(() {
            _verticalScrollController.jumpTo(targetOffset!);
          });
        }
      }
    });
  }

  /// Calculates the active visible column list in current display order.
  List<_ActiveColumnInfo> _buildActiveColumns() {
    final l10n = AppLocalizations.of(context);
    final List<_ActiveColumnInfo> list = [];
    final hidden = widget.columnConfig.hiddenColumns;

    // 1. Timestamp
    if (!hidden.contains(StandardTableColumns.timestamp)) {
      list.add(
        _ActiveColumnInfo(
          id: StandardTableColumns.timestamp,
          title: l10n?.timestamp ?? 'Timestamp',
          isProjected: false,
          logicalIndex: 0,
        ),
      );
    }

    // 2. Step (if enabled)
    if (widget.showStep && !hidden.contains(StandardTableColumns.step)) {
      list.add(
        _ActiveColumnInfo(
          id: StandardTableColumns.step,
          title: l10n?.step ?? 'Step',
          isProjected: false,
          logicalIndex: 6,
        ),
      );
    }

    // 3. Topic (if enabled)
    if (widget.showTopic && !hidden.contains(StandardTableColumns.topic)) {
      list.add(
        _ActiveColumnInfo(
          id: StandardTableColumns.topic,
          title: l10n?.topic ?? 'Topic',
          isProjected: false,
          logicalIndex: 5,
        ),
      );
    }

    // 4. Partition
    if (!hidden.contains(StandardTableColumns.partition)) {
      list.add(
        _ActiveColumnInfo(
          id: StandardTableColumns.partition,
          title: l10n?.partitionCol ?? 'Partition',
          isProjected: false,
          logicalIndex: 1,
        ),
      );
    }

    // 5. Offset
    if (!hidden.contains(StandardTableColumns.offset)) {
      list.add(
        _ActiveColumnInfo(
          id: StandardTableColumns.offset,
          title: l10n?.offset ?? 'Offset',
          isProjected: false,
          logicalIndex: 2,
        ),
      );
    }

    // 6. Key
    if (!hidden.contains(StandardTableColumns.key)) {
      list.add(
        _ActiveColumnInfo(
          id: StandardTableColumns.key,
          title: l10n?.key ?? 'Key',
          isProjected: false,
          logicalIndex: 3,
        ),
      );
    }

    // 7. Projected columns
    final activeProjected = _activeProjected;

    for (int i = 0; i < activeProjected.length; i++) {
      final col = activeProjected[i];
      if (!hidden.contains(col.path)) {
        list.add(
          _ActiveColumnInfo(
            id: col.path,
            title: col.label,
            isProjected: true,
            projectedColumn: col,
            logicalIndex: 100 + i,
          ),
        );
      }
    }

    // 8. Content
    if (!hidden.contains(StandardTableColumns.content)) {
      list.add(
        _ActiveColumnInfo(
          id: StandardTableColumns.content,
          title: l10n?.content ?? 'Content',
          isProjected: false,
          logicalIndex: 4,
        ),
      );
    }

    // Fallback: If everything was hidden, keep at least Timestamp or Content
    if (list.isEmpty) {
      list.add(
        _ActiveColumnInfo(
          id: StandardTableColumns.content,
          title: l10n?.content ?? 'Content',
          isProjected: false,
          logicalIndex: 4,
        ),
      );
    }

    return list;
  }

  double _getColumnWidth(String columnId, {double? fallback}) {
    if (_liveColumnWidths.containsKey(columnId)) {
      return _liveColumnWidths[columnId]!.clamp(
        StandardTableColumns.minColumnWidth,
        StandardTableColumns.maxColumnWidth,
      );
    }
    return widget.columnConfig.getWidth(columnId, fallback: fallback);
  }

  /// Resolve every unresolved projected path in a single bridge call.
  Future<void> _resolveProjectedValues() async {
    final columns = _activeProjected;
    final messages = widget.messages;
    if (columns.isEmpty) {
      _projectionDirty = false;
      return;
    }

    final unresolved = <KafkaMessage>[
      for (final message in messages)
        if (!_projectedValues.containsKey(message)) message,
    ];

    if (unresolved.isNotEmpty) {
      final paths = columns.map((column) => column.path).toList();
      final payloads = unresolved
          .map((message) => message.payload ?? '')
          .toList();
      final values = await resolveJsonPathBatch(
        payloads: payloads,
        paths: paths,
      );
      if (!mounted) return;

      for (var i = 0; i < unresolved.length; i++) {
        final msg = unresolved[i];
        final perMessage = <String, String>{};
        for (var p = 0; p < paths.length; p++) {
          perMessage[paths[p]] = values[i * paths.length + p] ?? '';
        }
        _projectedValues[msg] = perMessage;
        _rowCache[msg] = null;
      }
    }

    _pruneProjectedValues(widget.messages);
    _projectionDirty =
        _activeProjected.isNotEmpty && _hasUnresolvedProjected(widget.messages);
    setState(_rebuildRows);
  }

  void _rebuildRows() {
    _cachedData = _filterAndSortMessages(widget.messages);
    _needsRebuildRows = false;
    if (_pendingAnchorMessage != null) {
      final anchor = _pendingAnchorMessage!;
      final oldIdx = _pendingAnchorOldIndex;
      _pendingAnchorMessage = null;
      _pendingAnchorOldIndex = -1;
      if (_verticalScrollController.hasClients) {
        final newIdx = _cachedData.indexWhere(
          (d) => identical(d.message, anchor),
        );
        if (newIdx >= 0 && newIdx != oldIdx) {
          final delta = (newIdx - oldIdx) * 44.0;
          final pos = _verticalScrollController.position;
          final target = (pos.pixels + delta).clamp(0.0, double.infinity);
          _runProgrammaticScroll(() {
            pos.correctBy(target - pos.pixels);
          });
        }
      }
    }
    final visualOrder = _cachedData.map((e) => e.message).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onVisualOrderChanged?.call(visualOrder);
      }
    });
  }

  bool _matchesColumnFilters(
    _TableRowData data,
    List<ProjectedColumn> activeProjected,
  ) {
    final hasAnyFilter = _columnFilters.values.any((v) => v.isNotEmpty);
    if (!hasAnyFilter) return true;
    widget.onColumnFilterEvaluated?.call(data.message);
    for (var entry in _columnFilters.entries) {
      final filter = entry.value.toLowerCase();
      if (filter.isEmpty) continue;
      String val = "";
      switch (entry.key) {
        case 0: // Timestamp
          val = data.dateStr;
          break;
        case 1: // Partition
          val = data.message.partition.toString();
          break;
        case 2: // Offset
          val = data.message.offset.toString();
          break;
        case 3: // Key
          val = data.keyString;
          break;
        case 4: // Content
          val = data.message.payload ?? '';
          break;
        case 5: // Topic
          val = data.message.topic;
          break;
        case 6: // Step
          val = data.stepStr;
          break;
        default:
          if (entry.key >= 100) {
            final projIndex = entry.key - 100;
            if (projIndex >= 0 && projIndex < activeProjected.length) {
              final col = activeProjected[projIndex];
              val = data.projectedValues[col.path] ?? "";
            }
          }
          break;
      }
      if (!val.toLowerCase().contains(filter)) return false;
    }
    return true;
  }

  int _compareRows(
    _TableRowData a,
    _TableRowData b,
    List<ProjectedColumn> activeProjected,
  ) {
    dynamic valA;
    dynamic valB;

    switch (_sortColumnIndex) {
      case 0: // Timestamp
        valA = a.message.timestamp;
        valB = b.message.timestamp;
        break;
      case 1: // Partition
        valA = a.message.partition;
        valB = b.message.partition;
        break;
      case 2: // Offset
        valA = a.message.offset;
        valB = b.message.offset;
        break;
      case 3: // Key
        valA = a.keyString;
        valB = b.keyString;
        break;
      case 4: // Content
        valA = a.contentPreview;
        valB = b.contentPreview;
        break;
      case 5: // Topic
        valA = a.message.topic;
        valB = b.message.topic;
        break;
      case 6: // Step
        valA = a.stepStr;
        valB = b.stepStr;
        break;
      default:
        if (_sortColumnIndex! >= 100) {
          final projIndex = _sortColumnIndex! - 100;
          if (projIndex >= 0 && projIndex < activeProjected.length) {
            final col = activeProjected[projIndex];
            valA = a.projectedValues[col.path] ?? "";
            valB = b.projectedValues[col.path] ?? "";
          }
        }
        break;
    }

    int cmp = 0;
    if (valA is Comparable && valB is Comparable) {
      try {
        cmp = valA.compareTo(valB);
      } catch (e) {
        cmp = valA.toString().compareTo(valB.toString());
      }
    } else {
      cmp = valA.toString().compareTo(valB.toString());
    }

    if (cmp == 0) {
      return compareMessageIdentity(a.message, b.message);
    }
    return _sortAscending ? cmp : -cmp;
  }

  List<_TableRowData> _filterAndSortMessages(List<KafkaMessage> messages) {
    final activeProjected = _activeProjected;
    final rows = <_TableRowData>[];

    // 1. Lookup or build cached row data + evaluate column filters only when needed
    for (final msg in messages) {
      var row = _rowCache[msg];
      if (row == null) {
        final date = DateTime.fromMillisecondsSinceEpoch(msg.timestamp.toInt());
        final dateStr = DateFormatUtils.formatDateTime(
          context,
          date,
          withMilliseconds: true,
        );
        final stepStr = msg is ScriptResultMessage ? msg.stepName : 'Global';
        final contentPreview = TextPreviewUtils.getPayloadPreview(msg.payload);
        final keyString = msg.key ?? "";
        final cachedValues = _projectedValues[msg];
        final projectedValues = <String, String>{
          for (final col in activeProjected)
            col.path: cachedValues?[col.path] ?? '',
        };

        row = _TableRowData(
          message: msg,
          dateStr: dateStr,
          stepStr: stepStr,
          contentPreview: contentPreview,
          keyString: keyString,
          projectedValues: projectedValues,
        );
        _rowCache[msg] = row;
        widget.onRowBuilt?.call(msg);
      }

      if (row.filterRevision != _filterRevision) {
        row.filterPassed = _matchesColumnFilters(row, activeProjected);
        row.filterRevision = _filterRevision;
      }

      if (row.filterPassed) {
        rows.add(row);
      }
    }

    // 2. Sort (incremental merge when column sort is active and cache is valid)
    if (_sortColumnIndex == null) {
      _forceFullSort = false;
      return rows;
    }

    int compare(_TableRowData a, _TableRowData b) =>
        _compareRows(a, b, activeProjected);

    if (_forceFullSort || _cachedData.isEmpty) {
      _forceFullSort = false;
      rows.sort(compare);
      return rows;
    }

    final inputSet = HashSet<KafkaMessage>.identity()..addAll(messages);
    final previousSet = HashSet<_TableRowData>.identity()..addAll(_cachedData);
    final added = <_TableRowData>[
      for (final row in rows)
        if (!previousSet.contains(row)) row,
    ];

    return mergeIncremental<_TableRowData>(
      _cachedData,
      retain: (row) =>
          inputSet.contains(row.message) &&
          identical(_rowCache[row.message], row) &&
          row.filterPassed,
      added: added,
      compare: compare,
    );
  }

  void _showFilterDialog(String title, int index) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: _columnFilters[index] ?? "");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n?.filterColumnTitle(title) ?? "Filter $title",
          style: const TextStyle(fontSize: 16),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText:
                l10n?.filterSubstringHint ?? "Enter substring to filter...",
            isDense: true,
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: l10n?.clear ?? 'Clear',
                    onPressed: () {
                      controller.clear();
                    },
                  )
                : null,
          ),
          autofocus: true,
          onSubmitted: (val) {
            setState(() {
              if (val.isEmpty) {
                _columnFilters.remove(index);
              } else {
                _columnFilters[index] = val;
              }
              _filterRevision++;
              _needsRebuildRows = true;
            });
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _columnFilters.remove(index);
                _filterRevision++;
                _needsRebuildRows = true;
              });
              Navigator.pop(ctx);
            },
            child: Text(l10n?.clear ?? "Clear"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () {
              setState(() {
                if (controller.text.isEmpty) {
                  _columnFilters.remove(index);
                } else {
                  _columnFilters[index] = controller.text;
                }
                _filterRevision++;
                _needsRebuildRows = true;
              });
              Navigator.pop(ctx);
            },
            child: Text(l10n?.apply ?? "Apply"),
          ),
        ],
      ),
    );
  }

  double _measureTextWidth(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.size.width;
  }

  /// Calculates auto-fit width for a column by measuring header & sample row contents.
  void _autoFitColumn(_ActiveColumnInfo colInfo) {
    final headerStyle = const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );
    final monoStyle = AppFonts.robotoMono(fontSize: 12);

    // 1. Measure header (label + padding + sort + 24x24 filter/close icons)
    double maxWidth = _measureTextWidth(colInfo.title, headerStyle) + 104.0;

    // 2. Measure sample row cell values (sample first 100 rows for high performance)
    final sampleCount = _cachedData.length > 100 ? 100 : _cachedData.length;
    for (int i = 0; i < sampleCount; i++) {
      final row = _cachedData[i];
      String cellText = "";
      switch (colInfo.logicalIndex) {
        case 0:
          cellText = row.dateStr;
          break;
        case 1:
          cellText = row.message.partition.toString();
          break;
        case 2:
          cellText = row.message.offset.toString();
          break;
        case 3:
          cellText = row.keyString;
          break;
        case 4:
          cellText = row.contentPreview;
          break;
        case 5:
          cellText = row.message.topic;
          break;
        case 6:
          cellText = row.stepStr;
          break;
        default:
          if (colInfo.isProjected && colInfo.projectedColumn != null) {
            cellText = row.projectedValues[colInfo.projectedColumn!.path] ?? "";
          }
          break;
      }

      if (cellText.isNotEmpty) {
        final cellWidth =
            _measureTextWidth(cellText, monoStyle) +
            36.0; // horizontal padding (16*2) + margin
        if (cellWidth > maxWidth) {
          maxWidth = cellWidth;
        }
      }
    }

    final newWidth = maxWidth.clamp(
      StandardTableColumns.minColumnWidth,
      StandardTableColumns.maxColumnWidth,
    );

    setState(() {
      _liveColumnWidths[colInfo.id] = newWidth;
    });

    widget.onColumnWidthChanged?.call(colInfo.id, newWidth);
  }

  TableViewCell _buildSortableHeader(
    _ActiveColumnInfo colInfo,
    int visibleColCount,
  ) {
    final title = colInfo.title;
    final index = colInfo.logicalIndex;
    final projectedColumn = colInfo.projectedColumn;
    final bool isSorted = _sortColumnIndex == index;
    final bool isFiltered =
        _columnFilters.containsKey(index) && _columnFilters[index]!.isNotEmpty;

    return TableViewCell(
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Stack(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (_sortColumnIndex == index) {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortColumnIndex = index;
                    _sortAscending = true;
                  }
                  _forceFullSort = true;
                  _needsRebuildRows = true;
                });
              },
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Tooltip(
                        message: projectedColumn?.path ?? title,
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isFiltered
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        isFiltered ? Icons.filter_alt : Icons.filter_list,
                        size: 14,
                        color: isFiltered
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      tooltip:
                          AppLocalizations.of(
                            context,
                          )?.filterColumnTooltip(title) ??
                          'Filter $title',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _showFilterDialog(title, index),
                    ),
                    if (isSorted)
                      Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 14,
                      ),
                    // Remove or hide column icon
                    if (colInfo.isProjected &&
                        widget.onRemoveProjectedColumn != null &&
                        projectedColumn != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        tooltip:
                            AppLocalizations.of(context)?.removeColumnTooltip ??
                            'Remove column',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () =>
                            widget.onRemoveProjectedColumn!(projectedColumn),
                      ),
                    ] else if (!colInfo.isProjected &&
                        widget.onToggleColumnVisibility != null &&
                        visibleColCount > 1) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.visibility_off_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        tooltip:
                            AppLocalizations.of(context)?.hideColumn ??
                            'Hide column',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () =>
                            widget.onToggleColumnVisibility!(colInfo.id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Resize Handle at right edge
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 12,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  key: Key('resize_handle_${colInfo.id}'),
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () => _autoFitColumn(colInfo),
                  onHorizontalDragStart: (_) {},
                  onHorizontalDragUpdate: (details) {
                    final currentWidth = _getColumnWidth(colInfo.id);
                    final newWidth = (currentWidth + details.delta.dx).clamp(
                      StandardTableColumns.minColumnWidth,
                      StandardTableColumns.maxColumnWidth,
                    );
                    setState(() {
                      _liveColumnWidths[colInfo.id] = newWidth;
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    final finalWidth = _getColumnWidth(colInfo.id);
                    widget.onColumnWidthChanged?.call(colInfo.id, finalWidth);
                  },
                  child: Container(
                    width: 12,
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 2.0,
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableSpan _buildColumnSpan(
    int visualIndex,
    List<_ActiveColumnInfo> activeColumns,
  ) {
    if (visualIndex < 0 || visualIndex >= activeColumns.length) {
      return const TableSpan(extent: FixedTableSpanExtent(100));
    }
    final colInfo = activeColumns[visualIndex];
    final width = _getColumnWidth(
      colInfo.id,
      fallback: colInfo.projectedColumn?.width,
    );
    return TableSpan(extent: FixedTableSpanExtent(width));
  }

  TableSpan _buildRowSpan(int index) {
    if (index == 0) {
      return const TableSpan(extent: FixedTableSpanExtent(40)); // Header height
    }
    return const TableSpan(extent: FixedTableSpanExtent(44)); // Row height
  }

  void _showRowContextMenu(
    BuildContext context,
    Offset position,
    KafkaMessage msg,
  ) {
    final l10n = AppLocalizations.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          key: const Key('menu_copy_shareable_link'),
          value: 'copy_link',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n?.copyShareableLink ?? 'Copy Shareable Link',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'copy_link') {
        final ref = MessageReference(
          cluster: widget.clusterProfile?.name,
          topic: msg.topic,
          partition: msg.partition,
          offset: msg.offset,
          filter: widget.searchPhrase,
        );
        Clipboard.setData(ClipboardData(text: ref.toString()));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n?.shareableLinkCopied ??
                    'Shareable link copied to clipboard',
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    });
  }

  TableViewCell _buildCell(
    BuildContext context,
    TableVicinity vicinity,
    List<_ActiveColumnInfo> activeColumns,
    TextStyle monoStyle,
    TextStyle highlightStyle,
  ) {
    final int colIdx = vicinity.column;
    if (colIdx < 0 || colIdx >= activeColumns.length) {
      return TableViewCell(child: const SizedBox.shrink());
    }

    final colInfo = activeColumns[colIdx];

    // Row 0 is the Header
    if (vicinity.row == 0) {
      return _buildSortableHeader(colInfo, activeColumns.length);
    }

    // Data Row
    final dataIndex = vicinity.row - 1;
    if (dataIndex >= _cachedData.length) {
      return TableViewCell(child: const SizedBox.shrink());
    }

    final data = _cachedData[dataIndex];
    final msg = data.message;
    final dividerColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.5);

    // Search match logic
    bool isMatch = true;
    if (widget.searchPhrase != null && widget.searchPhrase!.isNotEmpty) {
      final query = widget.searchPhrase!.toLowerCase();
      final keyMatch = data.keyString.toLowerCase().contains(query);
      final payloadMatch = (msg.payload ?? "").toLowerCase().contains(query);
      final topicMatch = msg.topic.toLowerCase().contains(query);
      final stepMatch = data.stepStr.toLowerCase().contains(query);
      final projectedMatch = data.projectedValues.values.any(
        (v) => v.toLowerCase().contains(query),
      );
      isMatch =
          keyMatch || payloadMatch || topicMatch || stepMatch || projectedMatch;
    }

    final isSelected = widget.selectedMessage == msg;
    final colorScheme = Theme.of(context).colorScheme;

    final effectiveMonoStyle = isSelected
        ? monoStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onPrimaryContainer,
          )
        : monoStyle;

    Widget cellContent;
    if (!colInfo.isProjected) {
      switch (colInfo.logicalIndex) {
        case 0: // Timestamp
          cellContent = Text(
            data.dateStr,
            style: isSelected
                ? TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                  )
                : const TextStyle(fontSize: 12),
          );
          break;
        case 6: // Step
          cellContent = Text(
            data.stepStr,
            style: effectiveMonoStyle,
            overflow: TextOverflow.ellipsis,
          );
          break;
        case 5: // Topic
          cellContent = Tooltip(
            message: msg.topic,
            child: Text(
              msg.topic,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ColorUtils.getColorForString(msg.topic),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
          break;
        case 1: // Partition
          cellContent = Text(
            msg.partition.toString(),
            style: effectiveMonoStyle,
          );
          break;
        case 2: // Offset
          cellContent = Text(msg.offset.toString(), style: effectiveMonoStyle);
          break;
        case 3: // Key
          cellContent = Tooltip(
            message: data.keyString,
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: HighlightTextUtils.buildHighlightedSpans(
                  data.keyString,
                  widget.searchPhrase ?? "",
                  effectiveMonoStyle,
                  highlightStyle,
                ),
              ),
            ),
          );
          break;
        case 4: // Content
        default:
          cellContent = RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: HighlightTextUtils.buildHighlightedSpans(
                data.contentPreview,
                widget.searchPhrase ?? "",
                effectiveMonoStyle,
                highlightStyle,
              ),
            ),
          );
          break;
      }
    } else {
      // Projected column
      final path = colInfo.projectedColumn?.path ?? colInfo.id;
      final val = data.projectedValues[path] ?? '';
      cellContent = Tooltip(
        message: val,
        child: RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: HighlightTextUtils.buildHighlightedSpans(
              val.isEmpty ? '-' : val,
              widget.searchPhrase ?? "",
              effectiveMonoStyle.copyWith(
                color: val.isEmpty
                    ? (isSelected
                          ? colorScheme.outline
                          : Theme.of(context).colorScheme.outline)
                    : null,
              ),
              highlightStyle,
            ),
          ),
        ),
      );
    }

    Widget decoratedCell = Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.60
                    : 0.80,
              )
            : null,
        border: Border(
          top: isSelected
              ? BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.8),
                  width: 1.5,
                )
              : BorderSide.none,
          bottom: BorderSide(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.8)
                : dividerColor,
            width: isSelected ? 1.5 : 1.0,
          ),
          left: (isSelected && colIdx == 0)
              ? BorderSide(color: colorScheme.primary, width: 4.0)
              : BorderSide.none,
        ),
      ),
      child: cellContent,
    );

    if (widget.showNonMatches && !isMatch) {
      decoratedCell = Opacity(opacity: 0.4, child: decoratedCell);
    }

    return TableViewCell(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('message_cell_${dataIndex}_$colIdx'),
          onTap: () {
            if (widget.showFollowControl && _followNewest) {
              setState(() => _followNewest = false);
            }
            widget.onMessageTap?.call(msg);
          },
          onSecondaryTapDown: (details) {
            _showRowContextMenu(context, details.globalPosition, msg);
          },
          child: decoratedCell,
        ),
      ),
    );
  }

  Widget _buildFollowNewestToggle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = _isTimestampOrder;
    final isFollowing = enabled && _followNewest;
    final tooltip = !enabled
        ? (l10n?.followNewestDisabledTooltip ??
              'Follow newest requires timestamp order')
        : (isFollowing
              ? (l10n?.followNewestOnTooltip ??
                    'Following newest messages (click to pause following)')
              : (l10n?.followNewestOffTooltip ??
                    'Follow newest is off (click to jump to newest)'));
    final label = l10n?.followNewest ?? 'Follow newest';
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        key: const ValueKey('follow_newest_toggle'),
        toggled: isFollowing,
        enabled: enabled,
        child: OutlinedButton.icon(
          onPressed: enabled
              ? () {
                  setState(() {
                    _followNewest = !_followNewest;
                  });
                  if (_followNewest) {
                    _scheduleJumpToNewest();
                  }
                }
              : null,
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            backgroundColor: isFollowing
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
            foregroundColor: isFollowing
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            side: BorderSide(
              color: isFollowing
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : colorScheme.outlineVariant,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          icon: Icon(
            isFollowing
                ? Icons.vertical_align_bottom
                : Icons.pause_circle_outline,
            size: 16,
          ),
          label: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_needsRebuildRows) {
      if (_projectionDirty && !_projectionInFlight) {
        // Rows for this frame keep the previous values; the batched resolver
        // rebuilds them as soon as it returns.
        _projectionInFlight = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _resolveProjectedValues();
          _projectionInFlight = false;
        });
      } else {
        _rebuildRows();
      }
    }

    final activeColumns = _buildActiveColumns();

    final monoStyle = AppFonts.robotoMono(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final highlightStyle = monoStyle.copyWith(
      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
      color: Theme.of(context).colorScheme.onTertiaryContainer,
    );

    final table = TableView.builder(
      verticalDetails: ScrollableDetails.vertical(
        controller: _verticalScrollController,
      ),
      columnCount: activeColumns.length,
      rowCount: _cachedData.length + 1, // +1 for Header
      columnBuilder: (idx) => _buildColumnSpan(idx, activeColumns),
      rowBuilder: _buildRowSpan,
      cellBuilder: (context, vicinity) => _buildCell(
        context,
        vicinity,
        activeColumns,
        monoStyle,
        highlightStyle,
      ),
      diagonalDragBehavior: DiagonalDragBehavior.free,
    );

    final Widget wrappedTable = Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent &&
            widget.showFollowControl &&
            _followNewest &&
            !_programmaticScroll) {
          setState(() => _followNewest = false);
        }
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (!widget.showFollowControl ||
              !_followNewest ||
              _programmaticScroll) {
            return false;
          }
          if (notification.metrics.axis != Axis.vertical) return false;
          final isUserScroll =
              notification is UserScrollNotification &&
              notification.direction != ScrollDirection.idle;
          final isDragStart =
              notification is ScrollStartNotification &&
              notification.dragDetails != null;
          if (isUserScroll || isDragStart) {
            setState(() => _followNewest = false);
          }
          return false;
        },
        child: table,
      ),
    );

    final hasActiveColumnFilters = _columnFilters.values.any(
      (v) => v.isNotEmpty,
    );
    final showEmptyFilterOverlay =
        _cachedData.isEmpty && hasActiveColumnFilters;
    if (!showEmptyFilterOverlay && !widget.showFollowControl) {
      return wrappedTable;
    }

    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        wrappedTable,
        if (showEmptyFilterOverlay)
          Positioned(
            top: 48,
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_alt_off_outlined,
                    size: 32,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n?.columnFiltersNoMatch ??
                        'No rows match the active column filters.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _columnFilters.clear();
                        _filterRevision++;
                        _needsRebuildRows = true;
                      });
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: Text(l10n?.resetColumnFilters ?? 'Reset filters'),
                  ),
                ],
              ),
            ),
          ),
        if (widget.showFollowControl)
          Positioned(
            top: 48,
            right: 12,
            child: _buildFollowNewestToggle(context),
          ),
      ],
    );
  }
}
