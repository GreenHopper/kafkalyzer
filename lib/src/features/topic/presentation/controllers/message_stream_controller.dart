import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:kafkalyzer/src/services/local_schema_assignment_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/ui/messages/message_ring_buffer.dart';

/// Builds a filtered Kafka message stream for [MessageStreamController].
typedef MessageConsumeStreamFactory =
    Stream<KafkaMessage> Function({
      required ClusterProfile profile,
      required String topic,
      List<String>? filterTerms,
      String? filterField,
      required FilterType filterType,
      required SearchScope searchScope,
      String? filterExpression,
      Map<String, List<String>>? filterVariables,
      String? fastTraceKey,
      int? startOffset,
      int? startTimestamp,
      int? startPartition,
      int? maxResults,
      int? endOffset,
      int? endTimestamp,
      required bool runForever,
      bool? startFromTail,
      TopicLocalSchemasDto? localSchemas,
    });

class MessageStreamController extends ChangeNotifier {
  MessageStreamController({
    Logger? logger,
    MessageConsumeStreamFactory? consumeStreamFactory,
    int Function()? bufferLimitProvider,
    LocalSchemaAssignmentService? localSchemaService,
  }) : _logger = logger ?? getIt<Logger>(),
       _consumeStreamFactory = consumeStreamFactory ?? _defaultConsumeStream,
       _bufferLimitProvider = bufferLimitProvider ?? _defaultBufferLimit,
       _localSchemaService =
           localSchemaService ??
           (getIt.isRegistered<LocalSchemaAssignmentService>()
               ? getIt<LocalSchemaAssignmentService>()
               : null) {
    final limit = _resolveBufferLimit();
    _buffer = MessageRingBuffer(limit);
    _published = _buffer.snapshot();
  }

  final Logger _logger;
  final MessageConsumeStreamFactory _consumeStreamFactory;
  final int Function() _bufferLimitProvider;
  final LocalSchemaAssignmentService? _localSchemaService;

  static int _defaultBufferLimit() {
    if (getIt.isRegistered<SettingsService>()) {
      return getIt<SettingsService>().messageBufferLimit.value;
    }
    return SettingsService.defaultMessageBufferLimit;
  }

  int _resolveBufferLimit() {
    final limit = _bufferLimitProvider();
    return limit > 0 ? limit : SettingsService.defaultMessageBufferLimit;
  }

  static Stream<KafkaMessage> _defaultConsumeStream({
    required ClusterProfile profile,
    required String topic,
    List<String>? filterTerms,
    String? filterField,
    required FilterType filterType,
    required SearchScope searchScope,
    String? filterExpression,
    Map<String, List<String>>? filterVariables,
    String? fastTraceKey,
    int? startOffset,
    int? startTimestamp,
    int? startPartition,
    int? maxResults,
    int? endOffset,
    int? endTimestamp,
    required bool runForever,
    bool? startFromTail,
    TopicLocalSchemasDto? localSchemas,
  }) => consumeWithFilter(
    profile: profile,
    topic: topic,
    filterTerms: filterTerms,
    filterField: filterField,
    filterType: filterType,
    searchScope: searchScope,
    filterExpression: filterExpression,
    filterVariables: filterVariables,
    fastTraceKey: fastTraceKey,
    startOffset: startOffset,
    startTimestamp: startTimestamp,
    startPartition: startPartition,
    maxResults: maxResults,
    endOffset: endOffset,
    endTimestamp: endTimestamp,
    runForever: runForever,
    startFromTail: startFromTail,
    localSchemas: localSchemas,
  );

  StreamSubscription<KafkaMessage>? _subscription;
  late MessageRingBuffer _buffer;
  late MessageSnapshot _published;
  Timer? _throttleTimer;
  bool _hasPendingUiUpdate = false;
  bool _isStreaming = false;
  bool _isPaused = false;
  String? _error;

  List<KafkaMessage> get messages => _published;
  bool get isStreaming => _isStreaming;
  bool get isPaused => _isPaused;
  int get pendingCount => _buffer.receivedTotal - _published.endSeq;
  int get receivedCount => _buffer.receivedTotal;
  int get droppedCount => _buffer.droppedTotal;
  int get bufferLimit => _buffer.capacity;
  String? get error => _error;
  int _totalConsumed = 0;
  int get totalConsumed => _totalConsumed;

  int _totalToScan = 0;
  int get totalToScan => _totalToScan;

  int? _maxResults;

  DateTime? _startTime;
  DateTime? get startTime => _startTime;

  double get progress {
    if (_totalToScan == 0) return 0.0;
    if (_totalConsumed >= _totalToScan) return 1.0;
    return _totalConsumed / _totalToScan;
  }

  Future<void> startStreaming(
    ClusterProfile profile,
    String topic, {
    List<String>? filterTerms,
    String? filterField,
    required FilterType filterType,
    required SearchScope searchScope,
    String? filterExpression,
    Map<String, List<String>>? filterVariables,
    bool fastTraceEnabled = false,
    int? startOffset,
    int? startTimestamp,
    int? startPartition,
    int? maxResults,
    int? endOffset,
    int? endTimestamp,
    bool runForever = true,
    bool startFromTail = false,
  }) async {
    await stopStreaming();

    _buffer = MessageRingBuffer(_resolveBufferLimit());
    _published = _buffer.snapshot();
    _isPaused = false;
    _totalConsumed = 0;
    _totalToScan = 0;
    _startTime = DateTime.now();
    _error = null;
    _isStreaming = true;
    _maxResults = maxResults;
    notifyListeners();

    try {
      final localSchemas = await _localSchemaService?.scanOptionsFor(
        profile.name,
        topic,
      );
      final stream = _consumeStreamFactory(
        profile: profile,
        topic: topic,
        filterTerms: filterTerms,
        filterField: filterField,
        filterType: filterType,
        searchScope: searchScope,
        filterExpression: filterExpression,
        filterVariables: filterVariables,
        startOffset: startOffset,
        startTimestamp: startTimestamp,
        startPartition: startPartition,
        fastTraceKey: fastTraceEnabled ? filterTerms?.firstOrNull : null,
        endOffset: endOffset,
        endTimestamp: endTimestamp,
        runForever: runForever,
        maxResults: maxResults,
        startFromTail: startFromTail,
        localSchemas: localSchemas,
      );
      _subscription = stream.listen(
        _onMessageReceived,
        onError: (e) {
          _logger.e("Error consuming topic $topic", error: e);
          _flushPendingUiUpdate();
          _error = e.toString();
          _isStreaming = false;
          notifyListeners();
        },
        onDone: () {
          _flushPendingUiUpdate();
          _isStreaming = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _logger.e("Failed to start stream", error: e);
      _error = e.toString();
      _isStreaming = false;
      notifyListeners();
    }
  }

  void _onMessageReceived(KafkaMessage message) {
    if (!_isStreaming) return;

    final payload = message.payload ?? "";
    if (payload.startsWith("__LOG")) {
      _logger.d(payload);
      return;
    }
    if (payload.startsWith("__HEARTBEAT__") ||
        payload.startsWith("__PROGRESS__")) {
      _handleControlMessage(payload);
      return;
    }
    if (payload == "__EOF__") {
      _flushPendingUiUpdate();
      _isStreaming = false;
      notifyListeners();
      _logger.i("End of topic reached.");
      return;
    }

    _buffer.add(message);
    if (_totalConsumed < _buffer.receivedTotal) {
      _totalConsumed = _buffer.receivedTotal;
    }
    _scheduleUiUpdate();

    if (_maxResults != null && _buffer.receivedTotal >= _maxResults!) {
      _logger.i("Max results $_maxResults reached, stopping stream.");
      stopStreaming();
    }
  }

  void pause() {
    if (_isPaused) return;
    _isPaused = true;
    notifyListeners();
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    _published = _buffer.snapshot();
    notifyListeners();
  }

  void _scheduleUiUpdate() {
    _hasPendingUiUpdate = true;
    if (_throttleTimer == null || !_throttleTimer!.isActive) {
      _throttleTimer = Timer(const Duration(milliseconds: 60), () {
        if (_hasPendingUiUpdate) {
          _hasPendingUiUpdate = false;
          if (!_isPaused) {
            _published = _buffer.snapshot();
          }
          notifyListeners();
        }
      });
    }
  }

  void _flushPendingUiUpdate() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    if (_hasPendingUiUpdate && !_isPaused) {
      _published = _buffer.snapshot();
    }
    _hasPendingUiUpdate = false;
  }

  void _handleControlMessage(String payload) {
    // __HEARTBEAT__:scanned:total or __PROGRESS__:scanned:total
    final parts = payload.split(":");
    if (parts.length > 1) {
      final parsedScanned = int.tryParse(parts[1]);
      if (parsedScanned != null) {
        _totalConsumed = parsedScanned > _buffer.receivedTotal
            ? parsedScanned
            : _buffer.receivedTotal;
      }
      if (parts.length > 2) {
        _totalToScan =
            int.tryParse(parts[2]) ??
            (payload.startsWith("__PROGRESS__") ? 0 : _totalToScan);
      }
      _scheduleUiUpdate();
    }
  }

  Future<void> stopStreaming() async {
    _flushPendingUiUpdate();
    // Update UI immediately
    _isStreaming = false;
    _startTime = null;
    notifyListeners();

    await _subscription?.cancel();
    _subscription = null;
  }

  void clearMessages() {
    _flushPendingUiUpdate();
    _buffer = MessageRingBuffer(_resolveBufferLimit());
    _published = _buffer.snapshot();
    _isPaused = false;
    _totalConsumed = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _flushPendingUiUpdate();
    stopStreaming();
    super.dispose();
  }
}
