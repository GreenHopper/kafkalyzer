import '../../../../l10n/app_localizations.dart';
import '../../../rust/api/kafka_metadata.dart';
import '../../../rust/api/kafka_types.dart';
import '../../scripting/domain/script.dart';
import '../main_navigation_controller.dart';
import 'package:kafkalyzer/src/features/messages/domain/message_reference.dart';
import 'fuzzy_match.dart';
import 'palette_entry.dart';

/// In-memory snapshot of all sources searched by the command palette.
class PaletteSnapshot {
  const PaletteSnapshot({
    required this.l10n,
    required this.clusters,
    required this.activeProfile,
    required this.topics,
    required this.openTopicNames,
    required this.consumerGroupIds,
    required this.scripts,
    required this.onSelectDestination,
    required this.onOpenCluster,
    required this.onOpenTopic,
    required this.onOpenConsumerGroup,
    required this.onOpenScript,
  });

  final AppLocalizations l10n;
  final List<ClusterProfile> clusters;
  final ClusterProfile? activeProfile;

  /// Cached topics for [activeProfile]; `null` when not loaded or failed.
  final List<TopicMetadata>? topics;
  final Set<String> openTopicNames;

  /// Session-loaded consumer group IDs for [activeProfile]; `null` when
  /// Consumer Lag has not loaded them yet in this session.
  final List<String>? consumerGroupIds;
  final List<Script> scripts;

  final void Function(MainDestination destination) onSelectDestination;
  final Future<void> Function(ClusterProfile profile) onOpenCluster;
  final void Function(TopicMetadata topic) onOpenTopic;
  final void Function(String groupId) onOpenConsumerGroup;
  final void Function(Script script) onOpenScript;

  bool get groupsNotLoaded => activeProfile != null && consumerGroupIds == null;
}

class PaletteRankResult {
  const PaletteRankResult({
    required this.visible,
    required this.totalMatches,
    required this.groupsNotLoaded,
  });

  final List<RankedPaletteEntry> visible;
  final int totalMatches;
  final bool groupsNotLoaded;
}

List<PaletteEntry> _buildDestinationEntries(PaletteSnapshot snapshot) {
  final l10n = snapshot.l10n;
  return [
    PaletteEntry(
      kind: PaletteEntryKind.destination,
      label: l10n.explorer,
      run: () async => snapshot.onSelectDestination(MainDestination.explorer),
    ),
    PaletteEntry(
      kind: PaletteEntryKind.destination,
      label: l10n.consumerLag,
      run: () async =>
          snapshot.onSelectDestination(MainDestination.consumerLag),
    ),
    PaletteEntry(
      kind: PaletteEntryKind.destination,
      label: l10n.scripts,
      run: () async => snapshot.onSelectDestination(MainDestination.scripts),
    ),
    PaletteEntry(
      kind: PaletteEntryKind.destination,
      label: l10n.settings,
      run: () async => snapshot.onSelectDestination(MainDestination.settings),
    ),
  ];
}

List<PaletteEntry> _buildClusterEntries(PaletteSnapshot snapshot) {
  return [
    for (final profile in snapshot.clusters)
      PaletteEntry(
        kind: PaletteEntryKind.cluster,
        label: profile.name,
        subtitle: snapshot.activeProfile?.name == profile.name
            ? snapshot.l10n.commandPaletteActiveCluster
            : null,
        run: () => snapshot.onOpenCluster(profile),
      ),
  ];
}

List<PaletteEntry> _buildTopicEntries(PaletteSnapshot snapshot) {
  final topics = snapshot.topics;
  if (snapshot.activeProfile == null || topics == null) return const [];
  return [
    for (final topic in topics)
      PaletteEntry(
        kind: PaletteEntryKind.topic,
        label: topic.name,
        subtitle: snapshot.l10n.commandPalettePartitionsCount(
          topic.partitionCount,
        ),
        isOpenTab: snapshot.openTopicNames.contains(topic.name),
        run: () async => snapshot.onOpenTopic(topic),
      ),
  ];
}

List<PaletteEntry> _buildConsumerGroupEntries(PaletteSnapshot snapshot) {
  final groupIds = snapshot.consumerGroupIds;
  if (snapshot.activeProfile == null || groupIds == null) return const [];
  return [
    for (final id in groupIds)
      PaletteEntry(
        kind: PaletteEntryKind.consumerGroup,
        label: id,
        run: () async => snapshot.onOpenConsumerGroup(id),
      ),
  ];
}

List<PaletteEntry> _buildScriptEntries(PaletteSnapshot snapshot) {
  return [
    for (final script in snapshot.scripts)
      PaletteEntry(
        kind: PaletteEntryKind.script,
        label: script.name,
        subtitle: snapshot.l10n.commandPaletteStepsCount(script.steps.length),
        run: () async => snapshot.onOpenScript(script),
      ),
  ];
}

/// Ranks and filters [snapshot] entries for [query], capping at [limit].
PaletteRankResult rankPaletteEntries({
  required String query,
  required PaletteSnapshot snapshot,
  required Future<void> Function(String rawReference) onOpenReference,
  int limit = 50,
}) {
  final trimmed = query.trim();
  final destinations = _buildDestinationEntries(snapshot);
  final clusters = _buildClusterEntries(snapshot);
  final topics = _buildTopicEntries(snapshot);
  final groups = _buildConsumerGroupEntries(snapshot);
  final scripts = _buildScriptEntries(snapshot);

  final reference = trimmed.isEmpty ? null : MessageReference.tryParse(trimmed);
  final referenceEntry = reference == null
      ? null
      : RankedPaletteEntry(
          entry: PaletteEntry(
            kind: PaletteEntryKind.reference,
            label: snapshot.l10n.commandPaletteOpenReference,
            subtitle: trimmed,
            run: () => onOpenReference(trimmed),
          ),
          score: double.infinity,
          matchedIndices: const [],
        );

  if (trimmed.isEmpty) {
    final openTopics = topics.where((t) => t.isOpenTab).toList();
    final emptyOrder = <PaletteEntry>[
      ...destinations,
      ...clusters,
      ...openTopics,
      ...scripts,
    ];
    final ranked = [
      for (final entry in emptyOrder)
        RankedPaletteEntry(entry: entry, score: 0, matchedIndices: const []),
    ];
    final total = ranked.length;
    return PaletteRankResult(
      visible: ranked.take(limit).toList(),
      totalMatches: total,
      groupsNotLoaded: snapshot.groupsNotLoaded,
    );
  }

  final allEntries = <PaletteEntry>[
    ...destinations,
    ...clusters,
    ...topics,
    ...groups,
    ...scripts,
  ];

  final matched = <RankedPaletteEntry>[];
  for (final entry in allEntries) {
    final m = fuzzyMatch(trimmed, entry.label);
    if (m != null) {
      matched.add(
        RankedPaletteEntry(
          entry: entry,
          score: m.score,
          matchedIndices: m.matchedIndices,
        ),
      );
    }
  }

  matched.sort((a, b) {
    final scoreCmp = b.score.compareTo(a.score);
    if (scoreCmp != 0) return scoreCmp;
    final kindCmp = a.entry.kind.index.compareTo(b.entry.kind.index);
    if (kindCmp != 0) return kindCmp;
    final alphaCmp = a.entry.label.toLowerCase().compareTo(
      b.entry.label.toLowerCase(),
    );
    if (alphaCmp != 0) return alphaCmp;
    return a.entry.label.length.compareTo(b.entry.label.length);
  });

  final combined = <RankedPaletteEntry>[?referenceEntry, ...matched];
  final total = combined.length;
  return PaletteRankResult(
    visible: combined.take(limit).toList(),
    totalMatches: total,
    groupsNotLoaded: snapshot.groupsNotLoaded,
  );
}
