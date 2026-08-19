import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_analyzer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class TopicAnalysisController extends ChangeNotifier {
  final Logger _logger;

  TopicAnalysisController({Logger? logger})
    : _logger =
          logger ?? (getIt.isRegistered<Logger>() ? getIt<Logger>() : Logger());

  StreamSubscription<TopicAnalysisProgress>? _subscription;
  bool _isAnalyzing = false;
  TopicAnalysisProgress? _progress;
  TopicAnalysisReport? _report;
  String? _error;
  DateTime? _startTime;

  int? _maxMessages;
  bool _sampleFromLatest = true;

  bool get isAnalyzing => _isAnalyzing;
  TopicAnalysisProgress? get progress => _progress;
  TopicAnalysisReport? get report => _report;
  String? get error => _error;
  DateTime? get startTime => _startTime;
  int? get maxMessages => _maxMessages;
  bool get sampleFromLatest => _sampleFromLatest;

  double get progressRatio => _progress?.progress ?? 0.0;
  int get scannedMessages => _progress?.scannedMessages ?? 0;
  int get totalMessagesToScan => _progress?.totalMessagesToScan ?? 0;
  double get messagesPerSecond => _progress?.messagesPerSecond ?? 0.0;

  void setMaxMessages(int? count) {
    _maxMessages = count;
    notifyListeners();
  }

  void setSampleFromLatest(bool value) {
    _sampleFromLatest = value;
    notifyListeners();
  }

  Future<void> startAnalysis(
    ClusterProfile profile,
    String topic, {
    int? maxMessages,
    bool sampleFromLatest = true,
  }) async {
    await stopAnalysis();

    _maxMessages = maxMessages ?? _maxMessages;
    _sampleFromLatest = sampleFromLatest;
    _isAnalyzing = true;
    _progress = null;
    _error = null;
    _startTime = DateTime.now();
    notifyListeners();

    try {
      final stream = analyzeTopicContent(
        profile: profile,
        topic: topic,
        maxMessages: _maxMessages,
        sampleFromLatest: _sampleFromLatest,
      );

      _subscription = stream.listen(
        _onProgressReceived,
        onError: (e) {
          _logger.e("Error analyzing topic $topic", error: e);
          _error = e.toString();
          _isAnalyzing = false;
          notifyListeners();
        },
        onDone: () {
          _isAnalyzing = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _logger.e("Failed to start topic analysis", error: e);
      _error = e.toString();
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  void _onProgressReceived(TopicAnalysisProgress progress) {
    _progress = progress;
    if (progress.partialReport != null) {
      _report = progress.partialReport;
    }
    if (progress.errorMessage != null) {
      _error = progress.errorMessage;
    }
    if (progress.isComplete) {
      _isAnalyzing = false;
    }
    notifyListeners();
  }

  Future<void> stopAnalysis() async {
    _isAnalyzing = false;
    notifyListeners();

    await _subscription?.cancel();
    _subscription = null;
  }

  void clear() {
    stopAnalysis();
    _progress = null;
    _report = null;
    _error = null;
    _startTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAnalysis();
    super.dispose();
  }
}
