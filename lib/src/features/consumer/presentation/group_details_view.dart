import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'topic_partition_table.dart';

class GroupDetailsView extends StatefulWidget {
  final ConsumerGroupLag group;
  final Map<String, int>? partitionDeltas;
  final AppLocalizations l10n;

  const GroupDetailsView({
    super.key,
    required this.group,
    this.partitionDeltas,
    required this.l10n,
  });

  @override
  State<GroupDetailsView> createState() => _GroupDetailsViewState();
}

class _GroupDetailsViewState extends State<GroupDetailsView> {
  bool _sortTopicsAscending = true;
  bool _sortByLag = false;

  String _formatNum(num value) {
    final locale = Localizations.localeOf(context).toString();
    return NumberFormat.decimalPattern(locale).format(value);
  }

  int _calculateTopicLag(List<TopicPartitionLag> partitionLags) {
    return partitionLags.fold(0, (sum, item) => sum + item.lag.toInt());
  }

  int? _calculateTopicDelta(
    String topic,
    List<TopicPartitionLag> partitionLags,
  ) {
    if (widget.partitionDeltas == null) return null;
    int totalDelta = 0;
    bool hasDelta = false;
    for (final part in partitionLags) {
      final key = "${part.topic}-${part.partition}";
      final delta = widget.partitionDeltas![key];
      if (delta != null) {
        totalDelta += delta;
        hasDelta = true;
      }
    }
    return hasDelta ? totalDelta : null;
  }

  Widget _buildTopicDeltaWidget(BuildContext context, int? delta) {
    if (delta == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          "-",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }

    final String text;
    final Color color;
    if (delta > 0) {
      text = "+${_formatNum(delta)}";
      color = Colors.red;
    } else if (delta < 0) {
      text = _formatNum(delta);
      color = Colors.green;
    } else {
      text = "0";
      color = Theme.of(context).colorScheme.outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<TopicPartitionLag>> topicGroups = {};
    for (final part in widget.group.partitionLags) {
      topicGroups.putIfAbsent(part.topic, () => []).add(part);
    }

    final topicsList = topicGroups.keys.toList();

    topicsList.sort((a, b) {
      int cmp;
      if (_sortByLag) {
        final lagA = _calculateTopicLag(topicGroups[a]!);
        final lagB = _calculateTopicLag(topicGroups[b]!);
        cmp = lagA.compareTo(lagB);
      } else {
        cmp = a.toLowerCase().compareTo(b.toLowerCase());
      }
      return _sortTopicsAscending ? cmp : -cmp;
    });

    final isGerman = Localizations.localeOf(context).languageCode == 'de';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isGerman ? "Topics sortieren nach:" : "Sort topics by:",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (!_sortByLag) {
                      _sortTopicsAscending = !_sortTopicsAscending;
                    } else {
                      _sortByLag = false;
                      _sortTopicsAscending = true;
                    }
                  });
                },
                icon: Icon(
                  !_sortByLag && _sortTopicsAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 14,
                ),
                label: Text(
                  isGerman ? "Name" : "Name",
                  style: TextStyle(
                    fontWeight: !_sortByLag
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (_sortByLag) {
                      _sortTopicsAscending = !_sortTopicsAscending;
                    } else {
                      _sortByLag = true;
                      _sortTopicsAscending = true;
                    }
                  });
                },
                icon: Icon(
                  _sortByLag && _sortTopicsAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 14,
                ),
                label: Text(
                  isGerman ? "Lag" : "Lag",
                  style: TextStyle(
                    fontWeight: _sortByLag
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (topicsList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  isGerman
                      ? "Keine aktiven Partitionen gefunden."
                      : "No active partition assignments.",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ...topicsList.map((topic) {
            final parts = topicGroups[topic]!;
            final totalLag = _calculateTopicLag(parts);
            final topicDelta = _calculateTopicDelta(topic, parts);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ExpansionTile(
                title: Text(
                  topic,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTopicDeltaWidget(context, topicDelta),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: totalLag > 0
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${widget.l10n.lagCol}: ${_formatNum(totalLag)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: totalLag > 0
                              ? Theme.of(context).colorScheme.onErrorContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  TopicPartitionTable(
                    partitionLags: parts,
                    partitionDeltas: widget.partitionDeltas,
                    l10n: widget.l10n,
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
