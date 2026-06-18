import 'dart:convert';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:json_diff/json_diff.dart';
import 'package:flutter/foundation.dart';

class MessageDiff {
  final KafkaMessage? older;
  final KafkaMessage newer;
  final bool isJson;
  final DiffNode? jsonDiffToPrevious;
  final List<Diff> textDiffToPrevious;

  MessageDiff._({
    required this.older,
    required this.newer,
    required this.isJson,
    required this.jsonDiffToPrevious,
    required this.textDiffToPrevious,
  });

  /// Computes the diff. Uses an isolate only for large payloads to prevent
  /// both UI thread blocking *and* isolate-spawn overhead flooding during rapid scrolling.
  static Future<MessageDiff> computeDiff(
    KafkaMessage? older,
    KafkaMessage newer,
  ) async {
    final payloadOlder = older?.payload;
    final payloadNewer = newer.payload;

    final combinedLength =
        (payloadOlder?.length ?? 0) + (payloadNewer?.length ?? 0);

    // Spawning an isolate takes a few milliseconds of UI thread time. Doing this
    // concurrently for 20-50 list items during a heavy scroll completely locks the app.
    // For smaller payloads (< 30KB), synchronous calculation is typically faster than the isolate spawn.
    if (combinedLength < 30000) {
      return _computeIsolate(
        _DiffArgs(payloadOlder, payloadNewer, older, newer),
      );
    }

    return compute(
      _computeIsolate,
      _DiffArgs(payloadOlder, payloadNewer, older, newer),
    );
  }

  static MessageDiff _computeIsolate(_DiffArgs args) {
    bool isJsonOlder = true;
    bool isJsonNewer = true;
    Object? oldJson;
    Object? newJson;

    // Decode older
    if (args.payloadOlder != null && args.payloadOlder!.isNotEmpty) {
      try {
        oldJson = jsonDecode(args.payloadOlder!);
      } catch (_) {
        isJsonOlder = false;
      }
    } else {
      oldJson = {};
    }

    // Decode newer
    if (args.payloadNewer != null && args.payloadNewer!.isNotEmpty) {
      try {
        newJson = jsonDecode(args.payloadNewer!);
      } catch (_) {
        isJsonNewer = false;
      }
    } else {
      newJson = {};
    }

    final isJson = isJsonOlder && isJsonNewer;
    DiffNode? jsonDiff;
    List<Diff> textDiff = [];

    if (isJson) {
      var differ = JsonDiffer.fromJson(oldJson ?? {}, newJson ?? {});
      jsonDiff = differ.diff();
    } else {
      String oldText = args.payloadOlder ?? "";
      String newText = args.payloadNewer ?? "";
      DiffMatchPatch dmp = DiffMatchPatch();
      textDiff = dmp.diff(oldText, newText);
    }

    return MessageDiff._(
      older: args.older,
      newer: args.newer,
      isJson: isJson,
      jsonDiffToPrevious: jsonDiff,
      textDiffToPrevious: textDiff,
    );
  }
}

class _DiffArgs {
  final String? payloadOlder;
  final String? payloadNewer;
  final KafkaMessage? older;
  final KafkaMessage newer;
  _DiffArgs(this.payloadOlder, this.payloadNewer, this.older, this.newer);
}
