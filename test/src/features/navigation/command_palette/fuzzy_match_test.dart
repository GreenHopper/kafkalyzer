import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/navigation/command_palette/fuzzy_match.dart';

void main() {
  test('matches subsequence case-insensitively and returns indices', () {
    final match = fuzzyMatch('ordevt', 'orders.events');
    expect(match, isNotNull);
    expect(match!.matchedIndices.length, 6);
    expect(
      match.matchedIndices.map((i) => 'orders.events'[i]).join(),
      'ordevt',
    );
  });

  test('ranks exact > prefix > scattered', () {
    final exact = fuzzyMatch('orders', 'orders')!;
    final prefix = fuzzyMatch('orders', 'orders.events')!;
    final scattered = fuzzyMatch('orders', 'ops-reader-dlq-events')!;

    expect(exact.score, greaterThan(prefix.score));
    expect(prefix.score, greaterThan(scattered.score));
  });

  test('returns null when query does not match', () {
    expect(fuzzyMatch('xyz', 'orders.events'), isNull);
    expect(fuzzyMatch('orders.events.extra', 'orders.events'), isNull);
  });

  test('empty query returns zero score with empty indices', () {
    final match = fuzzyMatch('', 'orders.events');
    expect(match, isNotNull);
    expect(match!.score, 0);
    expect(match.matchedIndices, isEmpty);
  });

  test('word-boundary and camelCase bonuses prefer boundary starts', () {
    final boundary = fuzzyMatch('oe', 'orders.events')!;
    final nonBoundary = fuzzyMatch('oe', 'cooperate')!;
    expect(boundary.score, greaterThan(nonBoundary.score));

    final camel = fuzzyMatch('cL', 'consumerLag')!;
    expect(camel.matchedIndices, [0, 8]);
  });

  test('handles non-ASCII names', () {
    final match = fuzzyMatch('üö', 'büro-über-öl');
    expect(match, isNotNull);
    expect(match!.matchedIndices.length, 2);
  });
}
