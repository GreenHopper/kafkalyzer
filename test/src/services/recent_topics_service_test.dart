import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/services/recent_topics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecentTopicsService', () {
    late SharedPreferences prefs;
    late RecentTopicsService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = RecentTopicsService(prefs: prefs);
      await service.loadRecentTopics();
    });

    test('starts with empty list when no preferences saved', () {
      expect(service.recentTopics, isEmpty);
      expect(service.getRecentTopics(clusterName: 'PROD'), isEmpty);
    });

    test('records topic visit and persists to SharedPreferences', () async {
      await service.recordVisit(clusterName: 'PROD', topicName: 'orders');

      expect(service.recentTopics.length, 1);
      expect(service.recentTopics.first.clusterName, 'PROD');
      expect(service.recentTopics.first.topicName, 'orders');

      // Verify loaded in new instance
      final newService = RecentTopicsService(prefs: prefs);
      await newService.loadRecentTopics();
      expect(newService.recentTopics.length, 1);
      expect(newService.recentTopics.first.topicName, 'orders');
    });

    test('moves duplicate visit to front without duplicating', () async {
      await service.recordVisit(clusterName: 'PROD', topicName: 'topicA');
      await service.recordVisit(clusterName: 'PROD', topicName: 'topicB');
      expect(service.recentTopics.map((e) => e.topicName).toList(), [
        'topicB',
        'topicA',
      ]);

      // Re-visit topicA
      await service.recordVisit(clusterName: 'PROD', topicName: 'topicA');
      expect(service.recentTopics.length, 2);
      expect(service.recentTopics.map((e) => e.topicName).toList(), [
        'topicA',
        'topicB',
      ]);
    });

    test('filters recent topics by clusterName', () async {
      await service.recordVisit(clusterName: 'PROD', topicName: 'prod-topic');
      await service.recordVisit(clusterName: 'DEV', topicName: 'dev-topic');

      expect(service.getRecentTopics(clusterName: 'PROD').length, 1);
      expect(
        service.getRecentTopics(clusterName: 'PROD').first.topicName,
        'prod-topic',
      );

      expect(service.getRecentTopics(clusterName: 'DEV').length, 1);
      expect(
        service.getRecentTopics(clusterName: 'DEV').first.topicName,
        'dev-topic',
      );

      expect(service.getRecentTopics().length, 2);
    });

    test('enforces maxRecentTopics limit of 10 items (LRU)', () async {
      for (int i = 0; i < 15; i++) {
        await service.recordVisit(clusterName: 'PROD', topicName: 'topic-$i');
      }

      expect(service.recentTopics.length, RecentTopicsService.maxRecentTopics);
      // Newest should be topic-14, oldest in list should be topic-5
      expect(service.recentTopics.first.topicName, 'topic-14');
      expect(service.recentTopics.last.topicName, 'topic-5');
    });

    test('removes entry and clears history', () async {
      await service.recordVisit(clusterName: 'PROD', topicName: 'topicA');
      await service.recordVisit(clusterName: 'PROD', topicName: 'topicB');

      await service.removeEntry('PROD', 'topicA');
      expect(service.recentTopics.length, 1);
      expect(service.recentTopics.first.topicName, 'topicB');

      await service.clearHistory();
      expect(service.recentTopics, isEmpty);
    });
  });
}
