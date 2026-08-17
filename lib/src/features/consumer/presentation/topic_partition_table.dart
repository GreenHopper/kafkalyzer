import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart' as consumer;
import 'package:kafkalyzer/src/ui/message_details_dialog.dart';

class TopicPartitionTable extends StatefulWidget {
  final ClusterProfile profile;
  final List<TopicPartitionLag> partitionLags;
  final Map<String, int>? partitionDeltas;
  final AppLocalizations l10n;

  const TopicPartitionTable({
    super.key,
    required this.profile,
    required this.partitionLags,
    this.partitionDeltas,
    required this.l10n,
  });

  @override
  State<TopicPartitionTable> createState() => _TopicPartitionTableState();
}

class _TopicPartitionTableState extends State<TopicPartitionTable> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  final Set<int> _loadingPartitions = {};

  String _formatNum(num value) {
    final locale = Localizations.localeOf(context).toString();
    return NumberFormat.decimalPattern(locale).format(value);
  }

  int? _calculatePartitionDelta(TopicPartitionLag part) {
    if (widget.partitionDeltas == null) return null;
    final key = "${part.topic}-${part.partition}";
    return widget.partitionDeltas![key];
  }

  Future<void> _viewLaggingMessage(TopicPartitionLag part) async {
    if (part.currentOffset.toInt() < 0) return;

    setState(() {
      _loadingPartitions.add(part.partition);
    });

    try {
      final stream = consumer.consumeWithFilter(
        profile: widget.profile,
        topic: part.topic,
        filterType: FilterType.contains,
        searchScope: SearchScope.both,
        startOffset: part.currentOffset,
        startPartition: part.partition,
        maxResults: 1,
        runForever: false,
      );

      final message = await stream.firstWhere(
        (m) => m.partition == part.partition && m.offset == part.currentOffset,
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => MessageDetailsDialog(message: message),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error: ${e.toString()}",
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingPartitions.remove(part.partition);
        });
      }
    }
  }

  Widget _buildDeltaCell(TopicPartitionLag part, {required int flex}) {
    final delta = _calculatePartitionDelta(part);
    if (delta == null) {
      return _buildTableCell(
        "-",
        textColor: Theme.of(context).colorScheme.outline,
        flex: flex,
      );
    }
    if (delta > 0) {
      return _buildTableCell(
        "+${_formatNum(delta)}",
        textColor: Colors.red,
        isBold: true,
        flex: flex,
      );
    } else if (delta < 0) {
      return _buildTableCell(
        _formatNum(delta),
        textColor: Colors.green,
        isBold: true,
        flex: flex,
      );
    } else {
      return _buildTableCell(
        "0",
        textColor: Theme.of(context).colorScheme.outline,
        flex: flex,
      );
    }
  }

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
    final isGerman = Localizations.localeOf(context).languageCode == 'de';
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
          cmp = a.lag.compareTo(b.lag);
          break;
        case 4:
          final deltaA = _calculatePartitionDelta(a) ?? 0;
          final deltaB = _calculatePartitionDelta(b) ?? 0;
          cmp = deltaA.compareTo(deltaB);
          break;
        default:
          cmp = a.lag.compareTo(b.lag);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
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
                _buildHeaderCell(0, widget.l10n.partitionCol, flex: 3),
                _buildHeaderCell(1, widget.l10n.logEndOffsetCol, flex: 4),
                _buildHeaderCell(2, widget.l10n.committedOffsetCol, flex: 4),
                _buildHeaderCell(3, widget.l10n.lagCol, flex: 2),
                _buildHeaderCell(
                  4,
                  isGerman ? 'Abarbeitung' : 'Processed',
                  flex: 2,
                ),
                const SizedBox(width: 48), // Space for action
              ],
            ),
          ),
          ...sortedParts.map((part) {
            final lagVal = part.lag.toInt();
            final isHighLag = lagVal > 0;
            final committedStr = part.currentOffset.toInt() == -1
                ? "-"
                : _formatNum(part.currentOffset.toInt());
            final isLoading = _loadingPartitions.contains(part.partition);

            return Container(
              padding: const EdgeInsets.only(left: 24, right: 24),
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
                  _buildTableCell(part.partition.toString(), flex: 3),
                  _buildTableCell(
                    _formatNum(part.logEndOffset.toInt()),
                    flex: 4,
                  ),
                  _buildTableCell(committedStr, flex: 4),
                  _buildTableCell(
                    _formatNum(lagVal),
                    flex: 2,
                    textColor: isHighLag
                        ? Theme.of(context).colorScheme.error
                        : null,
                    isBold: isHighLag,
                  ),
                  _buildDeltaCell(part, flex: 2),
                  SizedBox(
                    width: 48,
                    child: Center(
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.visibility_outlined),
                              iconSize: 20,
                              tooltip: isGerman
                                  ? 'Message am Offset anzeigen'
                                  : 'View message at offset',
                              onPressed: part.currentOffset.toInt() >= 0
                                  ? () => _viewLaggingMessage(part)
                                  : null,
                            ),
                    ),
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

