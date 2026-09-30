import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

/// Builds a filtered Kafka message stream for [MessageStreamController].
typedef MessageConsumeStreamFactory =
    Stream<KafkaMessage> Function({
      required ClusterProfile profile,
      required String topic,
      List<String>? filterTerms,
      String? filterField,
      required FilterType filterType,
      required SearchScope searchScope,
      String? fastTraceKey,
      int? startOffset,
      int? startTimestamp,
      int? startPartition,
      int? maxResults,
      int? endOffset,
      int? endTimestamp,
      required bool runForever,
      bool? startFromTail,
    });

class MessageStreamController extends ChangeNotifier {
  MessageStreamController({
    Logger? logger,
    MessageConsumeStreamFactory? consumeStreamFactory,
  }) : _logger = logger ?? getIt<Logger>(),
       _consumeStreamFactory = consumeStreamFactory ?? _defaultConsumeStream;

  final Logger _logger;
  final MessageConsumeStreamFactory _consumeStreamFactory;

  static Stream<KafkaMessage> _defaultConsumeStream({
    required ClusterProfile profile,
    required String topic,
    List<String>? filterTerms,
    String? filterField,
    required FilterType filterType,
    required SearchScope searchScope,
    String? fastTraceKey,
    int? startOffset,
    int? startTimestamp,
    int? startPartition,
    int? maxResults,
    int? endOffset,
    int? endTimestamp,
    required bool runForever,
    bool? startFromTail,
  }) => consumeWithFilter(
    profile: profile,
    topic: topic,
    filterTerms: filterTerms,
    filterField: filterField,
    filterType: filterType,
    searchScope: searchScope,
    fastTraceKey: fastTraceKey,
    startOffset: startOffset,
    startTimestamp: startTimestamp,
    startPartition: startPartition,
    maxResults: maxResults,
    endOffset: endOffset,
    endTimestamp: endTimestamp,
    runForever: runForever,
    startFromTail: startFromTail,
  );

  StreamSubscription<KafkaMessage>? _subscription;
  final List<KafkaMessage> _messages = [];
  List<KafkaMessage>? _cachedUnmodifiableMessages;
  Timer? _throttleTimer;
  bool _hasPendingUiUpdate = false;
  bool _isStreaming = false;

  List<KafkaMessage> get messages =>
      _cachedUnmodifiableMessages ??= List.unmodifiable(_messages);
  bool get isStreaming => _isStreaming;
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

    _messages.clear();
    _cachedUnmodifiableMessages = null;
    _totalConsumed = 0;
    _totalToScan = 0;
    _startTime = DateTime.now();
    _isStreaming = true;
    _maxResults = maxResults;
    notifyListeners();

    try {
      final stream = _consumeStreamFactory(
        profile: profile,
        topic: topic,
        filterTerms: filterTerms,
        filterField: filterField,
        filterType: filterType,
        searchScope: searchScope,
        startOffset: startOffset,
        startTimestamp: startTimestamp,
        startPartition: startPartition,
        fastTraceKey: fastTraceEnabled ? filterTerms?.firstOrNull : null,
        endOffset: endOffset,
        endTimestamp: endTimestamp,
        runForever: runForever,
        maxResults: maxResults,
        startFromTail: startFromTail,
      );
      _subscription = stream.listen(
        _onMessageReceived,
        onError: (e) {
          _logger.e("Error consuming topic $topic", error: e);
          _isStreaming = false;
          notifyListeners();
        },
        onDone: () {
          _isStreaming = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _logger.e("Failed to start stream", error: e);
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

    _messages.add(message);
    _cachedUnmodifiableMessages = null;
    if (_totalConsumed < _messages.length) {
      _totalConsumed = _messages.length;
    }
    _scheduleUiUpdate();

    if (_maxResults != null && _messages.length >= _maxResults!) {
      _logger.i("Max results $_maxResults reached, stopping stream.");
      stopStreaming();
    }
  }

  void _scheduleUiUpdate() {
    _hasPendingUiUpdate = true;
    if (_throttleTimer == null || !_throttleTimer!.isActive) {
      _throttleTimer = Timer(const Duration(milliseconds: 60), () {
        if (_hasPendingUiUpdate) {
          _hasPendingUiUpdate = false;
          notifyListeners();
        }
      });
    }
  }

  void _flushPendingUiUpdate() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _hasPendingUiUpdate = false;
  }

  void _handleControlMessage(String payload) {
    // __HEARTBEAT__:scanned:total or __PROGRESS__:scanned:total
    final parts = payload.split(":");
    if (parts.length > 1) {
      final parsedScanned = int.tryParse(parts[1]);
      if (parsedScanned != null) {
        _totalConsumed = parsedScanned > _messages.length
            ? parsedScanned
            : _messages.length;
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
    _messages.clear();
    _cachedUnmodifiableMessages = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _flushPendingUiUpdate();
    stopStreaming();
    super.dispose();
  }
}
