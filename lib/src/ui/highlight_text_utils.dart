import 'package:flutter/material.dart';

class HighlightTextUtils {
  static List<TextSpan> buildHighlightedSpans(
    String text,
    String query,
    TextStyle baseStyle,
    TextStyle highlightStyle,
  ) {
    if (query.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final lowerQuery = query.toLowerCase();
    final lowerText = text.toLowerCase();
    final matches = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          matches.add(TextSpan(text: text.substring(start), style: baseStyle));
        }
        break;
      }

      if (index > start) {
        matches.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }

      final match = text.substring(index, index + query.length);
      matches.add(TextSpan(text: match, style: highlightStyle));

      start = index + query.length;
    }

    return matches;
  }
}
