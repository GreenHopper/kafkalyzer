import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_result_message.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/ui/color_utils.dart';
import 'package:kafkalyzer/src/ui/message_details_dialog.dart';
import 'package:kafkalyzer/src/ui/highlight_text_utils.dart';
import 'package:kafkalyzer/src/ui/text_preview_utils.dart';

class _TableRowData {
  final KafkaMessage message;
  final String dateStr;
  final String stepStr;
  final String contentPreview;
  final String keyString;

  _TableRowData({
    required this.message,
    required this.dateStr,
    required this.stepStr,
    required this.contentPreview,
    required this.keyString,
  });
}

class MessagesTableView extends StatefulWidget {
  final List<KafkaMessage> messages;
  final bool showTopic;
  final bool showStep;
  final String? searchPhrase;
  final bool showNonMatches;
  final Function(KafkaMessage)? onMessageTap;

  const MessagesTableView({
    super.key,
    required this.messages,
    this.showTopic = false,
    this.showStep = false,
    this.searchPhrase,
    this.showNonMatches = false,
    this.onMessageTap,
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

  @override
  void didUpdateWidget(covariant MessagesTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages != oldWidget.messages ||
        widget.searchPhrase != oldWidget.searchPhrase ||
        widget.showTopic != oldWidget.showTopic ||
        widget.showStep != oldWidget.showStep ||
        widget.showNonMatches != oldWidget.showNonMatches) {
      _needsRebuildRows = true;
    }
  }

  List<_TableRowData> _filterAndSortMessages(List<KafkaMessage> messages) {
    // 1. Map to wrapper class to evaluate strings exactly once
    final mappedData = messages.map((msg) {
      final date = DateTime.fromMillisecondsSinceEpoch(msg.timestamp.toInt());
      final dateStr = DateFormatUtils.formatDateTime(context, date, withMilliseconds: true);
      final stepStr = msg is ScriptResultMessage ? msg.stepName : 'Global';
      final contentPreview = TextPreviewUtils.getPayloadPreview(msg.payload);
      final keyString = msg.key ?? "";

      return _TableRowData(
        message: msg,
        dateStr: dateStr,
        stepStr: stepStr,
        contentPreview: contentPreview,
        keyString: keyString,
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
        }
        // Substring
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
            hintText: "Enter filter text...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 20),
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
      builder: (context) => MessageDetailsDialog(message: msg, initialSearchPhrase: widget.searchPhrase),
    );
  }

  TableViewCell _buildSortableHeader(String title, int index) {
    final bool isSorted = _sortColumnIndex == index;
    bool isFiltered = _columnFilters.containsKey(index) && _columnFilters[index]!.isNotEmpty;

    return TableViewCell(
      child: InkWell(
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
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isFiltered ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
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
              if (isSorted) Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  TableSpan _buildColumnSpan(int index) {
    if (!widget.showStep && index >= 1) index++; // Skip Step
    if (!widget.showTopic && index >= 2) index++; // Skip Topic

    switch (index) {
      case 0: // Timestamp
        return const TableSpan(extent: FixedTableSpanExtent(180));
      case 1: // Step
        return const TableSpan(extent: FixedTableSpanExtent(120));
      case 2: // Topic
        return const TableSpan(extent: FixedTableSpanExtent(150));
      case 3: // Partition
        return const TableSpan(extent: FixedTableSpanExtent(110));
      case 4: // Offset
        return const TableSpan(extent: FixedTableSpanExtent(110));
      case 5: // Key
        return const TableSpan(extent: FractionalTableSpanExtent(0.33)); // Like flex: 1
      case 6: // Content
        return const TableSpan(extent: FractionalTableSpanExtent(0.67)); // Like flex: 2
      default:
        return const TableSpan(extent: FixedTableSpanExtent(100));
    }
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
    TextStyle monoStyle,
    TextStyle highlightStyle,
  ) {
    final int columnRaw = vicinity.column;
    // Map visual column index to logical model index based on visibility
    int logicalColumn = columnRaw;
    if (!widget.showStep && logicalColumn >= 1) logicalColumn++;
    if (!widget.showTopic && logicalColumn >= 2) logicalColumn++;

    // Row 0 is the Header
    if (vicinity.row == 0) {
      switch (logicalColumn) {
        case 0:
          return _buildSortableHeader('Timestamp', 0);
        case 1:
          return _buildSortableHeader('Step', 6);
        case 2:
          return _buildSortableHeader('Topic', 5);
        case 3:
          return _buildSortableHeader('Partition', 1);
        case 4:
          return _buildSortableHeader('Offset', 2);
        case 5:
          return _buildSortableHeader('Key', 3);
        case 6:
          return _buildSortableHeader('Content', 4);
        default:
          return TableViewCell(child: const SizedBox.shrink());
      }
    }

    // Data Row
    final dataIndex = vicinity.row - 1;
    if (dataIndex >= _cachedData.length) {
      return TableViewCell(child: const SizedBox.shrink());
    }

    final data = _cachedData[dataIndex];
    final msg = data.message;
    final dividerColor = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5);

    // Search match logic
    bool isMatch = true;
    if (widget.searchPhrase != null && widget.searchPhrase!.isNotEmpty) {
      final query = widget.searchPhrase!.toLowerCase();
      final keyMatch = data.keyString.toLowerCase().contains(query);
      final payloadMatch = (msg.payload ?? "").toLowerCase().contains(query);
      final topicMatch = msg.topic.toLowerCase().contains(query);
      final stepMatch = data.stepStr.toLowerCase().contains(query);
      isMatch = keyMatch || payloadMatch || topicMatch || stepMatch;
    }

    Widget cellContent;
    switch (logicalColumn) {
      case 0: // Timestamp
        cellContent = Text(data.dateStr, style: const TextStyle(fontSize: 12));
        break;
      case 1: // Step
        cellContent = Text(data.stepStr, style: monoStyle, overflow: TextOverflow.ellipsis);
        break;
      case 2: // Topic
        cellContent = Tooltip(
          message: msg.topic,
          child: Text(
            msg.topic,
            style: TextStyle(fontWeight: FontWeight.bold, color: ColorUtils.getColorForString(msg.topic)),
            overflow: TextOverflow.ellipsis,
          ),
        );
        break;
      case 3: // Partition
        cellContent = Text(msg.partition.toString(), style: monoStyle);
        break;
      case 4: // Offset
        cellContent = Text(msg.offset.toString(), style: monoStyle);
        break;
      case 5: // Key
        cellContent = Tooltip(
          message: data.keyString,
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: HighlightTextUtils.buildHighlightedSpans(
                data.keyString,
                widget.searchPhrase ?? "",
                monoStyle,
                highlightStyle,
              ),
            ),
          ),
        );
        break;
      case 6: // Content
        cellContent = RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: HighlightTextUtils.buildHighlightedSpans(
              data.contentPreview,
              widget.searchPhrase ?? "",
              monoStyle,
              highlightStyle,
            ),
          ),
        );
        break;
      default:
        cellContent = const SizedBox.shrink();
    }

    Widget decoratedCell = Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor)),
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
    }

    final monoStyle = GoogleFonts.robotoMono(fontSize: 12, color: Theme.of(context).colorScheme.onSurface);
    final highlightStyle = monoStyle.copyWith(
      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
      color: Theme.of(context).colorScheme.onTertiaryContainer,
    );

    int totalColumns = 7;
    if (!widget.showStep) totalColumns--;
    if (!widget.showTopic) totalColumns--;

    return TableView.builder(
      columnCount: totalColumns,
      rowCount: _cachedData.length + 1, // +1 for Header
      columnBuilder: _buildColumnSpan,
      rowBuilder: _buildRowSpan,
      cellBuilder: (context, vicinity) => _buildCell(context, vicinity, monoStyle, highlightStyle),
      diagonalDragBehavior: DiagonalDragBehavior.free,
    );
  }
}
