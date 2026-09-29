import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/ui/messages/models/projected_column.dart';
import 'package:kafkalyzer/src/ui/messages/models/table_column_config.dart';
import 'package:kafkalyzer/src/utils/json_path_extractor.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_result_message.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/ui/color_utils.dart';
import 'package:kafkalyzer/src/ui/message_details_dialog.dart';
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

  // Local interactive column widths for smooth live-dragging
  final Map<String, double> _liveColumnWidths = {};

  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _syncLiveWidths();
    _scrollToSelectedMessage(animate: false);
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

  @override
  void didUpdateWidget(covariant MessagesTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages != oldWidget.messages ||
        widget.searchPhrase != oldWidget.searchPhrase ||
        widget.showTopic != oldWidget.showTopic ||
        widget.showStep != oldWidget.showStep ||
        widget.showNonMatches != oldWidget.showNonMatches ||
        widget.projectedColumns != oldWidget.projectedColumns) {
      _needsRebuildRows = true;
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
          _verticalScrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
          );
        } else {
          _verticalScrollController.jumpTo(targetOffset);
        }
      }
    });
  }

  /// Calculates the active visible column list in current display order.
  List<_ActiveColumnInfo> _buildActiveColumns() {
    final List<_ActiveColumnInfo> list = [];
    final hidden = widget.columnConfig.hiddenColumns;

    // 1. Timestamp
    if (!hidden.contains(StandardTableColumns.timestamp)) {
      list.add(
        _ActiveColumnInfo(
          id: StandardTableColumns.timestamp,
          title: 'Timestamp',
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
          title: 'Step',
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
          title: 'Topic',
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
          title: 'Partition',
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
          title: 'Offset',
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
          title: 'Key',
          isProjected: false,
          logicalIndex: 3,
        ),
      );
    }

    // 7. Projected columns
    final activeProjected = widget.projectedColumns.isNotEmpty
        ? widget.projectedColumns
        : widget.columnConfig.projectedColumns;

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
          title: 'Content',
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
          title: 'Content',
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

  List<_TableRowData> _filterAndSortMessages(List<KafkaMessage> messages) {
    final activeProjected = widget.projectedColumns.isNotEmpty
        ? widget.projectedColumns
        : widget.columnConfig.projectedColumns;

    // 1. Map to wrapper class to evaluate strings exactly once
    final mappedData = messages.map((msg) {
      final date = DateTime.fromMillisecondsSinceEpoch(msg.timestamp.toInt());
      final dateStr = DateFormatUtils.formatDateTime(
        context,
        date,
        withMilliseconds: true,
      );
      final stepStr = msg is ScriptResultMessage ? msg.stepName : 'Global';
      final contentPreview = TextPreviewUtils.getPayloadPreview(msg.payload);
      final keyString = msg.key ?? "";
      final projectedValues = <String, String>{};
      for (final col in activeProjected) {
        projectedValues[col.path] =
            JsonPathExtractor.extractFromPayload(msg.payload, col.path) ?? '';
      }

      return _TableRowData(
        message: msg,
        dateStr: dateStr,
        stepStr: stepStr,
        contentPreview: contentPreview,
        keyString: keyString,
        projectedValues: projectedValues,
      );
    }).toList();

    // 2. Filter
    var filtered = mappedData.where((data) {
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
            val = data.contentPreview;
            break;
          case 5: // Topic
            val = data.message.topic;
            break;
          case 6: // Step
            val = data.stepStr;
            break;
          default:
            // Dynamic projected columns
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
    }).toList();

    // 3. Sort
    if (_sortColumnIndex != null) {
      filtered.sort((a, b) {
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

        return _sortAscending ? cmp : -cmp;
      });
    }

    return filtered;
  }

  void _showFilterDialog(String title, int index) {
    final controller = TextEditingController(text: _columnFilters[index] ?? "");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Filter $title", style: const TextStyle(fontSize: 16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Enter substring to filter...",
            isDense: true,
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
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
                _needsRebuildRows = true;
              });
              Navigator.pop(ctx);
            },
            child: const Text("Clear"),
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
                _needsRebuildRows = true;
              });
              Navigator.pop(ctx);
            },
            child: const Text("Apply"),
          ),
        ],
      ),
    );
  }

  void _showMessageDetails(KafkaMessage msg) {
    showDialog(
      context: context,
      builder: (context) => MessageDetailsDialog(
        message: msg,
        initialSearchPhrase: widget.searchPhrase,
      ),
    );
  }

  /// Measures text width with a given text style.
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

    // 1. Measure header (label + padding + sort/filter/close icons ~ 64px)
    double maxWidth = _measureTextWidth(colInfo.title, headerStyle) + 68.0;

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
                  _needsRebuildRows = true;
                });
              },
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    InkWell(
                      onTap: () => _showFilterDialog(title, index),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isFiltered ? Icons.filter_alt : Icons.filter_list,
                          size: 14,
                          color: isFiltered
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
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
                      InkWell(
                        onTap: () =>
                            widget.onRemoveProjectedColumn!(projectedColumn),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ] else if (!colInfo.isProjected &&
                        widget.onToggleColumnVisibility != null &&
                        visibleColCount > 1) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () =>
                            widget.onToggleColumnVisibility!(colInfo.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Tooltip(
                          message: 'Hide column',
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.visibility_off_outlined,
                              size: 14,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
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
          onTap: () {
            if (widget.onMessageTap != null) {
              widget.onMessageTap!(msg);
            } else {
              _showMessageDetails(msg);
            }
          },
          child: decoratedCell,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_needsRebuildRows) {
      _cachedData = _filterAndSortMessages(widget.messages);
      _needsRebuildRows = false;
      final visualOrder = _cachedData.map((e) => e.message).toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onVisualOrderChanged?.call(visualOrder);
        }
      });
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

    return TableView.builder(
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
  }
}
