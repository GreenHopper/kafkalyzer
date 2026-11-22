import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/ui/smart_tree/virtual_json_node.dart';
import 'package:kafkalyzer/src/utils/nested_value_decoder.dart';

void main() {
  test('copyWith overrides selected fields and keeps the rest', () {
    const original = VirtualJsonNode(
      path: 'root.a',
      key: 'a',
      value: 1,
      depth: 1,
      type: JsonNodeType.primitive,
      isExpanded: true,
      hasChildren: false,
      childCount: 0,
      isMatch: true,
      collapsedRangeStart: 0,
      collapsedRangeEnd: 2,
      collapsedCount: 3,
      compoundPathKey: 'root.a',
      isFocusedMatch: false,
      decodedKind: DecodeKind.base64,
      insideDecoded: true,
    );

    final copy = original.copyWith(
      key: 'b',
      value: 'x',
      isExpanded: false,
      isFocusedMatch: true,
      decodedKind: DecodeKind.gzip,
      insideDecoded: false,
    );

    expect(copy.path, 'root.a');
    expect(copy.key, 'b');
    expect(copy.value, 'x');
    expect(copy.depth, 1);
    expect(copy.type, JsonNodeType.primitive);
    expect(copy.isExpanded, isFalse);
    expect(copy.hasChildren, isFalse);
    expect(copy.childCount, 0);
    expect(copy.isMatch, isTrue);
    expect(copy.collapsedRangeStart, 0);
    expect(copy.collapsedRangeEnd, 2);
    expect(copy.collapsedCount, 3);
    expect(copy.compoundPathKey, 'root.a');
    expect(copy.isFocusedMatch, isTrue);
    expect(copy.decodedKind, DecodeKind.gzip);
    expect(copy.insideDecoded, isFalse);
  });
}
