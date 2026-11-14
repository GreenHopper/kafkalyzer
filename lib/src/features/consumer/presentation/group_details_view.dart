import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import '../domain/consumer_lag_calculator.dart';
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
  final String? lagError;
  final VoidCallback? onRetry;

  const GroupDetailsView({
    super.key,
    required this.profile,
    required this.group,
    this.partitionDeltas,
    this.partitionTrends,
    this.lagWarnThreshold = 0,
    required this.l10n,
    this.lagError,
    this.onRetry,
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

  GroupLagSummary _summarizeTopicLag(List<TopicPartitionLag> partitionLags) {
    return summarizePartitionLags(partitionLags);
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
            if (widget.group.ownershipKnown && unassigned.isNotEmpty) ...[
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
            ] else if (!widget.group.ownershipKnown && members.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                key: const Key('group_ownership_unknown'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.partitionOwnershipUnknown,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
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
          if (widget.group.ownershipKnown)
            for (final partition in unassigned)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 2,
                ),
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
      color = Theme.of(context).colorScheme.error;
    } else if (delta < 0) {
      text = _formatNum(delta);
      color = Theme.of(context).colorScheme.primary;
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
      if (_sortByLag) {
        final lagA = _summarizeTopicLag(topicGroups[a]!).totalLag;
        final lagB = _summarizeTopicLag(topicGroups[b]!).totalLag;
        if (lagA == null && lagB == null) return 0;
        if (lagA == null) return 1;
        if (lagB == null) return -1;
        final cmp = lagA.compareTo(lagB);
        return _sortTopicsAscending ? cmp : -cmp;
      }
      final cmp = a.toLowerCase().compareTo(b.toLowerCase());
      return _sortTopicsAscending ? cmp : -cmp;
    });

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

    final effectiveError = widget.lagError ?? widget.group.lagError;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (effectiveError != null && effectiveError.isNotEmpty) ...[
            Card(
              key: const Key('group_lag_error_card'),
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.l10n.lagErrorTooltip(effectiveError),
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                    if (widget.onRetry != null)
                      OutlinedButton.icon(
                        key: const Key('group_lag_retry_button'),
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(widget.l10n.lagRetryAction),
                      ),
                  ],
                ),
              ),
            ),
          ],
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
                  label: widget.l10n.topic,
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
                  label: widget.l10n.lagCol,
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
                      widget.l10n.processedCol,
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
                  widget.l10n.noActivePartitionAssignments,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ...topicsList.map((topic) {
            final parts = topicGroups[topic]!;
            final topicSummary = _summarizeTopicLag(parts);
            final topicDelta = _calculateTopicDelta(topic, parts);
            final scheme = Theme.of(context).colorScheme;
            final Color badgeBg;
            final Color badgeFg;
            final String badgeText;
            if (topicSummary.outcome == GroupLagOutcome.unknown) {
              badgeBg = scheme.errorContainer;
              badgeFg = scheme.onErrorContainer;
              badgeText = widget.l10n.lagUnknown;
            } else if (topicSummary.outcome ==
                GroupLagOutcome.noCommittedOffsets) {
              badgeBg = scheme.outlineVariant.withValues(alpha: 0.2);
              badgeFg = scheme.onSurfaceVariant;
              badgeText = widget.l10n.lagNoCommittedOffsets;
            } else {
              final lag = topicSummary.totalLag!;
              badgeBg = lag > 0
                  ? scheme.errorContainer
                  : scheme.primaryContainer;
              badgeFg = lag > 0
                  ? scheme.onErrorContainer
                  : scheme.onPrimaryContainer;
              badgeText = "${widget.l10n.lagCol}: ${_formatNum(lag)}";
            }
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
                        child: Tooltip(
                          message: topicSummary.unknownReason ?? badgeText,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: badgeFg,
                              ),
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
