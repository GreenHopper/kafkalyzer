import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/diff_ignore_suggestions.dart';
import 'package:kafkalyzer/src/rust/api/json_diff.dart';

JsonDiffEntry _changed(String path, List<String> segments) => JsonDiffEntry(
  path: path,
  segments: segments,
  kind: JsonDiffKind.changed,
  oldValue: '1',
  newValue: '2',
);

void main() {
  test('suggests volatile fields and skips non-volatile/index/ignored', () {
    final entries = [
      _changed('updatedAt', ['updatedAt']),
      _changed('createdAt', ['createdAt']),
      _changed('meta.ts', ['meta', 'ts']),
      _changed('eventId', ['eventId']),
      _changed('uuid', ['uuid']),
      _changed('customerName', ['customerName']),
      _changed('/0/1', ['0', '1']),
      _changed('alreadyIgnoredTs', ['alreadyIgnoredTs']),
      const JsonDiffEntry(
        path: 'addedTs',
        segments: ['addedTs'],
        kind: JsonDiffKind.added,
        newValue: '123',
      ),
    ];

    final suggestions = suggestVolatileIgnorePaths(
      entries,
      alreadyIgnored: ['alreadyIgnoredTs'],
    );

    expect(suggestions, [
      'updatedAt',
      'createdAt',
      'meta.ts',
      'eventId',
      'uuid',
    ]);
  });

  test('caps suggestions at 20', () {
    final entries = List.generate(
      30,
      (i) => _changed('ts$i', ['field_${i}_ts']),
    );
    final suggestions = suggestVolatileIgnorePaths(entries);
    expect(suggestions, hasLength(20));
  });
}
