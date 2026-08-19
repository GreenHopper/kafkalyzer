import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_analysis_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

class MockLogger extends Logger {
  @override
  void e(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // No-op
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TopicAnalysisController controller;

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<Logger>(() => MockLogger());
    controller = TopicAnalysisController();
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets('TopicAnalysisView renders empty state and controls', (
    tester,
  ) async {
    const topic = TopicMetadata(
      name: 'orders-topic',
      partitionCount: 3,
      replicationFactor: 1,
    );
    const profile = ClusterProfile(
      name: 'Local Cluster',
      bootstrapServers: 'localhost:9092',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TopicAnalysisView(
            topic: topic,
            profile: profile,
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan Scope:'), findsOneWidget);
    expect(find.text('Full Scan (All Messages)'), findsOneWidget);
    expect(find.text('Start Analysis'), findsNWidgets(2));
  });
}
