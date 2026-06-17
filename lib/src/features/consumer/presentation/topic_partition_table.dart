import 'package:flutter/material.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class TopicPartitionTable extends StatefulWidget {
  final List<TopicPartitionLag> partitionLags;
  final AppLocalizations l10n;

  const TopicPartitionTable({
    super.key,
    required this.partitionLags,
    required this.l10n,
  });

  @override
  State<TopicPartitionTable> createState() => _TopicPartitionTableState();
}

class _TopicPartitionTableState extends State<TopicPartitionTable> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  Widget _buildHeaderCell(int index, String title, {required int flex}) {
    final isSelected = _sortColumnIndex == index;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          setState(() {
            if (_sortColumnIndex == index) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumnIndex = index;
              _sortAscending = true;
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    Color? textColor,
    bool isBold = false,
    required int flex,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: textColor,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedParts = List<TopicPartitionLag>.from(widget.partitionLags);
    sortedParts.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.partition.compareTo(b.partition);
          break;
        case 1:
          cmp = a.logEndOffset.compareTo(b.logEndOffset);
          break;
        case 2:
          cmp = a.currentOffset.compareTo(b.currentOffset);
          break;
        case 3:
        default:
          cmp = a.lag.compareTo(b.lag);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell(0, widget.l10n.partitionCol, flex: 2),
                _buildHeaderCell(1, widget.l10n.logEndOffsetCol, flex: 3),
                _buildHeaderCell(2, widget.l10n.committedOffsetCol, flex: 3),
                _buildHeaderCell(3, widget.l10n.lagCol, flex: 2),
              ],
            ),
          ),
          ...sortedParts.map((part) {
            final lagVal = part.lag.toInt();
            final isHighLag = lagVal > 0;
            final committedStr = part.currentOffset.toInt() == -1
                ? "-"
                : part.currentOffset.toString();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  _buildTableCell(part.partition.toString(), flex: 2),
                  _buildTableCell(part.logEndOffset.toString(), flex: 3),
                  _buildTableCell(committedStr, flex: 3),
                  _buildTableCell(
                    lagVal.toString(),
                    flex: 2,
                    textColor: isHighLag
                        ? Theme.of(context).colorScheme.error
                        : null,
                    isBold: isHighLag,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
