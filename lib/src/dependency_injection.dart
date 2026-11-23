import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/tls_transition_controller.dart';
import 'package:kafkalyzer/src/features/consumer/application/consumer_group_directory.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/controllers/cluster_overview_controller.dart';
import 'package:kafkalyzer/src/features/navigation/main_navigation_controller.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/ui/diff/json_diff_batcher.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/services/appearance_settings.dart';
import 'package:kafkalyzer/src/services/cluster_profile_tools.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/connection_diagnostics_service.dart';
import 'package:kafkalyzer/src/services/diff_ignore_list_service.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_reporter.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/topic_config_service.dart';
import 'package:kafkalyzer/src/services/topic_name_source.dart';
import 'package:kafkalyzer/src/services/topic_store.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:kafkalyzer/src/services/message_export_service.dart';
import 'package:kafkalyzer/src/services/topic_analysis_export_service.dart';
import 'package:kafkalyzer/src/services/topic_analysis_history_service.dart';
import 'package:kafkalyzer/src/services/file_opener_service.dart';
import 'package:kafkalyzer/src/services/local_schema_assignment_service.dart';
import 'package:kafkalyzer/src/services/update_service.dart';
import 'package:kafkalyzer/src/services/window_state_service.dart';
import 'package:kafkalyzer/src/services/saved_searches_service.dart';
import 'package:kafkalyzer/src/services/session_restore_service.dart';
import 'package:kafkalyzer/src/services/topic_list_preferences_service.dart';
import 'package:kafkalyzer/src/services/recent_topics_service.dart';
import 'package:kafkalyzer/src/services/secure_storage_service.dart';
import 'package:kafkalyzer/src/services/time_display_settings.dart';

final getIt = GetIt.instance;

/// The only application state that outlives the screen that produced it.
///
/// Each entry is here because a named spec requires the user to find it again
/// after leaving the screen that created it - for example `topic-search-tabs`
/// keeps every background tab session, `consumer-lag-trend` keeps the retained
/// lag history, and a running script has to finish while its view is disposed.
/// State that no such requirement covers belongs to the widget subtree that
/// creates it and is handed to its consumers as a constructor parameter
/// (see `SettingsImportExportController`), never registered here.
///
/// `scripts/quality_gates.sh` reads this list: a changed source under a
/// feature's `presentation/` must not gain a container lookup for one of these
/// types, it receives them from its caller instead.
const List<Type> sessionWideState = <Type>[
  ActiveConnectionController,
  ClusterListController,
  TlsTransitionController,
  MultiSearchController,
  TopicController,
  ClusterOverviewController,
  SchemaController,
  MainNavigationController,
  ScriptController,
  ScriptRunner,
  ConsumerGroupDirectory,
];

/// Wires the full desktop application: every service plus the session-wide state.
void setupDependencyInjection({ErrorReporter? errorReporter}) {
  setupCoreServices(errorReporter: errorReporter);
  registerSessionWideState();
}

/// Services that hold no screen state: they are safe to share across entry
/// points and every entry point that touches them registers them.
void setupCoreServices({ErrorReporter? errorReporter}) {
  getIt.registerLazySingleton<Logger>(() => Logger());
  getIt.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(logger: getIt<Logger>()),
  );
  getIt.registerLazySingleton<UpdateService>(
    () => UpdateService(logger: getIt<Logger>()),
  );
  getIt.registerLazySingleton<ClusterService>(() => ClusterService());
  getIt.registerLazySingleton<ClusterProfileTools>(
    () => const ClusterProfileTools(),
  );
  getIt.registerLazySingleton<KafkaMetadataService>(
    () => KafkaMetadataService(),
  );
  getIt.registerLazySingleton<TopicConfigService>(() => TopicConfigService());
  getIt.registerLazySingleton<ConnectionDiagnosticsService>(
    () => ConnectionDiagnosticsService(),
  );
  getIt.registerLazySingleton<SchemaRegistryService>(
    () => SchemaRegistryService(),
  );
  getIt.registerLazySingleton<AppearanceSettings>(() => AppearanceSettings());
  getIt.registerLazySingleton<WindowStateService>(() => WindowStateService());

  getIt.registerLazySingleton<ScriptRepository>(() => ScriptRepository());
  getIt.registerLazySingleton<ErrorReporter>(
    () => errorReporter ?? ErrorReporter(),
  );

  getIt.registerLazySingleton<SettingsService>(() => SettingsService());
  getIt.registerLazySingleton<MessageExportService>(
    () => MessageExportService(),
  );
  getIt.registerLazySingleton<TopicAnalysisExportService>(
    () => TopicAnalysisExportService(),
  );
  getIt.registerLazySingleton<TopicAnalysisHistoryService>(
    () => TopicAnalysisHistoryService(logger: getIt<Logger>()),
  );
  getIt.registerLazySingleton<FileOpenerService>(() => FileOpenerService());
  getIt.registerLazySingleton<RecentTopicsService>(() => RecentTopicsService());
  getIt.registerLazySingleton<SavedSearchesService>(
    () => SavedSearchesService(),
  );
  getIt.registerLazySingleton<SessionRestoreService>(
    () => SessionRestoreService(),
  );
  getIt.registerLazySingleton<TopicListPreferencesService>(
    () => TopicListPreferencesService(),
  );
  getIt.registerLazySingleton<TimeDisplaySettings>(() => TimeDisplaySettings());
  getIt.registerLazySingleton<JsonDiffBatcher>(() => JsonDiffBatcher());
  getIt.registerLazySingleton<DiffIgnoreListService>(
    () => DiffIgnoreListService(),
  );
  getIt.registerLazySingleton<LocalSchemaAssignmentService>(
    () => LocalSchemaAssignmentService(),
  );
  // The topic names the schema dialogs show, answered from the topic cache.
  getIt.registerLazySingleton<TopicNameSource>(
    () => CachedTopicNames(getIt<TopicController>()),
  );
}

/// The session-wide state of the desktop application, exactly the types listed
/// in [sessionWideState].
void registerSessionWideState() {
  getIt.registerLazySingleton<ClusterListController>(
    () => ClusterListController(),
  );
  getIt.registerLazySingleton<TlsTransitionController>(
    () => TlsTransitionController(),
  );
  getIt.registerLazySingleton<ActiveConnectionController>(
    () => ActiveConnectionController(),
  );
  getIt.registerLazySingleton<MultiSearchController>(
    () => MultiSearchController(),
  );
  getIt.registerLazySingleton<TopicController>(() => TopicController());
  // Alias, not extra state: lets a module drive the topic list without
  // importing the topic feature.
  getIt.registerLazySingleton<TopicStore>(() => getIt<TopicController>());
  getIt.registerLazySingleton<ClusterOverviewController>(
    () => ClusterOverviewController(),
  );
  getIt.registerLazySingleton<SchemaController>(() => SchemaController());
  getIt.registerLazySingleton<MainNavigationController>(
    () => MainNavigationController(),
  );
  getIt.registerLazySingleton<ConsumerGroupDirectory>(
    () => ConsumerGroupDirectory(),
  );
  getIt.registerLazySingleton<ScriptController>(() => ScriptController());
  getIt.registerLazySingleton<ScriptRunner>(() => ScriptRunner());
}

/// The headless script runner's own wiring: core services plus the state
/// [ScriptRunner] reads while it works. No GUI-only controller is registered,
/// so a headless run cannot pick up desktop state by accident.
void registerScriptExecutionState() {
  getIt.registerLazySingleton<ClusterListController>(
    () => ClusterListController(),
  );
  getIt.registerLazySingleton<MultiSearchController>(
    () => MultiSearchController(),
  );
  getIt.registerLazySingleton<TopicController>(() => TopicController());
  getIt.registerLazySingleton<ScriptRunner>(() => ScriptRunner());
}
