import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:kafkalyzer/src/services/local_schema_assignment_service.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const profile = ClusterProfile(
    name: 'prod',
    bootstrapServers: 'localhost:9092',
    tlsVerification: TlsVerification.unreviewed,
  );
  const avroAssignment = LocalSchemaAssignmentDto(
    path: '/schemas/orders.avsc',
    format: LocalSchemaFormatDto.avro,
    framing: FramingDto.auto,
    mode: LocalSchemaModeDto.fallback,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    getIt.registerLazySingleton<Logger>(() => Logger(level: Level.off));
  });

  tearDown(() async {});

  test(
    'MessageStreamController forwards localSchemas when assigned and null otherwise',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final localSvc = LocalSchemaAssignmentService(prefs: prefs);
      await localSvc.saveSide(
        'prod',
        'orders',
        LocalSchemaSide.value,
        avroAssignment,
      );

      final captured = <TopicLocalSchemasDto?>[];
      final controller = MessageStreamController(
        localSchemaService: localSvc,
        consumeStreamFactory:
            ({
              required profile,
              required topic,
              filterTerms,
              filterField,
              required filterType,
              required searchScope,
              filterExpression,
              filterVariables,
              fastTraceKey,
              startOffset,
              startTimestamp,
              startPartition,
              maxResults,
              endOffset,
              endTimestamp,
              required runForever,
              bool? startFromTail,
              TopicLocalSchemasDto? localSchemas,
            }) {
              captured.add(localSchemas);
              return const Stream.empty();
            },
      );

      await controller.startStreaming(
        profile,
        'orders',
        filterType: FilterType.contains,
        searchScope: SearchScope.both,
      );
      await controller.startStreaming(
        profile,
        'unassigned',
        filterType: FilterType.contains,
        searchScope: SearchScope.both,
      );

      expect(captured.length, 2);
      expect(captured[0]?.value, equals(avroAssignment));
      expect(captured[1], isNull);
      controller.dispose();
    },
  );

  test('MultiSearchController and ScriptRunner forward localSchemas', () async {
    final prefs = await SharedPreferences.getInstance();
    final localSvc = LocalSchemaAssignmentService(prefs: prefs);
    await localSvc.saveSide(
      'prod',
      'orders',
      LocalSchemaSide.value,
      avroAssignment,
    );

    final captured = <TopicLocalSchemasDto?>[];
    final multi = MultiSearchController(
      localSchemaService: localSvc,
      consumeStreamFactory:
          ({
            required profile,
            required topic,
            filterTerms,
            filterField,
            required filterType,
            required searchScope,
            filterExpression,
            filterVariables,
            fastTraceKey,
            startOffset,
            startTimestamp,
            startPartition,
            maxResults,
            endOffset,
            endTimestamp,
            required runForever,
            bool? startFromTail,
            TopicLocalSchemasDto? localSchemas,
          }) {
            captured.add(localSchemas);
            return Stream.fromIterable([
              const KafkaMessage(
                topic: 'orders',
                partition: 0,
                offset: 1,
                key: 'k1',
                payload: '{"id":"1"}',
                timestamp: 1000,
              ),
            ]);
          },
    );

    multi.addTarget(
      SearchTarget(
        profile: profile,
        topic: const TopicMetadata(
          name: 'orders',
          partitionCount: 1,
          replicationFactor: 1,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(captured.single?.value, equals(avroAssignment));

    // ScriptRunner step (register full DI container as headless does, overriding MultiSearchController)
    captured.clear();
    await getIt.reset();
    getIt.allowReassignment = true;
    setupDependencyInjection();
    getIt.registerSingleton<Logger>(Logger(level: Level.off));
    getIt.registerSingleton<LocalSchemaAssignmentService>(localSvc);
    getIt.registerSingleton<MultiSearchController>(multi);

    final runner = ScriptRunner(multiSearchController: multi);
    final script = Script(
      id: 's1',
      name: 'local-schema-step',
      steps: [
        const ScriptStep(
          id: 'step1',
          name: 'step1',
          clusterName: 'prod',
          topicNames: ['orders'],
        ),
      ],
    );
    await runner.runScript(script, const {}, overrideCluster: profile);
    expect(captured.single?.value, equals(avroAssignment));
    multi.dispose();
  });

  test(
    'TopicAnalysisController forwards localSchemas in TopicAnalysisOptions',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final localSvc = LocalSchemaAssignmentService(prefs: prefs);
      await localSvc.saveSide(
        'prod',
        'orders',
        LocalSchemaSide.value,
        avroAssignment,
      );

      TopicAnalysisOptions? capturedOpts;
      final controller = TopicAnalysisController(
        localSchemaService: localSvc,
        streamFactory: ({required profile, required topic, required options}) {
          capturedOpts = options;
          return const Stream.empty();
        },
      );

      await controller.startAnalysis(profile, 'orders');
      expect(capturedOpts?.localSchemas?.value, equals(avroAssignment));
      controller.dispose();
    },
  );
}
