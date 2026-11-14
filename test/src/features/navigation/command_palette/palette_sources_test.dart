import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations_en.dart';
import 'package:kafkalyzer/src/features/navigation/command_palette/palette_entry.dart';
import 'package:kafkalyzer/src/features/navigation/command_palette/palette_sources.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

void main() {
  final l10n = AppLocalizationsEn();

  const prod = ClusterProfile(
    name: 'prod',
    bootstrapServers: 'b:9092',
    tlsVerification: TlsVerification.enabled,
  );
  const staging = ClusterProfile(
    name: 'staging',
    bootstrapServers: 's:9092',
    tlsVerification: TlsVerification.enabled,
  );
  const script = Script(id: 's1', name: 'daily-check');

  PaletteSnapshot makeSnapshot({
    ClusterProfile? activeProfile,
    List<TopicMetadata>? topics,
    Set<String> openTopicNames = const {},
    List<String>? consumerGroupIds,
  }) {
    return PaletteSnapshot(
      l10n: l10n,
      clusters: const [prod, staging],
      activeProfile: activeProfile,
      topics: topics,
      openTopicNames: openTopicNames,
      consumerGroupIds: consumerGroupIds,
      scripts: [script],
      onSelectDestination: (_) {},
      onOpenCluster: (_) async {},
      onOpenTopic: (_) {},
      onOpenConsumerGroup: (_) {},
      onOpenScript: (_) {},
    );
  }

  test(
    'not connected: offers destinations, clusters, scripts; no topics/groups',
    () {
      final result = rankPaletteEntries(
        query: '',
        snapshot: makeSnapshot(activeProfile: null, topics: null),
        onOpenReference: (_) async {},
      );
      expect(result.groupsNotLoaded, isFalse);
      expect(result.visible.map((r) => r.entry.kind).toSet(), {
        PaletteEntryKind.destination,
        PaletteEntryKind.cluster,
        PaletteEntryKind.script,
      });
      expect(
        result.visible.take(4).map((r) => r.entry.kind),
        List.filled(4, PaletteEntryKind.destination),
      );
    },
  );

  test(
    'connected with null topics lists no topics; loaded topics include hidden/internal',
    () {
      final nullTopicsResult = rankPaletteEntries(
        query: 'orders',
        snapshot: makeSnapshot(activeProfile: prod, topics: null),
        onOpenReference: (_) async {},
      );
      expect(
        nullTopicsResult.visible.where(
          (r) => r.entry.kind == PaletteEntryKind.topic,
        ),
        isEmpty,
      );
      expect(nullTopicsResult.groupsNotLoaded, isTrue);

      final loadedResult = rankPaletteEntries(
        query: '__consumer',
        snapshot: makeSnapshot(
          activeProfile: prod,
          topics: const [
            TopicMetadata(
              name: '__consumer_offsets',
              partitionCount: 50,
              replicationFactor: 1,
            ),
            TopicMetadata(
              name: 'orders.events',
              partitionCount: 6,
              replicationFactor: 1,
            ),
          ],
          consumerGroupIds: const ['cg-orders'],
        ),
        onOpenReference: (_) async {},
      );
      expect(loadedResult.groupsNotLoaded, isFalse);
      expect(loadedResult.visible.single.entry.kind, PaletteEntryKind.topic);
      expect(loadedResult.visible.single.entry.label, '__consumer_offsets');
    },
  );

  test('caps visible results at 50 and reports totalMatches', () {
    final manyTopics = <TopicMetadata>[
      for (var i = 0; i < 80; i++)
        TopicMetadata(
          name: 'orders-$i',
          partitionCount: 1,
          replicationFactor: 1,
        ),
    ];
    final result = rankPaletteEntries(
      query: 'orders',
      snapshot: makeSnapshot(activeProfile: prod, topics: manyTopics),
      onOpenReference: (_) async {},
    );
    expect(result.visible.length, 50);
    expect(result.totalMatches, 80);
  });

  test('valid kafkalyzer:// reference ranks first', () {
    final result = rankPaletteEntries(
      query: 'kafkalyzer://open?topic=orders',
      snapshot: makeSnapshot(activeProfile: prod, topics: const []),
      onOpenReference: (_) async {},
    );
    expect(result.visible.first.entry.kind, PaletteEntryKind.reference);
  });
}
