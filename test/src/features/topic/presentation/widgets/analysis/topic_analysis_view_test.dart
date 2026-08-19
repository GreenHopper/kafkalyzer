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

  testWidgets('shows ETA when total and throughput are known', (tester) async {
    const topic = TopicMetadata(
      name: 'orders-topic',
      partitionCount: 3,
      replicationFactor: 1,
    );
    const profile = ClusterProfile(
      name: 'Local Cluster',
      bootstrapServers: 'localhost:9092',
    );

    final fakeCtrl = FakeAnalysisController(
      analyzing: true,
      scanned: 5000,
      total: 10000,
      mps: 100.0,
      startTime: DateTime.now().subtract(const Duration(seconds: 50)),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TopicAnalysisView(
            topic: topic,
            profile: profile,
            controller: fakeCtrl,
          ),
        ),
      ),
    );
    await tester.pump();

    // Progress banner should be visible
    expect(find.textContaining('Analyzing topic'), findsOneWidget);

    // ETA should be displayed: (10000 - 5000) / 100 = 50s
    expect(find.text('~50 s'), findsOneWidget);

    fakeCtrl.dispose();
  });

  testWidgets('hides ETA when total is unknown', (tester) async {
    const topic = TopicMetadata(
      name: 'orders-topic',
      partitionCount: 3,
      replicationFactor: 1,
    );
    const profile = ClusterProfile(
      name: 'Local Cluster',
      bootstrapServers: 'localhost:9092',
    );

    final fakeCtrl = FakeAnalysisController(
      analyzing: true,
      scanned: 100,
      total: 0,
      mps: 50.0,
      startTime: DateTime.now().subtract(const Duration(seconds: 2)),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TopicAnalysisView(
            topic: topic,
            profile: profile,
            controller: fakeCtrl,
          ),
        ),
      ),
    );
    await tester.pump();

    // Progress banner visible but no ETA
    expect(find.textContaining('Analyzing topic'), findsOneWidget);
    expect(find.text('~'), findsNothing);

    fakeCtrl.dispose();
  });
}

class FakeAnalysisController extends ChangeNotifier
    implements TopicAnalysisController {
  final bool _analyzing;
  final int _scanned;
  final int _total;
  final double _mps;
  final DateTime? _startTime;

  FakeAnalysisController({
    required bool analyzing,
    required int scanned,
    required int total,
    required double mps,
    required DateTime? startTime,
  }) : _analyzing = analyzing,
       _scanned = scanned,
       _total = total,
       _mps = mps,
       _startTime = startTime;

  @override
  bool get isAnalyzing => _analyzing;

  @override
  double get progressRatio => _total > 0 ? _scanned / _total : 0.0;

  @override
  int get scannedMessages => _scanned;

  @override
  int get totalMessagesToScan => _total;

  @override
  double get messagesPerSecond => _mps;

  @override
  DateTime? get startTime => _startTime;

  @override
  TopicAnalysisProgress? get progress => null;

  @override
  TopicAnalysisReport? get report => null;

  @override
  String? get error => null;

  @override
  int? get maxMessages => null;

  @override
  bool get sampleFromLatest => true;

  @override
  Future<void> stopAnalysis() async {}

  @override
  void clear() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
