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

class SearchTarget {
  final ClusterProfile profile;
  final TopicMetadata topic;
  final String? filterTerm; // Deprecated, use filterTerms
  final List<String>? filterTerms;
  final String? filterField;
  final FilterType filterType;
  final SearchScope scope;
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
  final Logger _logger = getIt<Logger>();

  String? _outputDirectory;
  String? get outputDirectory => _outputDirectory;

  MultiSearchController() {
    loadDirectory();
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
  List<SearchTarget> get targets => List.unmodifiable(_targets);

  final Map<SearchTarget, SearchStatus> _status = {};
  Map<SearchTarget, SearchStatus> get status => Map.unmodifiable(_status);

  final Map<SearchTarget, List<KafkaMessage>> _results = {};

  final Map<SearchTarget, SearchProgress> _progress = {};
  Map<SearchTarget, SearchProgress> get progress => Map.unmodifiable(_progress);

  List<KafkaMessage> getMessagesFor(SearchTarget? target) {
    if (target != null) {
      return List.unmodifiable(_results[target] ?? []);
    }
    // Aggregate for "All" view
    final all = _results.values.expand((element) => element).toList();
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  // Backward compatibility
  List<KafkaMessage> get aggregatedMessages => getMessagesFor(null);

  final Map<SearchTarget, StreamSubscription<KafkaMessage>> _subscriptions = {};

  void addTarget(SearchTarget target) {
    if (!_targets.contains(target)) {
      _targets.add(target);
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
      _stopSubscription(target);
      _status.remove(target);
      _results.remove(target);
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
    _closeFileSink(target);
  }

  final Map<SearchTarget, IOSink> _fileSinks = {};

  void _startSubscription(SearchTarget target) {
    try {
      _stopSubscription(target);
      _results.remove(target);
      _progress.remove(target);
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

      final stream = consumeWithFilter(
        profile: target.profile,
        topic: target.topic.name,
        filterTerms: finalFilterTerms,
        filterField: target.filterField,
        filterType: target.filterType,
        searchScope: target.scope,
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
      );

      final subscription = stream.listen(
        (message) {
          final payload = message.payload ?? "";
          if (payload.startsWith("__LOG__")) {
            final logMsg = payload.substring(7); // Remove __LOG__:
            if (_outputDirectory != null) {
              try {
                final logFile = File('$_outputDirectory/consumer.log');
                logFile.writeAsStringSync(
                  "${DateTime.now().toIso8601String()}: $logMsg\n",
                  mode: FileMode.append,
                );
              } catch (e) {
                _logger.e("Failed to write to consumer.log", error: e);
              }
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
            final isFirst = _results[target]?.length == 1;
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
          _status[target] = SearchStatus.error;
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
      _status[target] = SearchStatus.error;
      _closeFileSink(target);
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

  void _throttleNotify(SearchTarget target) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastNotify[target] ?? 0;
    if (now - last > 100) {
      // Max 10 updates per second
      _lastNotify[target] = now;
      notifyListeners();
    }
  }

  void _insertMessage(SearchTarget target, KafkaMessage message) {
    if (!_results.containsKey(target)) {
      _results[target] = [];
    }
    final list = _results[target]!;
    list.add(message);

    if (list.length > 2000) {
      list.removeRange(
        0,
        list.length - 2000,
      ); // Remove oldest (assuming append order)
    }
    _throttleNotify(target);
  }

  void clear() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    _targets.clear();
    _status.clear(); // Clear statuses too
    _results.clear();
    _progress.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
