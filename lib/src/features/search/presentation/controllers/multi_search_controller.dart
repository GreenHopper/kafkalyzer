import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:kafkalyzer/src/features/search/domain/search_json_serializer.dart';
import 'package:kafkalyzer/src/services/local_schema_assignment_service.dart';
import 'package:kafkalyzer/src/services/message_consume_stream.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/features/messages/presentation/message_ring_buffer.dart';
import 'package:kafkalyzer/src/features/messages/presentation/message_sort_utils.dart';

class SearchTarget {
  final ClusterProfile profile;
  final TopicMetadata topic;
  final String? filterTerm; // Deprecated, use filterTerms
  final List<String>? filterTerms;
  final String? filterField;
  final FilterType filterType;
  final SearchScope scope;
  final String? filterExpression;
  final Map<String, List<String>>? filterVariables;
  final MultiSearchStartStrategy startStrategy;
  final int? startOffset;
  final int? startTimestamp;
  final int? startPartition;
  final bool fastTraceEnabled;
  final MultiSearchEndStrategy endStrategy;
  final int? endOffset;
  final int? endTimestamp;
  final int? maxResults;
  final String? stepId;
  final String? searchJobId;

  SearchTarget({
    required this.profile,
    required this.topic,
    this.filterTerm,
    this.filterTerms,
    this.filterField,
    this.filterType = FilterType.contains,
    this.scope = SearchScope.both,
    this.filterExpression,
    this.filterVariables,
    this.startStrategy = MultiSearchStartStrategy.latest,
    this.startOffset,
    this.startTimestamp,
    this.startPartition,
    this.fastTraceEnabled = false,
    this.endStrategy = MultiSearchEndStrategy.live,
    this.endOffset,
    this.endTimestamp,
    this.maxResults,
    this.stepId,
    this.searchJobId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchTarget &&
          runtimeType == other.runtimeType &&
          profile == other.profile &&
          topic.name == other.topic.name &&
          filterTerm == other.filterTerm &&
          listEquals(filterTerms, other.filterTerms) &&
          filterField == other.filterField &&
          filterType == other.filterType &&
          scope == other.scope &&
          filterExpression == other.filterExpression &&
          _filterVariablesEquals(filterVariables, other.filterVariables) &&
          startStrategy == other.startStrategy &&
          startOffset == other.startOffset &&
          startTimestamp == other.startTimestamp &&
          startPartition == other.startPartition &&
          fastTraceEnabled == other.fastTraceEnabled &&
          endStrategy == other.endStrategy &&
          endOffset == other.endOffset &&
          endTimestamp == other.endTimestamp &&
          maxResults == other.maxResults &&
          stepId == other.stepId &&
          searchJobId == other.searchJobId;

  @override
  int get hashCode =>
      profile.hashCode ^
      topic.name.hashCode ^
      filterTerm.hashCode ^
      Object.hashAll(filterTerms ?? []) ^
      filterField.hashCode ^
      filterType.hashCode ^
      scope.hashCode ^
      filterExpression.hashCode ^
      _filterVariablesHash(filterVariables) ^
      startStrategy.hashCode ^
      startOffset.hashCode ^
      startTimestamp.hashCode ^
      startPartition.hashCode ^
      fastTraceEnabled.hashCode ^
      endStrategy.hashCode ^
      endOffset.hashCode ^
      endTimestamp.hashCode ^
      maxResults.hashCode ^
      stepId.hashCode ^
      searchJobId.hashCode;

  static bool _filterVariablesEquals(
    Map<String, List<String>>? a,
    Map<String, List<String>>? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!listEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }

  static int _filterVariablesHash(Map<String, List<String>>? vars) {
    if (vars == null || vars.isEmpty) return 0;
    final keys = vars.keys.toList()..sort();
    return Object.hashAll(
      keys.map((k) => Object.hash(k, Object.hashAll(vars[k]!))),
    );
  }
}

enum MultiSearchStartStrategy {
  latest,
  earliest,
  customOffset,
  customTimestamp,
}

enum MultiSearchEndStrategy { live, latest, customOffset, customTimestamp }

enum SearchStatus { running, stopped, error }

class SearchProgress {
  final int scanned;
  final int total;
  final DateTime startTime;

  SearchProgress(this.scanned, this.total, {DateTime? startTime})
    : startTime = startTime ?? DateTime.now();

  double get fraction => total == 0 ? 0 : (scanned / total).clamp(0.0, 1.0);
  int get remaining => (total - scanned).clamp(0, total);

  Duration? get estimatedRemaining {
    if (scanned <= 0 || total <= 0) return null;
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inMilliseconds <= 0) return null;

    final rate = scanned / elapsed.inMilliseconds; // messages per ms
    if (rate <= 0) return null;

    final remainingMs = remaining / rate;
    return Duration(milliseconds: remainingMs.round());
  }
}

class MultiSearchController extends ChangeNotifier {
  final Logger _logger;
  final MessageConsumeStreamFactory _consumeStreamFactory;
  final int Function() _bufferLimitProvider;
  final LocalSchemaAssignmentService? _localSchemaService;

  String? _outputDirectory;
  String? get outputDirectory => _outputDirectory;

  MultiSearchController({
    MessageConsumeStreamFactory? consumeStreamFactory,
    int Function()? bufferLimitProvider,
    LocalSchemaAssignmentService? localSchemaService,
    Logger? logger,
  }) : _consumeStreamFactory = consumeStreamFactory ?? bridgeConsumeStream,
       _logger = logger ?? getIt<Logger>(),
       _bufferLimitProvider = bufferLimitProvider ?? _defaultBufferLimit,
       _localSchemaService =
           localSchemaService ??
           (getIt.isRegistered<LocalSchemaAssignmentService>()
               ? getIt<LocalSchemaAssignmentService>()
               : null) {
    loadDirectory();
  }

  static int _defaultBufferLimit() {
    if (getIt.isRegistered<SettingsService>()) {
      return getIt<SettingsService>().messageBufferLimit.value;
    }
    return SettingsService.defaultMessageBufferLimit;
  }

  int get bufferLimit => _resolveBufferLimit();

  int _resolveBufferLimit() {
    final limit = _bufferLimitProvider();
    return limit > 0 ? limit : SettingsService.defaultMessageBufferLimit;
  }

  Future<void> loadDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    _outputDirectory = prefs.getString('general_default_output_dir');
    notifyListeners();
  }

  Future<void> setDirectory(String? path) async {
    _outputDirectory = path;
    notifyListeners();
  }

  final List<SearchTarget> _targets = [];
  List<SearchTarget>? _cachedUnmodifiableTargets;
  List<SearchTarget> get targets =>
      _cachedUnmodifiableTargets ??= List.unmodifiable(_targets);

  final Map<SearchTarget, SearchStatus> _status = {};
  Map<SearchTarget, SearchStatus> get status => Map.unmodifiable(_status);

  final Map<SearchTarget, String> _errors = {};
  Map<SearchTarget, String> get errors => Map.unmodifiable(_errors);

  final Map<SearchTarget, MessageRingBuffer> _results = {};
  final Map<SearchTarget, MessageSnapshot> _cachedUnmodifiableResults = {};

  final Map<SearchTarget, SearchProgress> _progress = {};
  Map<SearchTarget, SearchProgress> get progress => Map.unmodifiable(_progress);

  int receivedCountFor(SearchTarget target) =>
      _results[target]?.receivedTotal ?? 0;

  int droppedCountFor(SearchTarget target) =>
      _results[target]?.droppedTotal ?? 0;

  List<KafkaMessage> getMessagesFor(SearchTarget? target) {
    if (target != null) {
      return _cachedUnmodifiableResults.putIfAbsent(
        target,
        () => _results[target]?.snapshot() ?? MessageSnapshot.empty(),
      );
    }
    // Aggregate for "All" view
    final all = _results.keys.expand((t) => getMessagesFor(t)).toList();
    all.sort((a, b) {
      final tsCmp = b.timestamp.compareTo(a.timestamp);
      return tsCmp != 0 ? tsCmp : compareMessageIdentity(a, b);
    });
    return all;
  }

  // Backward compatibility
  List<KafkaMessage> get aggregatedMessages => getMessagesFor(null);

  final Map<SearchTarget, StreamSubscription<KafkaMessage>> _subscriptions = {};

  void addTarget(SearchTarget target) {
    if (!_targets.contains(target)) {
      _targets.add(target);
      _cachedUnmodifiableTargets = null;
      _startSubscription(target);
      notifyListeners();
    } else {
      // If it exists but is stopped, maybe restart it?
      // User can remove and add again, but let's handle "restart" logic if stopped.
      if (_status[target] == SearchStatus.stopped ||
          _status[target] == SearchStatus.error) {
        _startSubscription(target);
        notifyListeners();
      }
    }
  }

  void removeTarget(SearchTarget target) {
    if (_targets.remove(target)) {
      _cachedUnmodifiableTargets = null;
      _stopSubscription(target);
      _status.remove(target);
      _results.remove(target);
      _cachedUnmodifiableResults.remove(target);
      _progress.remove(target);
      notifyListeners();
    }
  }

  void stopTarget(SearchTarget target) {
    if (_targets.contains(target) && _status[target] == SearchStatus.running) {
      _stopSubscription(target);
      _status[target] = SearchStatus.stopped;
      notifyListeners();
    }
  }

  void _stopSubscription(SearchTarget target) {
    _subscriptions[target]?.cancel();
    _subscriptions.remove(target);
    _trailingNotifyTimers.remove(target)?.cancel();
    _closeFileSink(target);
  }

  final Map<SearchTarget, IOSink> _fileSinks = {};

  Future<void> _startSubscription(SearchTarget target) async {
    try {
      _stopSubscription(target);
      _results[target] = MessageRingBuffer(_resolveBufferLimit());
      _cachedUnmodifiableResults.remove(target);
      _progress.remove(target);
      _errors.remove(target);
      _status[target] = SearchStatus.running;

      // Setup file saving if directory is selected
      if (_outputDirectory != null) {
        try {
          final dir = Directory(_outputDirectory!);
          if (dir.existsSync()) {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final prefix = target.stepId != null ? "${target.stepId}_" : "";
            final filename =
                "search_results_$prefix${target.topic.name}_$timestamp.json";
            final file = File('${dir.path}/$filename');
            final sink = file.openWrite();
            _fileSinks[target] = sink;

            // We want to write "params": {...}, "messages": [ ... ]
            // But streaming into a JSON array is tricky.
            // Let's write the opening manually to allow appending.
            // Actually, simplest valid JSON streaming:
            // { "params": ..., "messages": [
            //    MSG, MSG, ...
            // ] }

            sink.write(
              '{\n  "params": ${jsonEncode(SearchJsonSerializer.serializeTarget(target))},\n  "messages": [\n',
            );
          }
        } catch (e) {
          _logger.e("Failed to setup file saving", error: e);
        }
      }

      final finalFilterTerms =
          target.filterTerms ??
          (target.filterTerm != null && target.filterTerm!.isNotEmpty
              ? [target.filterTerm!]
              : null);

      if (finalFilterTerms != null && finalFilterTerms.isNotEmpty) {
        _logger.i(
          "MultiSearchController: '${target.topic.name}' terms: ${finalFilterTerms.length}. e.g. ${finalFilterTerms.take(3).toList()}",
        );
      }

      final localSchemas = _localSchemaService != null
          ? await _localSchemaService.scanOptionsFor(
              target.profile.name,
              target.topic.name,
            )
          : null;
      final stream = _consumeStreamFactory(
        profile: target.profile,
        topic: target.topic.name,
        filterTerms: finalFilterTerms,
        filterField: target.filterField,
        filterType: target.filterType,
        searchScope: target.scope,
        filterExpression: target.filterExpression,
        filterVariables: target.filterVariables,
        startOffset: target.startOffset,
        startTimestamp: target.startTimestamp,
        startPartition: target.startPartition,
        fastTraceKey: target.fastTraceEnabled
            ? (target.filterTerm ?? target.filterTerms?.firstOrNull)
            : null,
        endOffset: target.endOffset,
        endTimestamp: target.endTimestamp,
        maxResults: target.maxResults,
        runForever: target.endStrategy == MultiSearchEndStrategy.live,
        startFromTail: target.startStrategy == MultiSearchStartStrategy.latest,
        localSchemas: localSchemas,
      );

      final subscription = stream.listen(
        (message) {
          final payload = message.payload ?? "";
          if (payload.startsWith("__LOG__")) {
            final logMsg = payload.substring(7); // Remove __LOG__:
            if (_outputDirectory != null) {
              final logFile = File('$_outputDirectory/consumer.log');
              logFile
                  .writeAsString(
                    "${DateTime.now().toIso8601String()}: $logMsg\n",
                    mode: FileMode.append,
                  )
                  .catchError((e) {
                    _logger.e("Failed to write to consumer.log", error: e);
                    return logFile;
                  });
            }
            return;
          }
          if (payload.startsWith("__HEARTBEAT__") ||
              payload.startsWith("__PROGRESS__")) {
            // Parse progress: __PROGRESS__:scanned:total or __HEARTBEAT__:scanned:total
            final parts = payload.split(":");
            if (parts.length > 2) {
              final scanned = int.tryParse(parts[1]) ?? 0;
              final total = int.tryParse(parts[2]) ?? 0;
              if (total > 0) {
                _progress[target] = SearchProgress(
                  scanned,
                  total,
                  startTime: _progress[target]?.startTime,
                );
                _throttleNotify(target);
              }
            }
            return;
          }
          if (payload == "__EOF__") {
            _logger.i("Received __EOF__ for ${target.topic.name}");
            if (_status[target] == SearchStatus.running) {
              // Ensure progress shows 100% on completion
              final current = _progress[target];
              if (current != null && current.total > 0) {
                _progress[target] = SearchProgress(
                  current.total,
                  current.total,
                  startTime: current.startTime,
                );
              }

              _status[target] = SearchStatus.stopped;
              _closeFileSink(target);
              notifyListeners();
              // Cancel subscription to stop receiving potential extra messages
              _subscriptions[target]?.cancel();
              _subscriptions.remove(target);
            }
            return;
          }

          _insertMessage(target, message);

          // Write to file if enabled
          if (_fileSinks.containsKey(target)) {
            final sink = _fileSinks[target]!;
            final isFirst = _results[target]?.receivedTotal == 1;
            if (!isFirst) {
              sink.write(',\n');
            }
            sink.write(
              '    ${jsonEncode(SearchJsonSerializer.serializeMessage(message))}',
            );
          }
        },
        onError: (e) {
          _logger.e("Error streaming from ${target.topic.name}", error: e);
          _errors[target] = e.toString();
          _status[target] = SearchStatus.error;
          _closeFileSink(target);
          notifyListeners();
        },
        onDone: () {
          _logger.i("Stream done for ${target.topic.name}");
          // If stream completes
          if (_status[target] == SearchStatus.running) {
            _status[target] = SearchStatus.stopped;
            _closeFileSink(target);
            notifyListeners();
          }
        },
      );
      _subscriptions[target] = subscription;
    } catch (e) {
      _logger.e("Failed to start stream for ${target.topic.name}", error: e);
      _errors[target] = e.toString();
      _status[target] = SearchStatus.error;
      _closeFileSink(target);
      notifyListeners();
    }
  }

  void _closeFileSink(SearchTarget target) {
    final sink = _fileSinks.remove(target);
    if (sink != null) {
      // Close JSON array
      sink.write('\n  ]\n}');
      sink.close();
    }
  }

  final Map<SearchTarget, int> _lastNotify = {};
  final Map<SearchTarget, Timer> _trailingNotifyTimers = {};

  void _throttleNotify(SearchTarget target) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastNotify[target] ?? 0;
    if (now - last > 100) {
      // Max 10 updates per second
      _trailingNotifyTimers.remove(target)?.cancel();
      _lastNotify[target] = now;
      notifyListeners();
    } else if (!(_trailingNotifyTimers[target]?.isActive ?? false)) {
      _trailingNotifyTimers[target] = Timer(
        const Duration(milliseconds: 100),
        () {
          _trailingNotifyTimers.remove(target);
          _lastNotify[target] = DateTime.now().millisecondsSinceEpoch;
          notifyListeners();
        },
      );
    }
  }

  void _insertMessage(SearchTarget target, KafkaMessage message) {
    final buffer = _results.putIfAbsent(
      target,
      () => MessageRingBuffer(_resolveBufferLimit()),
    );
    buffer.add(message);
    _cachedUnmodifiableResults.remove(target);
    _throttleNotify(target);
  }

  void clear() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    for (final timer in _trailingNotifyTimers.values) {
      timer.cancel();
    }
    _trailingNotifyTimers.clear();
    _targets.clear();
    _cachedUnmodifiableTargets = null;
    _status.clear(); // Clear statuses too
    _results.clear();
    _cachedUnmodifiableResults.clear();
    _progress.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
