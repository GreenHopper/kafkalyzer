import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';

/// Leader, replica and ISR state of one topic, one row per partition.
/// The health classification itself happens in Rust, this widget only shows it.
class TopicPartitionHealthTable extends StatefulWidget {
  final ClusterProfile profile;
  final String topicName;

  const TopicPartitionHealthTable({
    super.key,
    required this.profile,
    required this.topicName,
  });

  @override
  State<TopicPartitionHealthTable> createState() =>
      TopicPartitionHealthTableState();
}

class TopicPartitionHealthTableState extends State<TopicPartitionHealthTable> {
  final KafkaMetadataService _metadataService = getIt<KafkaMetadataService>();

  TopicPartitionDetails? _details;
  bool _loading = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant TopicPartitionHealthTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A metadata refresh hands us a new topic object, so re-read the rows.
    if (oldWidget.topicName != widget.topicName ||
        oldWidget.profile.name != widget.profile.name) {
      Future.microtask(_load);
    }
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final details = await _metadataService.fetchTopicPartitions(
        profile: widget.profile,
        topic: widget.topicName,
      );
      if (!mounted) return;
      setState(() {
        _details = details;
        _unavailable = details.partitions.isEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _details = null;
        _unavailable = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _brokerLabel(BrokerEndpoint broker) =>
      '${broker.id} (${broker.host}:${broker.port})';

  String _leaderLabel(PartitionRow row) {
    final leader = row.leader;
    if (leader == null) {
      return AppLocalizations.of(context)?.partitionNoLeader ?? 'none';
    }
    final broker = _details?.brokers.cast<BrokerEndpoint?>().firstWhere(
      (b) => b!.id == leader,
      orElse: () => null,
    );
    return broker == null ? '$leader' : _brokerLabel(broker);
  }

  Widget _cell(
    String text, {
    required int flex,
    Color? color,
    bool bold = false,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final partitions = _details?.partitions ?? const <PartitionRow>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n?.partitionHealthTitle ?? 'Partition health',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              if (_loading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const Spacer(),
              IconButton(
                key: const Key('partition_health_refresh'),
                icon: const Icon(Icons.refresh, size: 16),
                tooltip: l10n?.retry ?? 'Refresh',
                style: IconButton.styleFrom(
                  minimumSize: const Size(28, 28),
                  padding: EdgeInsets.zero,
                ),
                onPressed: _loading ? null : _load,
              ),
            ],
          ),
          if (_unavailable)
            Text(
              l10n?.partitionHealthUnavailable ??
                  'Partition metadata unavailable',
              key: const Key('partition_health_unavailable'),
              style: TextStyle(fontSize: 11, color: colorScheme.error),
            )
          else if (partitions.isNotEmpty) ...[
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        _cell('#', flex: 1),
                        _cell(l10n?.partitionLeaderCol ?? 'Leader', flex: 4),
                        _cell(
                          l10n?.partitionReplicasCol ?? 'Replicas',
                          flex: 3,
                        ),
                        _cell(l10n?.partitionIsrCol ?? 'ISR', flex: 3),
                      ],
                    ),
                    for (final row in partitions)
                      Container(
                        key: Key('partition_row_${row.partition}'),
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            _cell('${row.partition}', flex: 1),
                            _cell(
                              _leaderLabel(row),
                              flex: 4,
                              color: row.leaderless ? colorScheme.error : null,
                              bold: !row.leaderless,
                            ),
                            _cell(
                              row.replicas.join(', '),
                              flex: 3,
                              color: row.underReplicated
                                  ? colorScheme.error
                                  : null,
                            ),
                            _cell(row.inSyncReplicas.join(', '), flex: 3),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
