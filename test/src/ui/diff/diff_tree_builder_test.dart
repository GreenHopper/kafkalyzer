import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/ui/diff/diff_tree_builder.dart';
import 'package:kafkalyzer/src/rust/api/json_diff.dart';

List<Map<String, dynamic>> _flatten(List<DiffViewNode> nodes) {
  final out = <Map<String, dynamic>>[];
  void visit(DiffViewNode node) {
    out.add({
      'key': node.key,
      'type': node.type.name,
      'depth': node.depth,
      'old': node.oldValue?.toString(),
      'new': node.newValue?.toString(),
    });
    for (final child in node.children) {
      visit(child);
    }
  }

  for (final n in nodes) {
    visit(n);
  }
  return out;
}

JsonDiffKind _parseKind(String kind) {
  return switch (kind) {
    'added' => JsonDiffKind.added,
    'removed' => JsonDiffKind.removed,
    'changed' => JsonDiffKind.changed,
    _ => throw ArgumentError('Unknown kind: $kind'),
  };
}

void main() {
  test('DiffTreeBuilder.fromEntries matches captured fixture rows', () async {
    final raw = await File('test/fixtures/json_diff/cases.json').readAsString();
    final cases = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

    for (final c in cases) {
      final name = c['name'] as String;
      final rawEntries = (c['entries'] as List).cast<Map<String, dynamic>>();
      final entries = rawEntries
          .map(
            (e) => JsonDiffEntry(
              path: e['path'] as String,
              segments: (e['segments'] as List).cast<String>(),
              kind: _parseKind(e['kind'] as String),
              oldValue: e['old'] as String?,
              newValue: e['new'] as String?,
            ),
          )
          .toList();

      final tree = DiffTreeBuilder.fromEntries(entries);
      final actualRows = _flatten(tree);

      if (c.containsKey('deviation')) {
        // Known deviations from legacy json_diff:
        switch (name) {
          case 'array_reorder':
            expect(actualRows, isNotEmpty, reason: name);
          case 'equal_top_level_scalars':
            expect(actualRows, isEmpty, reason: name);
          case 'nested_unordered_lists':
            expect(actualRows, isNotEmpty, reason: name);
          default:
            fail('Unexpected deviation case: $name');
        }
      } else {
        expect(actualRows, c['rows'], reason: 'Mismatch for case $name');
      }
    }
  });
}
