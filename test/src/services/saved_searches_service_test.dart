import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/features/search/models/topic_search_preset.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/saved_searches_service.dart';

void main() {
  late SavedSearchesService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = SavedSearchesService();
  });

  group('SavedSearchesService', () {
    test('returns empty list when no presets are saved', () async {
      final presets = await service.getPresets(
        clusterName: 'local-cluster',
        topicName: 'orders',
      );
      expect(presets, isEmpty);
    });

    test('saves and retrieves preset scoped to cluster and topic', () async {
      final preset = TopicSearchPreset(
        id: 'preset-1',
        name: 'Errors in orders',
        clusterName: 'local-cluster',
        topicName: 'orders',
        scanMode: TopicScanMode.timeRange,
        filterType: FilterType.regex,
        filterTerm: 'ERROR|FATAL',
        searchScope: SearchScope.value,
        maxResults: '500',
        createdAt: DateTime(2026, 10, 25, 12, 0),
      );

      await service.savePreset(preset);

      // Same cluster and topic returns the preset
      final retrieved = await service.getPresets(
        clusterName: 'local-cluster',
        topicName: 'orders',
      );
      expect(retrieved.length, 1);
      expect(retrieved.first.name, 'Errors in orders');
      expect(retrieved.first.filterTerm, 'ERROR|FATAL');
      expect(retrieved.first.scanMode, TopicScanMode.timeRange);
      expect(retrieved.first.filterType, FilterType.regex);

      // Different topic returns empty
      final otherTopic = await service.getPresets(
        clusterName: 'local-cluster',
        topicName: 'payments',
      );
      expect(otherTopic, isEmpty);

      // Different cluster returns empty
      final otherCluster = await service.getPresets(
        clusterName: 'prod-cluster',
        topicName: 'orders',
      );
      expect(otherCluster, isEmpty);
    });

    test('overwrites preset with same name or id on save', () async {
      final initial = TopicSearchPreset(
        id: 'preset-1',
        name: 'My Preset',
        clusterName: 'cluster-a',
        topicName: 'topic-a',
        filterTerm: 'initial',
        createdAt: DateTime.now(),
      );
      await service.savePreset(initial);

      final updated = initial.copyWith(filterTerm: 'updated-term');
      await service.savePreset(updated);

      final list = await service.getPresets(
        clusterName: 'cluster-a',
        topicName: 'topic-a',
      );
      expect(list.length, 1);
      expect(list.first.filterTerm, 'updated-term');
    });

    test('deletes preset by id', () async {
      final p1 = TopicSearchPreset(
        id: 'p1',
        name: 'Preset 1',
        clusterName: 'cluster-a',
        topicName: 'topic-a',
        createdAt: DateTime(2026, 1, 1),
      );
      final p2 = TopicSearchPreset(
        id: 'p2',
        name: 'Preset 2',
        clusterName: 'cluster-a',
        topicName: 'topic-a',
        createdAt: DateTime(2026, 1, 2),
      );

      await service.savePreset(p1);
      await service.savePreset(p2);

      var list = await service.getPresets(
        clusterName: 'cluster-a',
        topicName: 'topic-a',
      );
      expect(list.length, 2);

      await service.deletePreset(
        clusterName: 'cluster-a',
        topicName: 'topic-a',
        presetId: 'p1',
      );

      list = await service.getPresets(
        clusterName: 'cluster-a',
        topicName: 'topic-a',
      );
      expect(list.length, 1);
      expect(list.first.id, 'p2');
    });
  });
}
