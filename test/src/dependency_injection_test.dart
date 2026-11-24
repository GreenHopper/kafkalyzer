import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/consumer/application/consumer_group_directory.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/controllers/cluster_overview_controller.dart';
import 'package:kafkalyzer/src/features/navigation/main_navigation_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';

/// Checks that the enumerated session-wide list and the wiring functions stay
/// in step, and that the headless entry point wires only what it uses.
void main() {
  test('registerSessionWideState registers every listed type', () {
    registerSessionWideState();

    for (final type in sessionWideState) {
      expect(
        getIt.isRegistered(type: type),
        isTrue,
        reason: '$type is listed in sessionWideState but not registered',
      );
    }
  });

  test('desktop wiring covers the whole session-wide list', () {
    setupDependencyInjection();

    for (final type in sessionWideState) {
      expect(
        getIt.isRegistered(type: type),
        isTrue,
        reason: '$type is missing from setupDependencyInjection',
      );
    }
  });

  test('headless wiring registers the runner and no GUI-only state', () async {
    await getIt.reset();

    setupCoreServices();
    registerScriptExecutionState();

    for (final type in const <Type>[
      ClusterListController,
      MultiSearchController,
      TopicController,
      ScriptRunner,
    ]) {
      expect(
        getIt.isRegistered(type: type),
        isTrue,
        reason: 'the headless run needs $type',
      );
    }

    for (final type in const <Type>[
      MainNavigationController,
      ActiveConnectionController,
      SchemaController,
      ClusterOverviewController,
      ConsumerGroupDirectory,
    ]) {
      expect(
        getIt.isRegistered(type: type),
        isFalse,
        reason: '$type is desktop-only and must not reach a headless run',
      );
    }
  });
}
