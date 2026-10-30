import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_analysis_report_file.dart';
import 'package:kafkalyzer/src/rust/api/kafka_analyzer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/report_compare.dart';
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
  FieldValueFilter? _valueFilter;
  DuplicateDetectionScope _duplicateScope = DuplicateDetectionScope.payloadOnly;

  ClusterProfile? _lastProfile;
  String? _lastTopic;

  // Comparison of the displayed report against a second one.
  TopicAnalysisReport? _baseReport;
  String? _baseClusterName;
  DateTime? _baseExportedAt;
  ReportComparison? _comparison;
  TopicAnalysisImportErrorKind? _baseImportErrorKind;
  String? _mismatchTopicA;
  String? _mismatchTopicB;
  bool _awaitingSecondReport = false;

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

  TopicAnalysisReport? get baseReport => _baseReport;
  String? get baseClusterName => _baseClusterName;
  DateTime? get baseExportedAt => _baseExportedAt;
  ReportComparison? get comparison => _comparison;
  TopicAnalysisImportErrorKind? get baseImportErrorKind => _baseImportErrorKind;

  /// The two topic names of a rejected pair, shown in the localized message.
  String? get mismatchTopicA => _mismatchTopicA;
  String? get mismatchTopicB => _mismatchTopicB;

  /// True when the comparison was asked for while only one report is loaded.
  bool get awaitingSecondReport => _awaitingSecondReport;

  double get progressRatio => _progress?.progress ?? 0.0;
  int get scannedMessages => _progress?.scannedMessages ?? 0;
  int get totalMessagesToScan => _progress?.totalMessagesToScan ?? 0;
  double get messagesPerSecond => _progress?.messagesPerSecond ?? 0.0;
  FieldValueFilter? get valueFilter => _valueFilter;
  DuplicateDetectionScope get duplicateScope => _duplicateScope;
  ClusterProfile? get lastProfile => _lastProfile;
  String? get lastTopic => _lastTopic;

  void setDuplicateScope(DuplicateDetectionScope scope) {
    _duplicateScope = scope;
    notifyListeners();
  }

  void setValueFilter(FieldValueFilter? filter) {
    _valueFilter = filter;
    notifyListeners();
  }

  void clearValueFilter() {
    _valueFilter = null;
    notifyListeners();
  }

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

  /// Ask for the second report of a comparison and compare it once it is picked.
  /// A pair of different topics is rejected instead of compared.
  Future<void> pickComparisonBase() async {
    _mismatchTopicA = null;
    _mismatchTopicB = null;
    _baseImportErrorKind = null;
    if (_report == null) {
      _awaitingSecondReport = true;
      notifyListeners();
      return;
    }
    try {
      final file = await _exportService.importFile();
      if (file == null) {
        notifyListeners();
        return;
      }
      await setComparisonBase(
        file.report,
        clusterName: file.clusterName,
        exportedAt: file.exportedAt,
      );
    } on TopicAnalysisImportError catch (e) {
      _logger.e('Comparison import failed: $e');
      _baseImportErrorKind = e.kind;
      _comparison = null;
      notifyListeners();
    }
  }

  Future<void> setComparisonBase(
    TopicAnalysisReport base, {
    String? clusterName,
    DateTime? exportedAt,
  }) async {
    _baseReport = base;
    _baseClusterName = clusterName;
    _baseExportedAt = exportedAt;
    _awaitingSecondReport = false;

    final current = _report;
    if (current == null) {
      _awaitingSecondReport = true;
      _comparison = null;
      notifyListeners();
      return;
    }
    if (current.topic != base.topic) {
      _comparison = null;
      _mismatchTopicA = base.topic;
      _mismatchTopicB = current.topic;
      notifyListeners();
      return;
    }
    _comparison = await compareReports(before: base, after: current);
    notifyListeners();
  }

  void clearComparison() {
    _baseReport = null;
    _baseClusterName = null;
    _baseExportedAt = null;
    _comparison = null;
    _baseImportErrorKind = null;
    _mismatchTopicA = null;
    _mismatchTopicB = null;
    _awaitingSecondReport = false;
    notifyListeners();
  }

  Future<void> startAnalysis(
    ClusterProfile profile,
    String topic, {
    int? maxMessages,
    bool sampleFromLatest = true,
    FieldValueFilter? valueFilter,
    DuplicateDetectionScope? duplicateScope,
  }) async {
    if (duplicateScope != null) {
      _duplicateScope = duplicateScope;
    }
    if (valueFilter != null) {
      if (valueFilter.fieldPath.trim().isEmpty) {
        _error = 'Field path cannot be empty';
        notifyListeners();
        return;
      }
      _valueFilter = valueFilter;
    }

    await stopAnalysis();

    _lastProfile = profile;
    _lastTopic = topic;
    _maxMessages = maxMessages;
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
    clearComparison();
    notifyListeners();

    try {
      final stream = analyzeTopicContentWithOptions(
        profile: profile,
        topic: topic,
        options: TopicAnalysisOptions(
          maxMessages: _maxMessages,
          sampleFromLatest: _sampleFromLatest,
          valueFilter: _valueFilter,
          duplicateScope: _duplicateScope,
        ),
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

  /// Restarts the scan with the last-used profile, topic, and message limits,
  /// but using the specified [filter].
  Future<void> rescanWithFilter(FieldValueFilter filter) async {
    if (filter.fieldPath.trim().isEmpty) {
      _error = 'Field path cannot be empty';
      notifyListeners();
      return;
    }
    if (_lastProfile == null || _lastTopic == null) {
      _error = 'No previous analysis scope to rescan';
      notifyListeners();
      return;
    }
    setValueFilter(filter);
    return startAnalysis(
      _lastProfile!,
      _lastTopic!,
      maxMessages: _maxMessages,
      sampleFromLatest: _sampleFromLatest,
      valueFilter: filter,
    );
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
    _valueFilter = null;
    clearComparison();
    notifyListeners();
  }

  @override
  void dispose() {
    stopAnalysis();
    super.dispose();
  }
}
