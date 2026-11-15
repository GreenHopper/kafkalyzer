import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_analysis_report_file.dart';
import 'package:kafkalyzer/src/rust/api/kafka_analyzer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/report_compare.dart';
import 'package:kafkalyzer/src/services/local_schema_assignment_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/services/topic_analysis_export_service.dart';
import 'package:kafkalyzer/src/services/topic_analysis_history_service.dart';

typedef ScopeEstimator =
    Future<AnalysisScopeEstimate> Function({
      required ClusterProfile profile,
      required String topic,
      required AnalysisScope scope,
    });

typedef AnalysisStreamFactory =
    Stream<TopicAnalysisProgress> Function({
      required ClusterProfile profile,
      required String topic,
      required TopicAnalysisOptions options,
    });

typedef HistoryMaxPerTopicReader = Future<int> Function();

/// Whether the currently displayed report came from a live scan or was
/// imported from a file.
enum TopicAnalysisSource { live, imported }

/// Validation errors produced by [TopicAnalysisController] before calling Rust.
enum TopicAnalysisErrorKind { emptyFieldPath, noPreviousScope }

class TopicAnalysisController extends ChangeNotifier {
  final Logger _logger;
  final TopicAnalysisExportService _exportService;
  final TopicAnalysisHistoryService _historyService;
  final ScopeEstimator _scopeEstimator;
  final AnalysisStreamFactory _streamFactory;
  final HistoryMaxPerTopicReader _historyMaxPerTopicReader;
  final LocalSchemaAssignmentService? _localSchemaService;

  TopicAnalysisController({
    Logger? logger,
    TopicAnalysisExportService? exportService,
    TopicAnalysisHistoryService? historyService,
    ScopeEstimator? scopeEstimator,
    AnalysisStreamFactory? streamFactory,
    HistoryMaxPerTopicReader? historyMaxPerTopicReader,
    LocalSchemaAssignmentService? localSchemaService,
  }) : _logger =
           logger ??
           (getIt.isRegistered<Logger>() ? getIt<Logger>() : Logger()),
       _exportService =
           exportService ??
           (getIt.isRegistered<TopicAnalysisExportService>()
               ? getIt<TopicAnalysisExportService>()
               : TopicAnalysisExportService()),
       _historyService =
           historyService ??
           (getIt.isRegistered<TopicAnalysisHistoryService>()
               ? getIt<TopicAnalysisHistoryService>()
               : TopicAnalysisHistoryService()),
       _scopeEstimator = scopeEstimator ?? estimateAnalysisScope,
       _streamFactory = streamFactory ?? analyzeTopicContentWithOptions,
       _historyMaxPerTopicReader =
           historyMaxPerTopicReader ?? _defaultHistoryMaxPerTopicReader,
       _localSchemaService =
           localSchemaService ??
           (getIt.isRegistered<LocalSchemaAssignmentService>()
               ? getIt<LocalSchemaAssignmentService>()
               : null);

  static Future<int> _defaultHistoryMaxPerTopicReader() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService.readInt(
      prefs,
      SettingsService.analysisHistoryPerTopicSetting,
    );
  }

  StreamSubscription<TopicAnalysisProgress>? _subscription;
  bool _isAnalyzing = false;
  TopicAnalysisProgress? _progress;
  TopicAnalysisReport? _report;
  String? _error;
  TopicAnalysisErrorKind? _errorKind;
  DateTime? _startTime;

  TopicAnalysisSource _reportSource = TopicAnalysisSource.live;
  String? _reportClusterName;
  DateTime? _reportExportedAt;
  TopicAnalysisImportErrorKind? _importErrorKind;
  int? _importErrorFoundVersion;

  AnalysisScope _scope = const AnalysisScope(limitFrom: ScopeLimitFrom.newest);
  bool _isEstimating = false;
  AnalysisScopeEstimate? _lastEstimate;
  String? _estimateError;
  String? _historySaveError;
  bool _savedCurrentScan = false;
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
  TopicAnalysisErrorKind? get errorKind => _errorKind;
  DateTime? get startTime => _startTime;
  AnalysisScope get scope => _scope;
  bool get isEstimating => _isEstimating;
  AnalysisScopeEstimate? get lastEstimate => _lastEstimate;
  String? get estimateError => _estimateError;
  String? get historySaveError => _historySaveError;
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

  void setScope(AnalysisScope scope) {
    _scope = scope;
    notifyListeners();
  }

  void clearHistorySaveError() {
    if (_historySaveError == null) return;
    _historySaveError = null;
    notifyListeners();
  }

  Future<AnalysisScopeEstimate?> estimateScope(
    ClusterProfile profile,
    String topic, {
    AnalysisScope? scope,
  }) async {
    _isEstimating = true;
    _estimateError = null;
    notifyListeners();
    try {
      final estimate = await _scopeEstimator(
        profile: profile,
        topic: topic,
        scope: scope ?? _scope,
      );
      _lastEstimate = estimate;
      _isEstimating = false;
      notifyListeners();
      return estimate;
    } catch (e) {
      _logger.w('Failed to estimate analysis scope for $topic: $e');
      _estimateError = e.toString();
      _isEstimating = false;
      notifyListeners();
      return null;
    }
  }

  Future<HistoryListing> listHistory(String clusterName, String topic) {
    return _historyService.list(clusterName, topic);
  }

  void openSavedReport(TopicAnalysisHistoryEntry entry) {
    _importErrorKind = null;
    _importErrorFoundVersion = null;
    _report = entry.report;
    _reportSource = TopicAnalysisSource.imported;
    _reportClusterName = entry.clusterName;
    _reportExportedAt = entry.exportedAt;
    _error = null;
    notifyListeners();
  }

  /// Exports the current report (live or imported) to a file.
  ///
  /// Returns the written path, or `null` if there is no report or the user
  /// cancelled the save dialog.
  Future<String?> exportReport({
    required String dialogTitle,
    String? clusterName,
  }) async {
    final report = _report;
    if (report == null) return null;

    final file = TopicAnalysisReportFile(
      exportedAt: DateTime.now(),
      clusterName: clusterName ?? _reportClusterName,
      report: report,
    );
    return _exportService.export(file, dialogTitle: dialogTitle);
  }

  /// Imports an analysis report file and makes it the displayed report.
  ///
  /// Returns `true` on success. Returns `false` and sets [importErrorKind]
  /// when the file is invalid. Returns `false` (with no error) when the user
  /// cancelled the picker.
  Future<bool> importReport({required String dialogTitle}) async {
    _importErrorKind = null;
    _importErrorFoundVersion = null;
    try {
      final file = await _exportService.importFile(dialogTitle: dialogTitle);
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
  Future<void> pickComparisonBase({required String dialogTitle}) async {
    _mismatchTopicA = null;
    _mismatchTopicB = null;
    _baseImportErrorKind = null;
    if (_report == null) {
      _awaitingSecondReport = true;
      notifyListeners();
      return;
    }
    try {
      final file = await _exportService.importFile(dialogTitle: dialogTitle);
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
    AnalysisScope? scope,
    FieldValueFilter? valueFilter,
    DuplicateDetectionScope? duplicateScope,
  }) async {
    if (duplicateScope != null) {
      _duplicateScope = duplicateScope;
    }
    if (valueFilter != null) {
      if (valueFilter.fieldPath.trim().isEmpty) {
        _errorKind = TopicAnalysisErrorKind.emptyFieldPath;
        _error = null;
        notifyListeners();
        return;
      }
      _valueFilter = valueFilter;
    }

    await stopAnalysis();

    _lastProfile = profile;
    _lastTopic = topic;
    if (scope != null) {
      _scope = scope;
    }
    _savedCurrentScan = false;
    _historySaveError = null;
    _isAnalyzing = true;
    _progress = null;
    _error = null;
    _errorKind = null;
    _startTime = DateTime.now();
    _reportSource = TopicAnalysisSource.live;
    _reportClusterName = null;
    _reportExportedAt = null;
    _importErrorKind = null;
    _importErrorFoundVersion = null;
    clearComparison();
    notifyListeners();

    try {
      final localSchemas = await _localSchemaService?.scanOptionsFor(
        profile.name,
        topic,
      );
      final stream = _streamFactory(
        profile: profile,
        topic: topic,
        options: TopicAnalysisOptions(
          maxMessages: null,
          sampleFromLatest: false,
          valueFilter: _valueFilter,
          duplicateScope: _duplicateScope,
          scope: _scope,
          localSchemas: localSchemas,
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
      _errorKind = TopicAnalysisErrorKind.emptyFieldPath;
      _error = null;
      notifyListeners();
      return;
    }
    if (_lastProfile == null || _lastTopic == null) {
      _errorKind = TopicAnalysisErrorKind.noPreviousScope;
      _error = null;
      notifyListeners();
      return;
    }
    setValueFilter(filter);
    return startAnalysis(
      _lastProfile!,
      _lastTopic!,
      scope: _scope,
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
      if (progress.errorMessage == null &&
          _reportSource == TopicAnalysisSource.live &&
          !_savedCurrentScan &&
          _report != null &&
          _lastProfile != null) {
        _savedCurrentScan = true;
        unawaited(_saveCompletedReport(_lastProfile!.name, _report!));
      }
    }
    notifyListeners();
  }

  Future<void> _saveCompletedReport(
    String clusterName,
    TopicAnalysisReport report,
  ) async {
    try {
      final maxPerTopic = await _historyMaxPerTopicReader();
      final result = await _historyService.save(
        clusterName: clusterName,
        report: report,
        maxPerTopic: maxPerTopic,
      );
      if (result.cleanupError != null) {
        _historySaveError = result.cleanupError;
        notifyListeners();
      }
    } catch (e) {
      _logger.w('Failed to save topic analysis history: $e');
      _historySaveError = e.toString();
      notifyListeners();
    }
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
