import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';

void main() {
  group('computeMiddleEllipsisIndices', () {
    test(
      'returns null when topic name is shorter than or equal to maxVisibleChars',
      () {
        expect(computeMiddleEllipsisIndices('short.topic', 20), isNull);
        expect(computeMiddleEllipsisIndices('short.topic', 11), isNull);
      },
    );

    test(
      'preserves terminal leaf segment when leaf length fits within allowance',
      () {
        const topic =
            'dataops.cdc.db2.jdbc.LKW_ORDER'; // len 30, prefix 21, leaf 9
        final indices = computeMiddleEllipsisIndices(topic, 18);
        expect(indices, isNotNull);

        final head = topic.substring(0, indices!.headEnd);
        final tail = topic.substring(indices.tailStart);

        // Tail should be the entire leaf 'LKW_ORDER'
        expect(tail, 'LKW_ORDER');
        // Head + tail should equal maxVisibleChars (18)
        expect(head.length + tail.length, 18);
        expect(head, 'dataops.c');
      },
    );

    test('truncates leaf proportionally when leaf itself is very long', () {
      const topic = 'com.example.VERY_LONG_LEAF_SEGMENT_FOR_ORDERS_V2';
      final indices = computeMiddleEllipsisIndices(topic, 20);
      expect(indices, isNotNull);

      final head = topic.substring(0, indices!.headEnd);
      final tail = topic.substring(indices.tailStart);

      expect(head.length + tail.length, 20);
      expect(head.startsWith('com.'), isTrue);
      expect(tail.endsWith('ORDERS_V2'), isTrue);
    });

    test('handles single-segment topic without dots', () {
      const topic = 'SingleLongTopicNameWithoutAnyDotsInside';
      final indices = computeMiddleEllipsisIndices(topic, 15);
      expect(indices, isNotNull);

      final head = topic.substring(0, indices!.headEnd);
      final tail = topic.substring(indices.tailStart);

      expect(head.length + tail.length, 15);
      expect(head, 'Singl');
      expect(tail, 'DotsInside');
    });

    test('handles edge cases with small maxVisibleChars', () {
      const topic = 'a.b.c';
      final indices = computeMiddleEllipsisIndices(topic, 2);
      expect(indices, isNotNull);
      final head = topic.substring(0, indices!.headEnd);
      final tail = topic.substring(indices.tailStart);
      expect(head.length + tail.length, 2);
    });
  });

  group('buildTopicNameSpans', () {
    const prefixStyle = TextStyle(
      color: Colors.grey,
      fontWeight: FontWeight.normal,
    );
    const leafStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
    );
    const highlightStyle = TextStyle(
      backgroundColor: Colors.yellow,
      color: Colors.blue,
    );
    const ellipsisStyle = TextStyle(color: Colors.grey);

    test(
      'builds hierarchical spans without truncation when headEnd and tailStart are null',
      () {
        const topic = 'com.company.orders';
        final spans = buildTopicNameSpans(
          topicName: topic,
          prefixStyle: prefixStyle,
          leafStyle: leafStyle,
          highlightStyle: highlightStyle,
          ellipsisStyle: ellipsisStyle,
        );

        expect(spans.length, 2);
        expect(spans[0].text, 'com.company.');
        expect(spans[0].style, prefixStyle);
        expect(spans[1].text, 'orders');
        expect(spans[1].style, leafStyle);
      },
    );

    test('inserts ellipsis between head and tail ranges', () {
      const topic = 'dataops.cdc.db2.jdbc.LKW_ORDER';
      final spans = buildTopicNameSpans(
        topicName: topic,
        headEnd: 7, // 'dataops'
        tailStart: 21, // 'LKW_ORDER'
        prefixStyle: prefixStyle,
        leafStyle: leafStyle,
        highlightStyle: highlightStyle,
        ellipsisStyle: ellipsisStyle,
      );

      expect(spans.length, 3);
      expect(spans[0].text, 'dataops');
      expect(spans[0].style, prefixStyle);
      expect(spans[1].text, '…');
      expect(spans[1].style, ellipsisStyle);
      expect(spans[2].text, 'LKW_ORDER');
      expect(spans[2].style, leafStyle);
    });

    test('highlights matching substring case-insensitively', () {
      const topic = 'kaenup.lopoco.temp.migrationPreSelection';
      final spans = buildTopicNameSpans(
        topicName: topic,
        prefixStyle: prefixStyle,
        leafStyle: leafStyle,
        highlightStyle: highlightStyle,
        ellipsisStyle: ellipsisStyle,
        highlightQuery: 'migration',
      );

      expect(spans.length, 3);
      expect(spans[0].text, 'kaenup.lopoco.temp.');
      expect(spans[1].text, 'migration');
      expect(spans[1].style?.backgroundColor, Colors.yellow);
      expect(spans[2].text, 'PreSelection');
      expect(spans[2].style?.backgroundColor, isNull);
    });
  });

  group('fitTopicNameToWidth', () {
    const prefixStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.normal);
    const leafStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
    const highlightStyle = TextStyle(backgroundColor: Colors.yellow);
    const ellipsisStyle = TextStyle(fontSize: 14, color: Colors.grey);

    test('returns full spans if width is generous', () {
      const topic = 'com.example.topic';
      final spans = fitTopicNameToWidth(
        topicName: topic,
        maxWidth: 500,
        prefixStyle: prefixStyle,
        leafStyle: leafStyle,
        highlightStyle: highlightStyle,
        ellipsisStyle: ellipsisStyle,
      );

      final fullText = spans.map((s) => s.text).join();
      expect(fullText, 'com.example.topic');
      expect(fullText.contains('…'), isFalse);
    });

    test('truncates with ellipsis when constrained to narrow width', () {
      const topic = 'dataops.cdc.db2.jdbc.LKW_TRANSPORT_ORDER_HEADER';
      final spans = fitTopicNameToWidth(
        topicName: topic,
        maxWidth: 160,
        prefixStyle: prefixStyle,
        leafStyle: leafStyle,
        highlightStyle: highlightStyle,
        ellipsisStyle: ellipsisStyle,
      );

      final fullText = spans.map((s) => s.text).join();
      expect(fullText.contains('…'), isTrue);
      expect(fullText.startsWith('dat'), isTrue);
      expect(fullText.endsWith('HEADER'), isTrue);
    });
  });
}
