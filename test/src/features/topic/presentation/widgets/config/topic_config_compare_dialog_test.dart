import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/ui/widgets/environment_tag.dart';
import 'package:kafkalyzer/src/ui/widgets/insecure_tls_badge.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/config/topic_config_compare_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart' as api;
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:material_ui/material_ui.dart';

class _FakeKafkaMetadataService implements KafkaMetadataService {
  int fetchTopicsCalls = 0;

  @override
  Future<List<api.TopicMetadata>> fetchTopics({
    required ClusterProfile profile,
  }) async {
    fetchTopicsCalls++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubTopicController extends TopicController {
  final Map<String, List<api.TopicMetadata>> _topicsByCluster;

  _StubTopicController(this._topicsByCluster);

  @override
  List<api.TopicMetadata>? getTopics(ClusterProfile cluster) =>
      _topicsByCluster[cluster.name];
}

ClusterProfile _profile(
  String name, {
  String? envLabel,
  TlsVerification tlsVerification = TlsVerification.enabled,
}) => ClusterProfile(
  name: name,
  bootstrapServers: 'localhost:9092',
  environmentLabel: envLabel,
  tlsVerification: tlsVerification,
);

api.TopicMetadata _topic(String name) =>
    api.TopicMetadata(name: name, partitionCount: 1, replicationFactor: 1);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  late _FakeKafkaMetadataService fakeMetadata;

  setUp(() {
    fakeMetadata = _FakeKafkaMetadataService();
    getIt.registerSingleton<KafkaMetadataService>(fakeMetadata);
  });

  tearDown(() async {});

  testWidgets(
    'defaults to current profile and open topic name, and shows insecure badge',
    (tester) async {
      final current = _profile(
        'prod',
        envLabel: 'PROD',
        tlsVerification: TlsVerification.disabled,
      );
      final staging = _profile('staging');
      TopicConfigCompareSelection? result;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showTopicConfigCompareDialog(
                  context: context,
                  currentProfile: current,
                  openTopicName: 'orders',
                  clusters: [staging, current],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Current profile + environment tag + insecure TLS badge visible.
      expect(find.byType(EnvironmentTagChip), findsWidgets);
      expect(find.byType(InsecureTlsBadge), findsWidgets);
      expect(find.text('orders'), findsOneWidget);

      // Submit immediately without changing anything -> returns (current, 'orders').
      await tester.tap(find.text('Compare'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.$1.name, 'prod');
      expect(result!.$2, 'orders');
    },
  );

  testWidgets(
    'uses only cached topics from TopicController without calling fetchTopics',
    (tester) async {
      final current = _profile('prod');
      final controller = _StubTopicController({
        'prod': [_topic('orders'), _topic('orders-dlq'), _topic('payments')],
      });
      getIt.registerSingleton<TopicController>(controller);

      await tester.pumpWidget(
        _wrap(
          TopicConfigCompareDialog(
            currentProfile: current,
            openTopicName: 'orders',
            clusters: [current],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Filter autocomplete to "orders"
      final textField = find.byType(TextField).last;
      await tester.tap(textField);
      await tester.enterText(textField, 'ord');
      await tester.pumpAndSettle();

      expect(find.text('orders'), findsOneWidget);
      expect(find.text('orders-dlq'), findsOneWidget);
      expect(find.text('payments'), findsNothing);
      expect(fakeMetadata.fetchTopicsCalls, 0);
    },
  );
}
