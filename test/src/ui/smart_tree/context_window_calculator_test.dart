import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/ui/smart_tree/context_window_calculator.dart';

void main() {
  group('ContextWindowCalculator', () {
    test('returns empty list when totalLength is 0 or negative', () {
      expect(
        ContextWindowCalculator.calculateSegments(
          totalLength: 0,
          matchIndices: {0},
        ),
        isEmpty,
      );
      expect(
        ContextWindowCalculator.calculateSegments(
          totalLength: -5,
          matchIndices: {0},
        ),
        isEmpty,
      );
    });

    test('returns all items as VisibleItemSegment when matchIndices is empty', () {
      final segments = ContextWindowCalculator.calculateSegments(
        totalLength: 5,
        matchIndices: {},
      );

      expect(segments.length, equals(5));
      for (int i = 0; i < 5; i++) {
        expect(segments[i], equals(VisibleItemSegment(index: i, isDirectMatch: false)));
      }
    });

    test('returns all items when forceShowAll is true, preserving isDirectMatch', () {
      final segments = ContextWindowCalculator.calculateSegments(
        totalLength: 5,
        matchIndices: {2},
        forceShowAll: true,
      );

      expect(segments.length, equals(5));
      expect(segments[0], equals(const VisibleItemSegment(index: 0, isDirectMatch: false)));
      expect(segments[1], equals(const VisibleItemSegment(index: 1, isDirectMatch: false)));
      expect(segments[2], equals(const VisibleItemSegment(index: 2, isDirectMatch: true)));
      expect(segments[3], equals(const VisibleItemSegment(index: 3, isDirectMatch: false)));
      expect(segments[4], equals(const VisibleItemSegment(index: 4, isDirectMatch: false)));
    });

    test('segments array with single match at start (index 0, radius 1)', () {
      final segments = ContextWindowCalculator.calculateSegments(
        totalLength: 10,
        matchIndices: {0},
        radius: 1,
      );

      expect(segments.length, equals(3));
      expect(segments[0], equals(const VisibleItemSegment(index: 0, isDirectMatch: true)));
      expect(segments[1], equals(const VisibleItemSegment(index: 1, isDirectMatch: false)));
      expect(segments[2], equals(const CollapsedRangeSegment(startIndex: 2, endIndex: 9)));
      expect((segments[2] as CollapsedRangeSegment).count, equals(8));
    });

    test('segments array with single match at end (index 9, radius 1)', () {
      final segments = ContextWindowCalculator.calculateSegments(
        totalLength: 10,
        matchIndices: {9},
        radius: 1,
      );

      expect(segments.length, equals(3));
      expect(segments[0], equals(const CollapsedRangeSegment(startIndex: 0, endIndex: 7)));
      expect((segments[0] as CollapsedRangeSegment).count, equals(8));
      expect(segments[1], equals(const VisibleItemSegment(index: 8, isDirectMatch: false)));
      expect(segments[2], equals(const VisibleItemSegment(index: 9, isDirectMatch: true)));
    });

    test('segments array with match in middle (index 14 in array of 30, radius 1)', () {
      final segments = ContextWindowCalculator.calculateSegments(
        totalLength: 30,
        matchIndices: {14},
        radius: 1,
      );

      expect(segments.length, equals(5));
      expect(segments[0], equals(const CollapsedRangeSegment(startIndex: 0, endIndex: 12)));
      expect((segments[0] as CollapsedRangeSegment).count, equals(13));
      expect(segments[1], equals(const VisibleItemSegment(index: 13, isDirectMatch: false)));
      expect(segments[2], equals(const VisibleItemSegment(index: 14, isDirectMatch: true)));
      expect(segments[3], equals(const VisibleItemSegment(index: 15, isDirectMatch: false)));
      expect(segments[4], equals(const CollapsedRangeSegment(startIndex: 16, endIndex: 29)));
      expect((segments[4] as CollapsedRangeSegment).count, equals(14));
    });

    test('merges overlapping match radii correctly', () {
      // Matches at 5 and 7 with radius 1:
      // match 5 visible: 4, 5, 6
      // match 7 visible: 6, 7, 8
      // Combined visible: 4..8
      final segments = ContextWindowCalculator.calculateSegments(
        totalLength: 20,
        matchIndices: {5, 7},
        radius: 1,
      );

      expect(segments.length, equals(7));
      expect(segments[0], equals(const CollapsedRangeSegment(startIndex: 0, endIndex: 3)));
      expect(segments[1], equals(const VisibleItemSegment(index: 4, isDirectMatch: false)));
      expect(segments[2], equals(const VisibleItemSegment(index: 5, isDirectMatch: true)));
      expect(segments[3], equals(const VisibleItemSegment(index: 6, isDirectMatch: false)));
      expect(segments[4], equals(const VisibleItemSegment(index: 7, isDirectMatch: true)));
      expect(segments[5], equals(const VisibleItemSegment(index: 8, isDirectMatch: false)));
      expect(segments[6], equals(const CollapsedRangeSegment(startIndex: 9, endIndex: 19)));
    });

    test('ignores match indices out of bounds safely', () {
      final segments = ContextWindowCalculator.calculateSegments(
        totalLength: 5,
        matchIndices: {-1, 10},
        radius: 1,
      );

      expect(segments.length, equals(5));
      for (int i = 0; i < 5; i++) {
        expect(segments[i], equals(VisibleItemSegment(index: i, isDirectMatch: false)));
      }
    });
  });
}
