import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/json_diff_batcher.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/message_diff.dart';
import 'package:kafkalyzer/src/rust/api/json_diff.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

KafkaMessage _msg(int offset, String? payload) => KafkaMessage(
  topic: 'orders',
  partition: 0,
  offset: offset,
  key: 'k1',
  payload: payload,
  headers: const [],
  timestamp: 1000 + offset,
);

void main() {
  test('JSON pair returns structural entries and no text diff', () async {
    final batcher = JsonDiffBatcher(
      batchFn: (reqs, maxEntries) async {
        expect(reqs, hasLength(1));
        expect(reqs.first.oldJson, '{"a":1}');
        expect(reqs.first.newJson, '{"a":2}');
        expect(reqs.first.ignorePaths, ['ts']);
        expect(maxEntries, MessageDiff.guiMaxEntries);
        return [
          const JsonDiffResult(
            entries: [
              JsonDiffEntry(
                path: 'a',
                segments: ['a'],
                kind: JsonDiffKind.changed,
                oldValue: '1',
                newValue: '2',
              ),
            ],
            total: 1,
            hidden: 1,
            truncated: false,
            invalidSide: null,
          ),
        ];
      },
    );

    final diff = await MessageDiff.computeDiff(
      _msg(1, '{"a":1}'),
      _msg(2, '{"a":2}'),
      ignorePaths: ['ts'],
      batcher: batcher,
    );

    expect(diff.isJson, isTrue);
    expect(diff.entries, hasLength(1));
    expect(diff.hiddenCount, 1);
    expect(diff.textDiffToPrevious, isEmpty);
  });

  test('non-JSON pair computes text diff and marks isJson false', () async {
    final batcher = JsonDiffBatcher(
      batchFn: (reqs, maxEntries) async => const [
        JsonDiffResult(
          entries: [],
          total: 0,
          hidden: 0,
          truncated: false,
          invalidSide: JsonDiffInvalidSide.new_,
        ),
      ],
    );

    final diff = await MessageDiff.computeDiff(
      _msg(1, '{"a":1}'),
      _msg(2, 'hello'),
      batcher: batcher,
    );

    expect(diff.isJson, isFalse);
    expect(diff.entries, isEmpty);
    expect(diff.textDiffToPrevious, isNotEmpty);
  });

  test('tombstone side is substituted with {}', () async {
    String? seenOld;
    final batcher = JsonDiffBatcher(
      batchFn: (reqs, maxEntries) async {
        seenOld = reqs.first.oldJson;
        return const [
          JsonDiffResult(
            entries: [
              JsonDiffEntry(
                path: 'a',
                segments: ['a'],
                kind: JsonDiffKind.added,
                newValue: '1',
              ),
            ],
            total: 1,
            hidden: 0,
            truncated: false,
            invalidSide: null,
          ),
        ];
      },
    );

    final diff = await MessageDiff.computeDiff(
      _msg(1, null),
      _msg(2, '{"a":1}'),
      batcher: batcher,
    );

    expect(seenOld, '{}');
    expect(diff.isJson, isTrue);
  });

  test('propagates bridge errors', () async {
    final batcher = JsonDiffBatcher(
      batchFn: (reqs, maxEntries) async => throw StateError('boom'),
    );

    await expectLater(
      MessageDiff.computeDiff(
        _msg(1, '{"a":1}'),
        _msg(2, '{"a":2}'),
        batcher: batcher,
      ),
      throwsStateError,
    );
  });
}
