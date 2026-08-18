import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

class MessageStreamController extends ChangeNotifier {
  final Logger _logger = getIt<Logger>();

  StreamSubscription<KafkaMessage>? _subscription;
  final List<KafkaMessage> _messages = [];
  bool _isStreaming = false;

  List<KafkaMessage> get messages => List.unmodifiable(_messages);
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

  // Removed local filterType state as it will be passed in startStreaming
  // or we can keep it but it's better to pass it from UI to be stateless-ish in controller regarding UI selection

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
  }) async {
    await stopStreaming();

    _messages.clear();
    _totalConsumed = 0;
    _totalToScan = 0;
    _startTime = DateTime.now();
    _isStreaming = true;
    _maxResults = maxResults;
    notifyListeners();

    try {
      final stream = consumeWithFilter(
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
        endTimestamp: endTimestamp,
        runForever: runForever,
        maxResults: maxResults,
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
      _isStreaming = false;
      notifyListeners();
      _logger.i("End of topic reached.");
      return;
    }

    _messages.insert(0, message);
    if (_messages.length > 1000) {
      _messages.removeLast();
    }
    notifyListeners();

    if (_maxResults != null && _messages.length >= _maxResults!) {
      _logger.i("Max results $_maxResults reached, stopping stream.");
      stopStreaming();
    }
  }

  void _handleControlMessage(String payload) {
    // __HEARTBEAT__:scanned:total or __PROGRESS__:scanned:total
    final parts = payload.split(":");
    if (parts.length > 1) {
      _totalConsumed = int.tryParse(parts[1]) ?? _totalConsumed;
      if (parts.length > 2) {
        _totalToScan =
            int.tryParse(parts[2]) ??
            (payload.startsWith("__PROGRESS__") ? 0 : _totalToScan);
      }
      notifyListeners();
    }
  }

  Future<void> stopStreaming() async {
    // Update UI immediately
    _isStreaming = false;
    _startTime = null;
    notifyListeners();

    await _subscription?.cancel();
    _subscription = null;
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopStreaming();
    super.dispose();
  }
}
