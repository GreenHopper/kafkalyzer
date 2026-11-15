import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_config_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/topic_config.dart';
import 'package:kafkalyzer/src/services/topic_config_service.dart';

class _FakeTopicConfigService implements TopicConfigService {
  final List<(String, String)> fetchedCalls = [];
  Future<TopicConfigSnapshot> Function(ClusterProfile profile, String topic)?
  onFetch;

  @override
  Future<TopicConfigSnapshot> fetchTopicConfig({
    required ClusterProfile profile,
    required String topic,
  }) {
    fetchedCalls.add((profile.name, topic));
    return onFetch!(profile, topic);
  }

  @override
  TopicConfigDiff diffTopicConfigs({
    required TopicConfigSnapshot left,
    required TopicConfigSnapshot right,
  }) {
    if (left.availability != TopicConfigAvailability.available &&
        right.availability != TopicConfigAvailability.available) {
      return const TopicConfigDiff(rows: [], differenceCount: null);
    }
    if (left.availability != TopicConfigAvailability.available) {
      return TopicConfigDiff(
        rows: [
          for (final r in right.entries)
            TopicConfigDiffRow(
              name: r.name,
              left: null,
              right: r,
              status: TopicConfigDiffStatus.unknown,
              nonDefault: !r.isDefault,
            ),
        ],
        differenceCount: null,
      );
    }
    if (right.availability != TopicConfigAvailability.available) {
      return TopicConfigDiff(
        rows: [
          for (final l in left.entries)
            TopicConfigDiffRow(
              name: l.name,
              left: l,
              right: null,
              status: TopicConfigDiffStatus.unknown,
              nonDefault: !l.isDefault,
            ),
        ],
        differenceCount: null,
      );
    }
    final rows = <TopicConfigDiffRow>[];
    var diffs = 0;
    final rMap = {for (final e in right.entries) e.name: e};
    for (final l in left.entries) {
      final r = rMap.remove(l.name);
      if (r == null) {
        diffs++;
        rows.add(
          TopicConfigDiffRow(
            name: l.name,
            left: l,
            right: null,
            status: TopicConfigDiffStatus.onlyLeft,
            nonDefault: !l.isDefault,
          ),
        );
      } else {
        final same = l.value == r.value;
        if (!same) diffs++;
        rows.add(
          TopicConfigDiffRow(
            name: l.name,
            left: l,
            right: r,
            status: same
                ? TopicConfigDiffStatus.equal
                : TopicConfigDiffStatus.different,
            nonDefault: !l.isDefault || !r.isDefault,
          ),
        );
      }
    }
    return TopicConfigDiff(rows: rows, differenceCount: diffs);
  }
}

ClusterProfile _profile(String name) => ClusterProfile(
  name: name,
  bootstrapServers: 'localhost:9092',
  tlsVerification: TlsVerification.disabled,
);

TopicConfigEntry _entry(String name, String? value, {bool isDefault = false}) =>
    TopicConfigEntry(
      name: name,
      value: value,
      source: isDefault
          ? TopicConfigSource.default_
          : TopicConfigSource.dynamicTopic,
      isDefault: isDefault,
      isSensitive: false,
      isReadOnly: false,
    );

void main() {
  late _FakeTopicConfigService fakeService;
  late TopicConfigController controller;

  setUp(() {
    fakeService = _FakeTopicConfigService();
    controller = TopicConfigController(
      leftProfile: _profile('dev'),
      leftTopic: 'orders',
      service: fakeService,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('ignores stale result after refresh', () async {
    final first = Completer<TopicConfigSnapshot>();
    final second = Completer<TopicConfigSnapshot>();
    var call = 0;
    fakeService.onFetch = (_, _) {
      call++;
      return call == 1 ? first.future : second.future;
    };

    controller.ensureLoaded();
    final refreshFuture = controller.refresh();

    second.complete(
      TopicConfigSnapshot(
        topic: 'orders',
        availability: TopicConfigAvailability.available,
        entries: [_entry('retention.ms', '2000')],
      ),
    );
    await refreshFuture;

    first.complete(
      TopicConfigSnapshot(
        topic: 'orders',
        availability: TopicConfigAvailability.available,
        entries: [_entry('retention.ms', '1000')],
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.left.snapshot?.entries.single.value, '2000');
  });

  test('ignores result arriving after dispose', () async {
    final completer = Completer<TopicConfigSnapshot>();
    fakeService.onFetch = (_, _) => completer.future;

    final local = TopicConfigController(
      leftProfile: _profile('dev'),
      leftTopic: 'orders',
      service: fakeService,
    );
    var notifications = 0;
    local.addListener(() => notifications++);
    local.ensureLoaded();
    expect(notifications, 1);

    local.dispose();
    completer.complete(
      TopicConfigSnapshot(
        topic: 'orders',
        availability: TopicConfigAvailability.available,
        entries: [_entry('retention.ms', '1000')],
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(notifications, 1);
  });

  test(
    'one side NotAuthorized gives differenceCount == null and retry only re-reads failed side',
    () async {
      var prodCalls = 0;
      fakeService.onFetch = (profile, topic) async {
        if (profile.name == 'dev') {
          return TopicConfigSnapshot(
            topic: topic,
            availability: TopicConfigAvailability.available,
            entries: [_entry('retention.ms', '60000')],
          );
        }
        prodCalls++;
        if (prodCalls == 1) {
          return TopicConfigSnapshot(
            topic: topic,
            availability: TopicConfigAvailability.notAuthorized,
            entries: const [],
          );
        }
        return TopicConfigSnapshot(
          topic: topic,
          availability: TopicConfigAvailability.available,
          entries: [_entry('retention.ms', '120000')],
        );
      };

      await controller.refresh();
      await controller.startComparison(_profile('prod'), 'orders');

      expect(controller.diff?.differenceCount, isNull);
      expect(
        controller.diff?.rows.single.status,
        TopicConfigDiffStatus.unknown,
      );
      expect(fakeService.fetchedCalls, [('dev', 'orders'), ('prod', 'orders')]);

      await controller.retryRight();
      expect(fakeService.fetchedCalls, [
        ('dev', 'orders'),
        ('prod', 'orders'),
        ('prod', 'orders'),
      ]);
      expect(controller.diff?.differenceCount, 1);
      expect(
        controller.diff?.rows.single.status,
        TopicConfigDiffStatus.different,
      );
    },
  );

  test('toggling nonDefaultOnly filters without calling service', () async {
    fakeService.onFetch = (_, topic) async => TopicConfigSnapshot(
      topic: topic,
      availability: TopicConfigAvailability.available,
      entries: [
        _entry('a.default', '1', isDefault: true),
        _entry('b.override', '2', isDefault: false),
      ],
    );

    await controller.refresh();
    expect(controller.visibleSingleEntries.length, 2);

    controller.toggleNonDefaultOnly();
    expect(controller.nonDefaultOnly, isTrue);
    expect(controller.visibleSingleEntries.length, 1);
    expect(controller.visibleSingleEntries.single.name, 'b.override');
    expect(fakeService.fetchedCalls.length, 1);
  });
}
