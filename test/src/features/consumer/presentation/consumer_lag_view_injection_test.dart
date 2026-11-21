import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/consumer_lag_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';

/// Fails every group fetch, the way an unreachable broker does.
class _FailingKafkaMetadataService implements KafkaMetadataService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<ConsumerGroupLag>> fetchConsumerGroups({
    required ClusterProfile profile,
  }) async => throw Exception('broker unavailable');
}

/// Reports a connected cluster without touching the application container.
class _StubActiveConnection extends ChangeNotifier
    implements ActiveConnectionController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  ClusterProfile? get activeProfile => const ClusterProfile(
    name: 'test-cluster',
    bootstrapServers: 'localhost:9092',
    tlsVerification: TlsVerification.enabled,
  );

  @override
  bool get isConnecting => false;
}

/// Counts group fetches so a test can see work scheduled after dismissal.
class _CountingKafkaMetadataService implements KafkaMetadataService {
  int groupFetches = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<ConsumerGroupLag>> fetchConsumerGroups({
    required ClusterProfile profile,
  }) async {
    groupFetches++;
    return const [];
  }
}

void main() {
  testWidgets(
    'group fetch failure shows the error banner, not an empty group list',
    (tester) async {
      final connection = _StubActiveConnection();
      // `build` couples to the connection controller through watch_it, so that
      // one stays in the container; the Kafka service is deliberately absent so
      // the injected failing instance is the only one that can be reached.
      GetIt.instance.registerSingleton<ActiveConnectionController>(connection);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('de')],
          home: ConsumerLagView(
            activeConnection: connection,
            kafkaMetadata: _FailingKafkaMetadataService(),
            settings: SettingsService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // The failure surfaces as the error banner with its retry button, not as
      // a silently empty list.
      expect(find.textContaining('broker unavailable'), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.refresh), findsWidgets);
    },
  );

  testWidgets('a dismissed view schedules no further group fetches', (
    tester,
  ) async {
    final connection = _StubActiveConnection();
    GetIt.instance.registerSingleton<ActiveConnectionController>(connection);
    final kafka = _CountingKafkaMetadataService();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const [Locale('en'), Locale('de')],
        home: ConsumerLagView(
          activeConnection: connection,
          kafkaMetadata: kafka,
          settings: SettingsService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final fetchesWhileVisible = kafka.groupFetches;
    expect(fetchesWhileVisible, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 5));

    expect(kafka.groupFetches, fetchesWhileVisible);
  });
}
