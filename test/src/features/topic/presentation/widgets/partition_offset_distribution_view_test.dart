import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/partition_offset_distribution_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeKafkaMetadataService implements KafkaMetadataService {
  Future<PartitionOffsetDistribution> Function({
    required ClusterProfile profile,
    required String topic,
    int? skewThresholdPercent,
  })?
  onFetchPartitionOffsets;

  int fetchPartitionOffsetsCallCount = 0;
  int? lastThreshold;

  @override
  Future<PartitionOffsetDistribution> fetchPartitionOffsets({
    required ClusterProfile profile,
    required String topic,
    int? skewThresholdPercent,
  }) {
    fetchPartitionOffsetsCallCount++;
    lastThreshold = skewThresholdPercent;
    return onFetchPartitionOffsets!(
      profile: profile,
      topic: topic,
      skewThresholdPercent: skewThresholdPercent,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeActiveConnectionController extends ChangeNotifier
    implements ActiveConnectionController {
  ClusterProfile? _activeProfile;

  _FakeActiveConnectionController(this._activeProfile);

  @override
  ClusterProfile? get activeProfile => _activeProfile;

  void setProfile(ClusterProfile? profile) {
    _activeProfile = profile;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClusterProfile _profile(String name) => ClusterProfile(
  name: name,
  bootstrapServers: 'localhost:9092',
  tlsVerification: TlsVerification.disabled,
);

PartitionOffsetDistribution _dist({
  String topic = 'orders',
  int readAtMs = 1700000000000,
  required List<PartitionOffsetRow> partitions,
  int? totalSpan,
  int knownSpan = 0,
  bool complete = true,
  OffsetSkewStatus skewStatus = OffsetSkewStatus.balanced,
  int? skewThresholdPercent = 50,
}) {
  return PartitionOffsetDistribution(
    topic: topic,
    readAtMs: readAtMs,
    partitions: partitions,
    totalSpan: totalSpan,
    knownSpan: knownSpan,
    complete: complete,
    skewStatus: skewStatus,
    skewThresholdPercent: skewThresholdPercent,
  );
}

Widget _wrap({
  required ClusterProfile profile,
  String topicName = 'orders',
  String? cleanupPolicy = 'delete',
  VoidCallback? onOpenAnalysis,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: PartitionOffsetDistributionView(
          profile: profile,
          topicName: topicName,
          cleanupPolicy: cleanupPolicy,
          onOpenAnalysis: onOpenAnalysis,
        ),
      ),
    ),
  );
}

void main() {
  late _FakeKafkaMetadataService fakeMetadata;
  late _FakeActiveConnectionController fakeConnection;
  final clusterA = _profile('cluster-a');
  final clusterB = _profile('cluster-b');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GetIt.instance.reset();
    fakeMetadata = _FakeKafkaMetadataService();
    fakeConnection = _FakeActiveConnectionController(clusterA);
    GetIt.instance.registerSingleton<KafkaMetadataService>(fakeMetadata);
    GetIt.instance.registerSingleton<ActiveConnectionController>(
      fakeConnection,
    );
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  testWidgets('shows loading then renders known rows, span, share, and note', (
    tester,
  ) async {
    final completer = Completer<PartitionOffsetDistribution>();
    fakeMetadata.onFetchPartitionOffsets =
        ({required profile, required topic, skewThresholdPercent}) =>
            completer.future;

    await tester.pumpWidget(_wrap(profile: clusterA));
    await tester.pump();
    expect(find.byKey(const Key('partition_offset_loading')), findsOneWidget);

    completer.complete(
      _dist(
        partitions: const [
          PartitionOffsetRow(
            partition: 0,
            state: PartitionOffsetState.known,
            low: 10,
            high: 110,
            span: 100,
            sharePercent: 60.0,
            skewed: true,
          ),
          PartitionOffsetRow(
            partition: 1,
            state: PartitionOffsetState.known,
            low: 0,
            high: 67,
            span: 67,
            sharePercent: 40.0,
            skewed: false,
          ),
        ],
        totalSpan: 167,
        knownSpan: 167,
        skewStatus: OffsetSkewStatus.skewed,
        skewThresholdPercent: 50,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('partition_offset_loading')), findsNothing);
    expect(find.text('Estimated distribution (offset span)'), findsOneWidget);
    expect(find.text('Total offset span: 167'), findsOneWidget);
    expect(
      find.byKey(const Key('partition_offset_estimate_note')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('partition_offset_skew_badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('partition_offset_skew_icon_0')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('partition_offset_skew_icon_1')), findsNothing);
    expect(find.text('60.0%'), findsOneWidget);
    expect(find.text('40.0%'), findsOneWidget);
    expect(find.byKey(const Key('partition_offset_read_at')), findsOneWidget);
    expect(
      find.byKey(const Key('partition_offset_compacted_note')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('partition_offset_policy_unknown_note')),
      findsNothing,
    );
  });

  testWidgets('initial error shows inline error and retry refetches', (
    tester,
  ) async {
    var fail = true;
    fakeMetadata.onFetchPartitionOffsets =
        ({required profile, required topic, skewThresholdPercent}) async {
          if (fail) throw Exception('broker unreachable');
          return _dist(
            partitions: const [
              PartitionOffsetRow(
                partition: 0,
                state: PartitionOffsetState.known,
                low: 0,
                high: 5,
                span: 5,
                sharePercent: 100.0,
                skewed: false,
              ),
            ],
            totalSpan: 5,
            knownSpan: 5,
            skewStatus: OffsetSkewStatus.singlePartition,
          );
        };

    await tester.pumpWidget(_wrap(profile: clusterA));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('partition_offset_error')), findsOneWidget);
    expect(find.textContaining('broker unreachable'), findsOneWidget);

    fail = false;
    await tester.tap(find.byKey(const Key('partition_offset_retry_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('partition_offset_error')), findsNothing);
    expect(find.byKey(const Key('partition_offset_row_0')), findsOneWidget);
    expect(fakeMetadata.fetchPartitionOffsetsCallCount, 2);
  });

  testWidgets('refresh is single-flight and preserves prior data on failure', (
    tester,
  ) async {
    var call = 0;
    Completer<PartitionOffsetDistribution>? refreshCompleter;
    fakeMetadata.onFetchPartitionOffsets =
        ({required profile, required topic, skewThresholdPercent}) {
          call++;
          if (call == 1) {
            return Future.value(
              _dist(
                partitions: const [
                  PartitionOffsetRow(
                    partition: 0,
                    state: PartitionOffsetState.known,
                    low: 0,
                    high: 10,
                    span: 10,
                    sharePercent: 100.0,
                    skewed: false,
                  ),
                ],
                totalSpan: 10,
                knownSpan: 10,
                skewStatus: OffsetSkewStatus.singlePartition,
              ),
            );
          }
          refreshCompleter = Completer<PartitionOffsetDistribution>();
          return refreshCompleter!.future;
        };

    await tester.pumpWidget(_wrap(profile: clusterA));
    await tester.pumpAndSettle();
    expect(fakeMetadata.fetchPartitionOffsetsCallCount, 1);

    // Tap refresh twice while in flight -> single flight
    await tester.tap(find.byKey(const Key('partition_offset_refresh_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('partition_offset_refresh_button')));
    await tester.pump();
    expect(fakeMetadata.fetchPartitionOffsetsCallCount, 2);

    refreshCompleter!.completeError(Exception('timeout'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('partition_offset_refresh_error')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('partition_offset_row_0')), findsOneWidget);
  });

  testWidgets('shows compaction note for compact and unknown-policy for null', (
    tester,
  ) async {
    fakeMetadata.onFetchPartitionOffsets =
        ({required profile, required topic, skewThresholdPercent}) async =>
            _dist(
              partitions: const [
                PartitionOffsetRow(
                  partition: 0,
                  state: PartitionOffsetState.known,
                  low: 0,
                  high: 0,
                  span: 0,
                  sharePercent: null,
                  skewed: false,
                ),
              ],
              totalSpan: 0,
              knownSpan: 0,
              skewStatus: OffsetSkewStatus.empty,
            );

    await tester.pumpWidget(
      _wrap(profile: clusterA, cleanupPolicy: 'delete,compact'),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('partition_offset_compacted_note')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('partition_offset_empty_note')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('partition_offset_skew_badge')), findsNothing);

    await tester.pumpWidget(_wrap(profile: clusterA, cleanupPolicy: null));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('partition_offset_policy_unknown_note')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('partition_offset_compacted_note')),
      findsNothing,
    );
  });

  testWidgets('incomplete read shows unknown values, row states, and note', (
    tester,
  ) async {
    fakeMetadata.onFetchPartitionOffsets =
        ({required profile, required topic, skewThresholdPercent}) async =>
            _dist(
              partitions: const [
                PartitionOffsetRow(
                  partition: 0,
                  state: PartitionOffsetState.known,
                  low: 1,
                  high: 11,
                  span: 10,
                  sharePercent: null,
                  skewed: false,
                ),
                PartitionOffsetRow(
                  partition: 1,
                  state: PartitionOffsetState.notReadable,
                  error: 'ACL denied',
                  skewed: false,
                ),
                PartitionOffsetRow(
                  partition: 2,
                  state: PartitionOffsetState.failed,
                  error: 'broker error',
                  skewed: false,
                ),
                PartitionOffsetRow(
                  partition: 3,
                  state: PartitionOffsetState.timedOut,
                  skewed: false,
                ),
              ],
              totalSpan: null,
              knownSpan: 10,
              complete: false,
              skewStatus: OffsetSkewStatus.incomplete,
            );

    await tester.pumpWidget(_wrap(profile: clusterA));
    await tester.pumpAndSettle();

    expect(find.text('Known offset span: 10'), findsOneWidget);
    expect(
      find.byKey(const Key('partition_offset_incomplete_note')),
      findsOneWidget,
    );
    expect(find.text('Offsets not readable — permission?'), findsOneWidget);
    expect(find.text('Read failed'), findsOneWidget);
    expect(find.text('Timed out'), findsOneWidget);
    expect(find.byKey(const Key('partition_offset_skew_badge')), findsNothing);
  });

  testWidgets('reads skew threshold setting and invokes onOpenAnalysis', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SettingsService.partitionSkewThresholdSetting.key: 75,
    });
    var openedAnalysis = false;
    fakeMetadata.onFetchPartitionOffsets =
        ({required profile, required topic, skewThresholdPercent}) async =>
            _dist(
              partitions: const [
                PartitionOffsetRow(
                  partition: 0,
                  state: PartitionOffsetState.known,
                  low: 0,
                  high: 50,
                  span: 50,
                  sharePercent: 50.0,
                  skewed: false,
                ),
                PartitionOffsetRow(
                  partition: 1,
                  state: PartitionOffsetState.known,
                  low: 0,
                  high: 50,
                  span: 50,
                  sharePercent: 50.0,
                  skewed: false,
                ),
              ],
              totalSpan: 100,
              knownSpan: 100,
              skewStatus: OffsetSkewStatus.balanced,
              skewThresholdPercent: skewThresholdPercent,
            );

    await tester.pumpWidget(
      _wrap(profile: clusterA, onOpenAnalysis: () => openedAnalysis = true),
    );
    await tester.pumpAndSettle();

    expect(fakeMetadata.lastThreshold, 75);
    expect(find.byKey(const Key('partition_offset_skew_badge')), findsNothing);

    await tester.tap(
      find.byKey(const Key('partition_offset_open_analysis_button')),
    );
    await tester.pump();
    expect(openedAnalysis, isTrue);
  });

  testWidgets(
    'marks view stale when active connection switches or disconnects',
    (tester) async {
      fakeMetadata.onFetchPartitionOffsets =
          ({required profile, required topic, skewThresholdPercent}) async =>
              _dist(
                partitions: const [
                  PartitionOffsetRow(
                    partition: 0,
                    state: PartitionOffsetState.known,
                    low: 0,
                    high: 10,
                    span: 10,
                    sharePercent: 100.0,
                    skewed: false,
                  ),
                ],
                totalSpan: 10,
                knownSpan: 10,
                skewStatus: OffsetSkewStatus.singlePartition,
              );

      await tester.pumpWidget(_wrap(profile: clusterA));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('partition_offset_stale_banner')),
        findsNothing,
      );

      fakeConnection.setProfile(clusterB);
      await tester.pump();
      expect(
        find.byKey(const Key('partition_offset_stale_banner')),
        findsOneWidget,
      );

      fakeConnection.setProfile(clusterA);
      await tester.pump();
      expect(
        find.byKey(const Key('partition_offset_stale_banner')),
        findsNothing,
      );

      fakeConnection.setProfile(null);
      await tester.pump();
      expect(
        find.byKey(const Key('partition_offset_stale_banner')),
        findsOneWidget,
      );
    },
  );

  testWidgets('lazily builds 1000-partition list without building all rows', (
    tester,
  ) async {
    final rows = List.generate(
      1000,
      (i) => PartitionOffsetRow(
        partition: i,
        state: PartitionOffsetState.known,
        low: 0,
        high: 10,
        span: 10,
        sharePercent: 0.1,
        skewed: false,
      ),
    );
    fakeMetadata.onFetchPartitionOffsets =
        ({required profile, required topic, skewThresholdPercent}) async =>
            _dist(
              partitions: rows,
              totalSpan: 10000,
              knownSpan: 10000,
              skewStatus: OffsetSkewStatus.balanced,
            );

    await tester.pumpWidget(_wrap(profile: clusterA));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('partition_offset_row_0')), findsOneWidget);
    expect(find.byKey(const Key('partition_offset_row_999')), findsNothing);
  });

  testWidgets('renders German labels when locale is de', (tester) async {
    fakeMetadata.onFetchPartitionOffsets =
        ({required profile, required topic, skewThresholdPercent}) async =>
            _dist(
              partitions: const [
                PartitionOffsetRow(
                  partition: 0,
                  state: PartitionOffsetState.known,
                  low: 0,
                  high: 10,
                  span: 10,
                  sharePercent: 100.0,
                  skewed: false,
                ),
              ],
              totalSpan: 10,
              knownSpan: 10,
              skewStatus: OffsetSkewStatus.singlePartition,
            );

    await tester.pumpWidget(
      _wrap(profile: clusterA, locale: const Locale('de')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Geschätzte Verteilung (Offset-Spanne)'), findsOneWidget);
  });
}
