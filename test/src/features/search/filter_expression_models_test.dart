import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/search/domain/search_json_serializer.dart';
import 'package:kafkalyzer/src/features/search/models/topic_search_preset.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:logger/logger.dart';

void main() {
  setUpAll(() {
    getIt.registerSingleton<Logger>(Logger(level: Level.off));
  });

  group('5.1 TopicSearchPreset & ScriptStep filterExpression', () {
    test(
      'TopicSearchPreset loads legacy JSON without filterExpression and round-trips',
      () {
        final legacy = TopicSearchPreset.fromJson({
          'id': 'p1',
          'name': 'Legacy',
          'clusterName': 'local',
          'topicName': 'orders',
          'filterTerm': 'err',
        });
        expect(legacy.filterExpression, '');
        expect(legacy.filterTerm, 'err');

        final updated = legacy.copyWith(
          filterExpression: 'value.status = "FAILED"',
        );
        final reloaded = TopicSearchPreset.fromJson(updated.toJson());
        expect(reloaded.filterExpression, 'value.status = "FAILED"');
      },
    );

    test(
      'ScriptStep loads legacy JSON without filterExpression and round-trips',
      () {
        final legacy = ScriptStep.fromJson({
          'id': 's1',
          'name': 'Step 1',
          'clusterName': 'local',
          'topicNames': ['orders'],
        });
        expect(legacy.filterExpression, isNull);

        final updated = legacy.copyWith(filterExpression: 'header.x = {{id}}');
        final renamed = updated.replaceVariable('id', 'orderId');
        expect(renamed.filterExpression, 'header.x = {{orderId}}');
        final reloaded = ScriptStep.fromJson(renamed.toJson());
        expect(reloaded.filterExpression, 'header.x = {{orderId}}');
      },
    );
  });

  group('5.2 SearchTarget, controllers, serializer', () {
    final profile = ClusterProfile(
      name: 'local',
      bootstrapServers: 'localhost:9092',
      tlsVerification: TlsVerification.unreviewed,
    );
    const topic = TopicMetadata(
      name: 'orders',
      partitionCount: 1,
      replicationFactor: 1,
    );

    test(
      'SearchTarget forwards filterExpression and filterVariables via MultiSearchController',
      () async {
        String? capturedExpr;
        Map<String, List<String>>? capturedVars;
        final controller = MultiSearchController(
          bufferLimitProvider: () => 100,
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
                startFromTail,
                localSchemas,
              }) {
                capturedExpr = filterExpression;
                capturedVars = filterVariables;
                return const Stream.empty();
              },
        );
        addTearDown(controller.dispose);

        final target = SearchTarget(
          profile: profile,
          topic: topic,
          filterExpression: 'value.id = {{ids}}',
          filterVariables: {
            'ids': ['A1', 'B2'],
          },
        );
        controller.addTarget(target);
        await Future<void>.delayed(Duration.zero);

        expect(capturedExpr, 'value.id = {{ids}}');
        expect(capturedVars, {
          'ids': ['A1', 'B2'],
        });
        expect(
          SearchJsonSerializer.serializeTarget(target)['filterExpression'],
          'value.id = {{ids}}',
        );
      },
    );

    test(
      'MessageStreamController forwards filterExpression and filterVariables',
      () async {
        String? capturedExpr;
        Map<String, List<String>>? capturedVars;
        final controller = MessageStreamController(
          logger: Logger(level: Level.off),
          bufferLimitProvider: () => 100,
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
                startFromTail,
                localSchemas,
              }) {
                capturedExpr = filterExpression;
                capturedVars = filterVariables;
                return const Stream.empty();
              },
        );
        addTearDown(controller.dispose);

        await controller.startStreaming(
          profile,
          'orders',
          filterType: FilterType.contains,
          searchScope: SearchScope.both,
          filterExpression: 'partition = 0',
          filterVariables: {
            'p': ['0'],
          },
        );

        expect(capturedExpr, 'partition = 0');
        expect(capturedVars, {
          'p': ['0'],
        });
      },
    );
  });
}
