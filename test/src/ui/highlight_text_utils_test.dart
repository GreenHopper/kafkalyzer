import 'package:kafkalyzer/src/ui/highlight_text_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HighlightTextUtils', () {
    final baseStyle = TextStyle(color: Color(0xFF000000));
    final highlightStyle = TextStyle(color: Color(0xFFFF0000));

    test('returns full text with base style when query is empty', () {
      final spans = HighlightTextUtils.buildHighlightedSpans(
        'Hello World',
        '',
        baseStyle,
        highlightStyle,
      );
      expect(spans.length, 1);
      expect(spans[0].text, 'Hello World');
      expect(spans[0].style, baseStyle);
    });

    test('returns text with highlighted spans when query matches', () {
      final spans = HighlightTextUtils.buildHighlightedSpans(
        'Hello World',
        'Hello',
        baseStyle,
        highlightStyle,
      );
      expect(spans.length, 2);
      expect(spans[0].text, 'Hello');
      expect(spans[0].style, highlightStyle);
      expect(spans[1].text, ' World');
      expect(spans[1].style, baseStyle);
    });

    test('returns text with highlighted spans when query matches middle', () {
      final spans = HighlightTextUtils.buildHighlightedSpans(
        'Hello World',
        'o',
        baseStyle,
        highlightStyle,
      );
      // Hell (base) -> o (highlight) -> W (base) -> o (highlight) -> rld (base)
      expect(spans.length, 5);
      expect(spans[0].text, 'Hell');
      expect(spans[1].text, 'o');
      expect(spans[1].style, highlightStyle);
      expect(spans[3].text, 'o');
      expect(spans[3].style, highlightStyle);
    });

    test('is case insensitive', () {
      final spans = HighlightTextUtils.buildHighlightedSpans(
        'Hello World',
        'hello',
        baseStyle,
        highlightStyle,
      );
      expect(spans.length, 2);
      expect(spans[0].text, 'Hello'); // Original text case preserved
      expect(spans[0].style, highlightStyle);
    });
  });
}
