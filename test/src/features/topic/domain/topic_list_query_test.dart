import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/topic/domain/topic_list_query.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';

TopicMetadata _topic(
  String name, {
  int partitions = 1,
  int rf = 1,
  int? underReplicated = 0,
  int? leaderless = 0,
  TopicMetadataError? error,
}) {
  return TopicMetadata(
    name: name,
    partitionCount: partitions,
    replicationFactor: rf,
    underReplicatedPartitions: underReplicated,
    leaderlessPartitions: leaderless,
    metadataError: error,
  );
}

void main() {
  group('internal and stream topic rules', () {
    test('orders-topic is visible when stream topics are hidden', () {
      final all = [
        _topic('orders-topic'),
        _topic('app-store-changelog'),
        _topic('app-agg-repartition'),
        _topic('__consumer_offsets'),
        _topic('_schemas'),
      ];

      final view = buildTopicListView(all, const TopicListQuery());
      expect(view.visibleTopics.map((t) => t.name), ['orders-topic']);
      expect(view.hiddenByInternal, 2);
      expect(view.hiddenByStream, 2);
      expect(view.hiddenByText, 0);
      expect(view.totalHidden, 4);
    });
  });

  group('filter modes', () {
    test('glob filter matches full name with * and ? ignoring case', () {
      final all = [
        _topic('orders.eu.v1'),
        _topic('Orders.EU.V2'),
        _topic('orders.eu.v10'),
        _topic('archive.orders.eu.v1'),
      ];

      final view = buildTopicListView(
        all,
        const TopicListQuery(text: 'orders.*.v?', mode: TopicFilterMode.glob),
      );
      expect(view.visibleTopics.map((t) => t.name), [
        'Orders.EU.V2',
        'orders.eu.v1',
      ]);
      expect(view.highlightPattern, isNull);
      expect(view.patternError, isNull);
    });

    test('regex filter matches anywhere and provides highlightPattern', () {
      final all = [
        _topic('orders.eu'),
        _topic('payments.v2'),
        _topic('billing.orders'),
      ];

      final view = buildTopicListView(
        all,
        const TopicListQuery(
          text: r'^(orders|payments)\.',
          mode: TopicFilterMode.regex,
        ),
      );
      expect(view.visibleTopics.map((t) => t.name), [
        'orders.eu',
        'payments.v2',
      ]);
      expect(view.highlightPattern, isNotNull);
      expect(view.patternError, isNull);
    });

    test('invalid regex sets patternError and disables text filtering', () {
      final all = [_topic('orders.eu'), _topic('billing.eu')];

      final view = buildTopicListView(
        all,
        const TopicListQuery(text: 'orders(', mode: TopicFilterMode.regex),
      );
      expect(view.patternError, isNotNull);
      expect(view.highlightPattern, isNull);
      expect(view.hiddenByText, 0);
      expect(view.visibleTopics, hasLength(2));
    });
  });

  group('sorting', () {
    test('sort by partitions puts unknown/error topics last', () {
      final all = [
        _topic('small', partitions: 2),
        _topic(
          'err-topic',
          partitions: 0,
          error: const TopicMetadataError(
            kind: TopicMetadataErrorKind.notAuthorized,
            message: 'denied',
          ),
        ),
        _topic('big', partitions: 12),
        _topic('alpha', partitions: 12),
      ];

      final view = buildTopicListView(
        all,
        const TopicListQuery(sort: TopicSortOrder.partitions),
      );
      expect(view.visibleTopics.map((t) => t.name), [
        'alpha',
        'big',
        'small',
        'err-topic',
      ]);
    });

    test('sort by health orders error, affected, unknown, healthy', () {
      final all = [
        _topic('healthy'),
        _topic('unknown-health', underReplicated: null, leaderless: null),
        _topic('ur-1', underReplicated: 1, leaderless: 0),
        _topic('ll-2', underReplicated: 0, leaderless: 2),
        _topic(
          'meta-err',
          error: const TopicMetadataError(
            kind: TopicMetadataErrorKind.other,
            message: 'err',
          ),
        ),
      ];

      final view = buildTopicListView(
        all,
        const TopicListQuery(sort: TopicSortOrder.health),
      );
      expect(view.visibleTopics.map((t) => t.name), [
        'meta-err',
        'll-2',
        'ur-1',
        'unknown-health',
        'healthy',
      ]);
    });
  });

  group('grouping', () {
    test('groups by first prefix with >=2 members and supports collapse', () {
      final all = [
        _topic('orders.us'),
        _topic('orders.eu'),
        _topic('orders-dlq'),
        _topic('billing'),
      ];

      final expanded = buildTopicListView(
        all,
        const TopicListQuery(groupByPrefix: true),
      );
      expect(expanded.rows[0], isA<TopicGroupHeaderRow>());
      final header = expanded.rows[0] as TopicGroupHeaderRow;
      expect(header.prefix, 'orders');
      expect(header.count, 3);
      expect(header.isCollapsed, isFalse);
      expect(expanded.rows, hasLength(5)); // header + 3 + billing

      final collapsed = buildTopicListView(
        all,
        const TopicListQuery(groupByPrefix: true, collapsedGroups: {'orders'}),
      );
      expect(collapsed.rows, hasLength(2)); // collapsed header + billing
      expect((collapsed.rows[0] as TopicGroupHeaderRow).isCollapsed, isTrue);
    });
  });

  group('favourites', () {
    test('pins favourites at top and marks missing favourites', () {
      final all = [_topic('orders.eu'), _topic('billing')];

      final view = buildTopicListView(
        all,
        const TopicListQuery(favourites: {'orders.eu', 'ghost.topic'}),
      );
      expect(view.rows[0], isA<FavouritesHeaderRow>());
      expect((view.rows[0] as FavouritesHeaderRow).count, 2);
      final firstFav = view.rows[1] as TopicItemRow;
      final secondFav = view.rows[2] as TopicItemRow;
      expect(firstFav.name, 'ghost.topic');
      expect(firstFav.isMissingFavourite, isTrue);
      expect(firstFav.topic, isNull);
      expect(secondFav.name, 'orders.eu');
      expect(secondFav.isMissingFavourite, isFalse);
    });
  });

  group('performance', () {
    test('10 000 topics with regex, health sort and grouping < 100 ms', () {
      final prefixes = ['orders', 'payments', 'billing', 'users', 'inventory'];
      final all = <TopicMetadata>[
        for (var i = 0; i < 10000; i++)
          _topic(
            '${i % 20 == 0 ? '_' : ''}${prefixes[i % prefixes.length]}.topic.$i${i % 20 == 1 ? '-changelog' : '.v${i % 10}'}',
            partitions: (i % 12) + 1,
            underReplicated: i % 100 == 0 ? 1 : 0,
            leaderless: i % 250 == 0 ? 1 : 0,
          ),
      ];
      const query = TopicListQuery(
        text: r'\.v[0-9]$',
        mode: TopicFilterMode.regex,
        sort: TopicSortOrder.health,
        groupByPrefix: true,
      );

      // Warm up JIT before measuring.
      expect(buildTopicListView(all, query).visibleTopics, isNotEmpty);

      var bestUs = 1 << 60;
      for (var run = 0; run < 5; run++) {
        final sw = Stopwatch()..start();
        final view = buildTopicListView(all, query);
        sw.stop();
        expect(view.visibleTopics, isNotEmpty);
        if (sw.elapsedMicroseconds < bestUs) {
          bestUs = sw.elapsedMicroseconds;
        }
      }
      expect(bestUs / 1000.0, lessThan(100.0));
    });
  });
}
