import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/json_diff_batcher.dart';
import 'package:kafkalyzer/src/rust/api/json_diff.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

class MessageDiff {
  static const int guiMaxEntries = 2000;
  static const int _textDiffIsolateThreshold = 30000;

  final KafkaMessage? older;
  final KafkaMessage newer;
  final bool isJson;
  final JsonDiffResult? jsonDiffResult;
  final List<Diff> textDiffToPrevious;

  List<JsonDiffEntry> get entries => jsonDiffResult?.entries ?? const [];
  int get hiddenCount => jsonDiffResult?.hidden ?? 0;
  int get totalCount => jsonDiffResult?.total ?? 0;
  bool get isTruncated => jsonDiffResult?.truncated ?? false;

  MessageDiff._({
    required this.older,
    required this.newer,
    required this.isJson,
    required this.jsonDiffResult,
    required this.textDiffToPrevious,
  });

  static Future<MessageDiff> computeDiff(
    KafkaMessage? older,
    KafkaMessage newer, {
    List<String> ignorePaths = const [],
    JsonDiffBatcher? batcher,
    int? maxEntries = guiMaxEntries,
  }) async {
    final payloadOlder = older?.payload;
    final payloadNewer = newer.payload;

    final oldJson = (payloadOlder == null || payloadOlder.isEmpty)
        ? '{}'
        : payloadOlder;
    final newJson = (payloadNewer == null || payloadNewer.isEmpty)
        ? '{}'
        : payloadNewer;

    final resolvedBatcher =
        batcher ??
        (getIt.isRegistered<JsonDiffBatcher>()
            ? getIt<JsonDiffBatcher>()
            : JsonDiffBatcher());

    final result = await resolvedBatcher.enqueue(
      JsonDiffRequest(
        oldJson: oldJson,
        newJson: newJson,
        ignorePaths: ignorePaths,
      ),
      maxEntries: maxEntries,
    );

    if (result.invalidSide == null) {
      return MessageDiff._(
        older: older,
        newer: newer,
        isJson: true,
        jsonDiffResult: result,
        textDiffToPrevious: const [],
      );
    }

    final oldText = payloadOlder ?? '';
    final newText = payloadNewer ?? '';
    final combinedLength = oldText.length + newText.length;

    final textDiff = combinedLength < _textDiffIsolateThreshold
        ? _computeTextDiff(_TextDiffArgs(oldText, newText))
        : await compute(_computeTextDiff, _TextDiffArgs(oldText, newText));

    return MessageDiff._(
      older: older,
      newer: newer,
      isJson: false,
      jsonDiffResult: null,
      textDiffToPrevious: textDiff,
    );
  }

  static List<Diff> _computeTextDiff(_TextDiffArgs args) {
    final dmp = DiffMatchPatch();
    return dmp.diff(args.oldText, args.newText);
  }
}

class _TextDiffArgs {
  final String oldText;
  final String newText;

  _TextDiffArgs(this.oldText, this.newText);
}
