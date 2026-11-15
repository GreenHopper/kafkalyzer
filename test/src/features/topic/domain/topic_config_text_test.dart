import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations_en.dart';
import 'package:kafkalyzer/src/features/topic/domain/topic_config_text.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/topic_config.dart';

TopicConfigEntry _entry(
  String name,
  String? value, {
  TopicConfigSource source = TopicConfigSource.dynamicTopic,
  bool isDefault = false,
  bool isSensitive = false,
  bool isReadOnly = false,
}) => TopicConfigEntry(
  name: name,
  value: value,
  source: source,
  isDefault: isDefault,
  isSensitive: isSensitive,
  isReadOnly: isReadOnly,
);

void main() {
  final l10n = AppLocalizationsEn();

  test(
    'formatSingleTopicConfigText formats entries and sensitive placeholder',
    () {
      final entries = [
        _entry('retention.ms', '60000'),
        _entry('ssl.key.password', null, isSensitive: true),
        _entry(
          'empty.prop',
          null,
          isDefault: true,
          source: TopicConfigSource.default_,
        ),
      ];
      final snapshot = TopicConfigSnapshot(
        topic: 'orders',
        availability: TopicConfigAvailability.available,
        entries: entries,
      );

      final text = formatSingleTopicConfigText(
        profileName: 'prod',
        topicName: 'orders',
        snapshot: snapshot,
        visibleEntries: entries,
        l10n: l10n,
      );

      final lines = text.split('\n');
      expect(lines[0], 'prod / orders');
      expect(lines[1], 'Name\tValue\tSource\tDefault');
      expect(lines[2], 'retention.ms\t60000\tTopic override\tOverride');
      expect(
        lines[3],
        'ssl.key.password\thidden (sensitive)\tTopic override\tOverride',
      );
      expect(lines[4], 'empty.prop\tno value\tBuilt-in default\tDefault');
    },
  );

  test(
    'formatTopicConfigDiffText formats filtered comparison with both headers',
    () {
      final leftSnap = TopicConfigSnapshot(
        topic: 'orders',
        availability: TopicConfigAvailability.available,
        entries: [_entry('retention.ms', '60000')],
      );
      final rightSnap = TopicConfigSnapshot(
        topic: 'orders-v2',
        availability: TopicConfigAvailability.available,
        entries: [_entry('retention.ms', '120000')],
      );

      final text = formatTopicConfigDiffText(
        leftProfileName: 'dev',
        leftTopicName: 'orders',
        leftSnapshot: leftSnap,
        rightProfileName: 'prod',
        rightTopicName: 'orders-v2',
        rightSnapshot: rightSnap,
        differenceCount: 1,
        visibleRows: [
          TopicConfigDiffRow(
            name: 'retention.ms',
            left: leftSnap.entries.single,
            right: rightSnap.entries.single,
            status: TopicConfigDiffStatus.different,
            nonDefault: true,
          ),
        ],
        l10n: l10n,
      );

      expect(text, contains('dev / orders  <>  prod / orders-v2'));
      expect(text, contains('1 difference'));
      expect(
        text,
        contains(
          'retention.ms\t60000\tTopic override\t120000\tTopic override\tDifferent',
        ),
      );
    },
  );

  test(
    'formatTopicConfigDiffText includes unreadable side reason and unknown values',
    () {
      final leftSnap = TopicConfigSnapshot(
        topic: 'orders',
        availability: TopicConfigAvailability.available,
        entries: [_entry('retention.ms', '60000')],
      );
      const rightSnap = TopicConfigSnapshot(
        topic: 'orders',
        availability: TopicConfigAvailability.notAuthorized,
        entries: [],
      );

      final text = formatTopicConfigDiffText(
        leftProfileName: 'dev',
        leftTopicName: 'orders',
        leftSnapshot: leftSnap,
        rightProfileName: 'prod',
        rightTopicName: 'orders',
        rightSnapshot: rightSnap,
        differenceCount: null,
        visibleRows: [
          TopicConfigDiffRow(
            name: 'retention.ms',
            left: leftSnap.entries.single,
            right: null,
            status: TopicConfigDiffStatus.unknown,
            nonDefault: true,
          ),
        ],
        l10n: l10n,
      );

      expect(text, contains('Differences: unknown'));
      expect(
        text,
        contains(
          'prod / orders: Not readable — missing DescribeConfigs permission?',
        ),
      );
      expect(
        text,
        contains(
          'retention.ms\t60000\tTopic override\tunknown\tunknown\tUnknown',
        ),
      );
    },
  );
}
