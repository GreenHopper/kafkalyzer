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
  });
}
