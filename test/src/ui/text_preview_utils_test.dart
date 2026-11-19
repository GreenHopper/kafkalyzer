import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/ui/text_preview_utils.dart';

void main() {
  group('TextPreviewUtils', () {
    test('getPayloadPreview returns empty string for null or empty input', () {
      expect(TextPreviewUtils.getPayloadPreview(null), '');
      expect(TextPreviewUtils.getPayloadPreview(''), '');
    });

    test('getPayloadPreview truncates long strings and appends ellipsis', () {
      final longString = 'a' * 500;
      final result = TextPreviewUtils.getPayloadPreview(
        longString,
        maxLength: 100,
      );
      expect(result.length, 103); // 100 chars + 3 dots
      expect(result.endsWith('...'), isTrue);
    });

    test('getPayloadPreview replaces newlines and collapses whitespace', () {
      const input = 'hello\nworld   test\nmultiple   spaces';
      final result = TextPreviewUtils.getPayloadPreview(input);
      expect(result, 'hello world test multiple spaces');
    });

    test(
      'getPayloadPreview formats JSON with space after : and , outside strings',
      () {
        const input =
            '{"address":{"city":"Paris","zip":"75001"},"count":3,"empty":null}';
        final result = TextPreviewUtils.getPayloadPreview(input);
        expect(
          result,
          '{"address": {"city": "Paris", "zip": "75001"}, "count": 3}',
        );
      },
    );

    test(
      'getPayloadPreview preserves colons and commas inside JSON string literals',
      () {
        const input = '{"pattern":"a,b:c","escaped":"x\\"y:z,w"}';
        final result = TextPreviewUtils.getPayloadPreview(input);
        expect(result, '{"pattern": "a,b:c", "escaped": "x\\"y:z,w"}');
      },
    );

    test('getPayloadPreview does not insert spaces for invalid JSON', () {
      const input = '{not_valid_json:1,foo:bar}';
      final result = TextPreviewUtils.getPayloadPreview(input);
      expect(result, '{not_valid_json:1,foo:bar}');
    });
  });
}
