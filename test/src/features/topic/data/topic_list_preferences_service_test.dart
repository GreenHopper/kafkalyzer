import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/topic/domain/topic_list_query.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_list_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('round trip saves and restores per cluster', () async {
    SharedPreferences.setMockInitialValues({});
    final service = TopicListPreferencesService();

    const saved = TopicListPreferences(
      showInternal: true,
      showStream: true,
      filterMode: TopicFilterMode.regex,
      sort: TopicSortOrder.health,
      groupByPrefix: true,
      favourites: {'orders.eu', 'payments.v1'},
    );

    expect(await service.save('prod', saved), isTrue);

    final loaded = await service.load('prod');
    expect(loaded.unreadable, isFalse);
    expect(loaded.preferences.showInternal, isTrue);
    expect(loaded.preferences.showStream, isTrue);
    expect(loaded.preferences.filterMode, TopicFilterMode.regex);
    expect(loaded.preferences.sort, TopicSortOrder.health);
    expect(loaded.preferences.groupByPrefix, isTrue);
    expect(loaded.preferences.favourites, {'orders.eu', 'payments.v1'});
  });

  test('missing key returns defaults without unreadable flag', () async {
    SharedPreferences.setMockInitialValues({});
    final service = TopicListPreferencesService();

    final loaded = await service.load('staging');
    expect(loaded.unreadable, isFalse);
    expect(loaded.preferences.showInternal, isFalse);
    expect(loaded.preferences.showStream, isFalse);
    expect(loaded.preferences.filterMode, TopicFilterMode.substring);
    expect(loaded.preferences.sort, TopicSortOrder.name);
    expect(loaded.preferences.groupByPrefix, isFalse);
    expect(loaded.preferences.favourites, isEmpty);
  });

  test('unknown enum values fall back to defaults', () async {
    SharedPreferences.setMockInitialValues({
      'topic_list_prefs_prod':
          '{"version":1,"filterMode":"fuzzy","sort":"size","showInternal":true}',
    });
    final service = TopicListPreferencesService();

    final loaded = await service.load('prod');
    expect(loaded.unreadable, isFalse);
    expect(loaded.preferences.showInternal, isTrue);
    expect(loaded.preferences.filterMode, TopicFilterMode.substring);
    expect(loaded.preferences.sort, TopicSortOrder.name);
  });

  test(
    'invalid JSON marks unreadable and writes backup before first overwrite',
    () async {
      SharedPreferences.setMockInitialValues({
        'topic_list_prefs_prod': '{not-valid-json',
      });
      final backups = <(String, String)>[];
      final service = TopicListPreferencesService(
        backupWriter: (key, raw) async {
          backups.add((key, raw));
          return '/tmp/backup.json';
        },
      );

      final loaded = await service.load('prod');
      expect(loaded.unreadable, isTrue);
      expect(loaded.preferences.filterMode, TopicFilterMode.substring);
      expect(backups, isEmpty);

      final saved = await service.save(
        'prod',
        const TopicListPreferences(showInternal: true),
      );
      expect(saved, isTrue);
      expect(backups, [('topic_list_prefs_prod', '{not-valid-json')]);
    },
  );

  test('backup returning null prevents overwriting unreadable value', () async {
    SharedPreferences.setMockInitialValues({
      'topic_list_prefs_prod': 'corrupt-data',
    });
    final service = TopicListPreferencesService(
      backupWriter: (_, _) async => null,
    );

    final loaded = await service.load('prod');
    expect(loaded.unreadable, isTrue);

    final saved = await service.save(
      'prod',
      const TopicListPreferences(showInternal: true),
    );
    expect(saved, isFalse);
    expect(service.isWriteBlocked('prod'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('topic_list_prefs_prod'), 'corrupt-data');
  });
}
