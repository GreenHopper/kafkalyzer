import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'topic_partition_table.dart';

/// Group detail: the members with the partitions they own, then the per-topic lag.
class GroupDetailsView extends StatefulWidget {
  final ClusterProfile profile;
  final ConsumerGroupLag group;
  final Map<String, int>? partitionDeltas;

  /// Retained lag readings per topic-partition, oldest first.
  final Map<String, List<int>>? partitionTrends;

  /// Lag in messages at which a partition is marked; 0 disables the marking.
  final int lagWarnThreshold;
  final AppLocalizations l10n;

  const GroupDetailsView({
    super.key,
    required this.profile,
    required this.group,
    this.partitionDeltas,
    this.partitionTrends,
    this.lagWarnThreshold = 0,
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

  /// Members of the group and the partitions each of them owns. Assignment
  /// decoding happens in Rust; this only shows what came back.
  Widget _buildMembersCard(BuildContext context) {
    final l10n = widget.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final members = widget.group.members;
    final unassigned = widget.group.unassignedPartitions;

    return Card(
      key: const Key('group_members_card'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        key: const Key('group_members_tile'),
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.only(left: 24, right: 24),
        title: Row(
          children: [
            Text(
              '${l10n.groupMembersTitle} (${members.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (unassigned.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                key: const Key('group_unassigned_chip'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.groupUnassignedPartitions(unassigned.length),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        children: [
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                l10n.groupMemberEmpty,
                key: const Key('group_member_empty'),
                style: TextStyle(
                  color: colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            for (final member in members)
              ExpansionTile(
                key: Key('group_member_${member.memberId}'),
                tilePadding: const EdgeInsets.only(left: 24, right: 24),
                title: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        member.clientId.isEmpty
                            ? member.memberId
                            : member.clientId,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        member.clientHost.isEmpty ? '-' : member.clientHost,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      l10n.groupMemberPartitions(member.assignments.length),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                children: [
                  if (!member.assignmentDecodable)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        l10n.groupAssignmentNotDecodable,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  for (final assignment in member.assignments)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${assignment.topic}-${assignment.partition}',
                            key: Key(
                              'group_assignment_${assignment.topic}-${assignment.partition}',
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          for (final partition in unassigned)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
              child: Text(
                '${partition.topic}-${partition.partition}',
                key: Key(
                  'group_unassigned_${partition.topic}-${partition.partition}',
                ),
                style: TextStyle(fontSize: 12, color: colorScheme.error),
              ),
            ),
        ],
      ),
    );
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

    Widget buildHeaderCell({
      required String label,
      required bool isSelected,
      required bool isAscending,
      required VoidCallback onTap,
      required int flex,
    }) {
      return Expanded(
        flex: flex,
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(
                  isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMembersCard(context),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(
              left: 26,
              right: 64,
              top: 4,
              bottom: 4,
            ),
            child: Row(
              children: [
                buildHeaderCell(
                  label: isGerman ? 'Topic' : 'Topic',
                  isSelected: !_sortByLag,
                  isAscending: _sortTopicsAscending,
                  onTap: () {
                    setState(() {
                      if (!_sortByLag) {
                        _sortTopicsAscending = !_sortTopicsAscending;
                      } else {
                        _sortByLag = false;
                        _sortTopicsAscending = true;
                      }
                    });
                  },
                  flex: 3,
                ),
                const Spacer(flex: 8),
                buildHeaderCell(
                  label: isGerman ? 'Lag' : 'Lag',
                  isSelected: _sortByLag,
                  isAscending: _sortTopicsAscending,
                  onTap: () {
                    setState(() {
                      if (_sortByLag) {
                        _sortTopicsAscending = !_sortTopicsAscending;
                      } else {
                        _sortByLag = true;
                        _sortTopicsAscending = true;
                      }
                    });
                  },
                  flex: 2,
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isGerman ? 'Abarbeitung' : 'Processed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
                tilePadding: const EdgeInsets.only(left: 24, right: 24),
                title: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        topic,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(flex: 2),
                    const Spacer(flex: 2),
                    const Spacer(flex: 2),
                    const Spacer(flex: 2),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: totalLag > 0
                                ? Theme.of(context).colorScheme.errorContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${widget.l10n.lagCol}: ${_formatNum(totalLag)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: totalLag > 0
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildTopicDeltaWidget(context, topicDelta),
                      ),
                    ),
                  ],
                ),
                children: [
                  TopicPartitionTable(
                    profile: widget.profile,
                    partitionLags: parts,
                    partitionDeltas: widget.partitionDeltas,
                    partitionTrends: widget.partitionTrends,
                    lagWarnThreshold: widget.lagWarnThreshold,
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
