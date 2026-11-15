import 'dart:async';

import 'package:kafkalyzer/src/rust/api/json_diff.dart';

typedef JsonDiffBatchFn =
    Future<List<JsonDiffResult>> Function(
      List<JsonDiffRequest> requests,
      int? maxEntries,
    );

/// Coalesces [JsonDiffRequest]s submitted in the same event-loop turn into
/// bounded batches over the Rust FRB bridge.
class JsonDiffBatcher {
  static const int maxBatchSize = 50;

  final JsonDiffBatchFn _batchFn;
  final Map<int?, List<_PendingDiff>> _pending = {};
  bool _scheduled = false;

  JsonDiffBatcher({JsonDiffBatchFn? batchFn})
    : _batchFn =
          batchFn ??
          ((requests, maxEntries) =>
              diffJsonBatch(requests: requests, maxEntries: maxEntries));

  Future<JsonDiffResult> enqueue(JsonDiffRequest request, {int? maxEntries}) {
    final completer = Completer<JsonDiffResult>();
    // Prevent uncaught-error zone crashes if the caller attaches one frame later
    // (e.g. FutureBuilder) or disposes before awaiting.
    completer.future.ignore();
    _pending
        .putIfAbsent(maxEntries, () => [])
        .add(_PendingDiff(request, completer));
    if (!_scheduled) {
      _scheduled = true;
      scheduleMicrotask(_flush);
    }
    return completer.future;
  }

  Future<void> _flush() async {
    _scheduled = false;
    final snapshot = Map<int?, List<_PendingDiff>>.from(_pending);
    _pending.clear();

    for (final entry in snapshot.entries) {
      final maxEntries = entry.key;
      final items = entry.value;
      for (var i = 0; i < items.length; i += maxBatchSize) {
        final end = (i + maxBatchSize < items.length)
            ? i + maxBatchSize
            : items.length;
        final chunk = items.sublist(i, end);
        try {
          final results = await _batchFn(
            chunk.map((e) => e.request).toList(),
            maxEntries,
          );
          if (results.length != chunk.length) {
            final err = StateError(
              'diffJsonBatch returned ${results.length} results for ${chunk.length} requests',
            );
            for (final item in chunk) {
              item.completer.completeError(err);
            }
            continue;
          }
          for (var j = 0; j < chunk.length; j++) {
            chunk[j].completer.complete(results[j]);
          }
        } catch (e, st) {
          for (final item in chunk) {
            item.completer.completeError(e, st);
          }
        }
      }
    }
  }
}

class _PendingDiff {
  final JsonDiffRequest request;
  final Completer<JsonDiffResult> completer;

  _PendingDiff(this.request, this.completer);
}
