import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';

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

  test('initial state is idle and empty', () {
    expect(controller.isAnalyzing, false);
    expect(controller.progress, isNull);
    expect(controller.report, isNull);
    expect(controller.error, isNull);
    expect(controller.startTime, isNull);
    expect(controller.progressRatio, 0.0);
    expect(controller.scannedMessages, 0);
    expect(controller.totalMessagesToScan, 0);
    expect(controller.sampleFromLatest, true);
  });

  test('setMaxMessages and setSampleFromLatest notify listeners', () {
    var notified = 0;
    controller.addListener(() => notified++);

    controller.setMaxMessages(50000);
    expect(controller.maxMessages, 50000);
    expect(notified, 1);

    controller.setSampleFromLatest(false);
    expect(controller.sampleFromLatest, false);
    expect(notified, 2);
  });

  test('clear resets state', () {
    controller.setMaxMessages(1000);
    controller.clear();

    expect(controller.isAnalyzing, false);
    expect(controller.progress, isNull);
    expect(controller.report, isNull);
    expect(controller.error, isNull);
    expect(controller.startTime, isNull);
  });

  test('stopAnalysis sets isAnalyzing to false', () async {
    await controller.stopAnalysis();
    expect(controller.isAnalyzing, false);
  });
}
