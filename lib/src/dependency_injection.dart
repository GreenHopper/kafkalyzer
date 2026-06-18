import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/theme_controller.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:kafkalyzer/src/services/message_export_service.dart';

final getIt = GetIt.instance;

void setupDependencyInjection() {
  getIt.registerLazySingleton<Logger>(() => Logger());
  getIt.registerLazySingleton<ClusterService>(() => ClusterService());
  getIt.registerLazySingleton<KafkaMetadataService>(() => KafkaMetadataService());
  getIt.registerLazySingleton<SchemaRegistryService>(() => SchemaRegistryService());
  getIt.registerLazySingleton<ClusterListController>(() => ClusterListController());
  getIt.registerLazySingleton<ActiveConnectionController>(() => ActiveConnectionController());
  getIt.registerLazySingleton<MultiSearchController>(() => MultiSearchController());
  getIt.registerLazySingleton<TopicController>(() => TopicController());
  getIt.registerLazySingleton<SchemaController>(() => SchemaController());
  getIt.registerLazySingleton<ThemeController>(() => ThemeController());

  getIt.registerLazySingleton<ScriptRepository>(() => ScriptRepository());
  getIt.registerLazySingleton<ScriptController>(() => ScriptController());
  getIt.registerLazySingleton<ScriptRunner>(() => ScriptRunner());


  getIt.registerLazySingleton<SettingsService>(() => SettingsService());
  getIt.registerLazySingleton<MessageExportService>(() => MessageExportService());
}
