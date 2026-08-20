import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_analysis_report_file.dart';
import 'package:kafkalyzer/src/rust/api/kafka_analyzer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/topic_analysis_export_service.dart';

/// Whether the currently displayed report came from a live scan or was
/// imported from a file.
enum TopicAnalysisSource { live, imported }

class TopicAnalysisController extends ChangeNotifier {
  final Logger _logger;
  final TopicAnalysisExportService _exportService;

  TopicAnalysisController({
    Logger? logger,
    TopicAnalysisExportService? exportService,
  }) : _logger =
           logger ??
           (getIt.isRegistered<Logger>() ? getIt<Logger>() : Logger()),
       _exportService =
           exportService ??
           (getIt.isRegistered<TopicAnalysisExportService>()
               ? getIt<TopicAnalysisExportService>()
               : TopicAnalysisExportService());

  StreamSubscription<TopicAnalysisProgress>? _subscription;
  bool _isAnalyzing = false;
  TopicAnalysisProgress? _progress;
  TopicAnalysisReport? _report;
  String? _error;
  DateTime? _startTime;

  TopicAnalysisSource _reportSource = TopicAnalysisSource.live;
  String? _reportClusterName;
  DateTime? _reportExportedAt;
  TopicAnalysisImportErrorKind? _importErrorKind;
  int? _importErrorFoundVersion;

  int? _maxMessages;
  bool _sampleFromLatest = true;

  bool get isAnalyzing => _isAnalyzing;
  TopicAnalysisProgress? get progress => _progress;
  TopicAnalysisReport? get report => _report;
  String? get error => _error;
  DateTime? get startTime => _startTime;
  int? get maxMessages => _maxMessages;
  bool get sampleFromLatest => _sampleFromLatest;
  bool get isImported => _reportSource == TopicAnalysisSource.imported;
  String? get reportClusterName => _reportClusterName;
  DateTime? get reportExportedAt => _reportExportedAt;
  TopicAnalysisImportErrorKind? get importErrorKind => _importErrorKind;
  int? get importErrorFoundVersion => _importErrorFoundVersion;

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

  /// Exports the current report (live or imported) to a file.
  ///
  /// Returns the written path, or `null` if there is no report or the user
  /// cancelled the save dialog.
  Future<String?> exportReport({String? clusterName}) async {
    final report = _report;
    if (report == null) return null;

    final file = TopicAnalysisReportFile(
      exportedAt: DateTime.now(),
      clusterName: clusterName ?? _reportClusterName,
      report: report,
    );
    return _exportService.export(file);
  }

  /// Imports an analysis report file and makes it the displayed report.
  ///
  /// Returns `true` on success. Returns `false` and sets [importErrorKind]
  /// when the file is invalid. Returns `false` (with no error) when the user
  /// cancelled the picker.
  Future<bool> importReport() async {
    _importErrorKind = null;
    _importErrorFoundVersion = null;
    try {
      final file = await _exportService.importFile();
      if (file == null) {
        notifyListeners();
        return false;
      }
      _report = file.report;
      _reportSource = TopicAnalysisSource.imported;
      _reportClusterName = file.clusterName;
      _reportExportedAt = file.exportedAt;
      _error = null;
      notifyListeners();
      return true;
    } on TopicAnalysisImportError catch (e) {
      _logger.e('Import failed: $e');
      _importErrorKind = e.kind;
      _importErrorFoundVersion = e.foundVersion;
      notifyListeners();
      return false;
    }
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
    _reportSource = TopicAnalysisSource.live;
    _reportClusterName = null;
    _reportExportedAt = null;
    _importErrorKind = null;
    _importErrorFoundVersion = null;
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
    _reportSource = TopicAnalysisSource.live;
    _reportClusterName = null;
    _reportExportedAt = null;
    _importErrorKind = null;
    _importErrorFoundVersion = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAnalysis();
    super.dispose();
  }
}
