import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/ui/messages/incremental_sorted_merge.dart';

class _Item {
  final int primary;
  final int id;
  const _Item(this.primary, this.id);

  @override
  String toString() => '($_primary:$id)';

  int get _primary => primary;
}

int _compareItems(_Item a, _Item b) {
  final c = a.primary.compareTo(b.primary);
  return c != 0 ? c : a.id.compareTo(b.id);
}

void main() {
  group('mergeIncremental', () {
    test('handles empty previous and empty added lists', () {
      final a = const _Item(1, 1);
      final b = const _Item(2, 2);

      expect(
        mergeIncremental<_Item>(
          const [],
          retain: (_) => true,
          added: [b, a],
          compare: _compareItems,
        ),
        [a, b],
      );

      expect(
        mergeIncremental<_Item>(
          [a, b],
          retain: (_) => true,
          added: const [],
          compare: _compareItems,
        ),
        [a, b],
      );

      expect(
        mergeIncremental<_Item>(
          [a, b],
          retain: (item) => item != a,
          added: const [],
          compare: _compareItems,
        ),
        [b],
      );
    });

    test(
      'matches full List.sort on random inputs with duplicate primary keys',
      () {
        final rng = Random(42);
        for (var trial = 0; trial < 30; trial++) {
          final prevCount = rng.nextInt(80) + 10;
          final addCount = rng.nextInt(40) + 1;

          var nextId = 0;
          final previous = [
            for (var i = 0; i < prevCount; i++)
              _Item(rng.nextInt(10), nextId++),
          ]..sort(_compareItems);

          final evicted = <_Item>{};
          for (final item in previous) {
            if (rng.nextInt(4) == 0) {
              evicted.add(item);
            }
          }

          final added = [
            for (var i = 0; i < addCount; i++) _Item(rng.nextInt(10), nextId++),
          ];

          final merged = mergeIncremental<_Item>(
            previous,
            retain: (item) => !evicted.contains(item),
            added: added,
            compare: _compareItems,
          );

          final expected = [
            ...previous.where((item) => !evicted.contains(item)),
            ...added,
          ]..sort(_compareItems);

          expect(merged, expected);
        }
      },
    );

    test('uses O(k log N) comparisons instead of re-sorting previous', () {
      const n = 5000;
      const k = 20;
      final previous = [for (var i = 0; i < n; i++) _Item(i * 2, i)];
      final added = [for (var i = 0; i < k; i++) _Item(i * 250 + 1, n + i)];

      var comparisons = 0;
      final merged = mergeIncremental<_Item>(
        previous,
        retain: (_) => true,
        added: added,
        compare: (a, b) {
          comparisons++;
          return _compareItems(a, b);
        },
      );

      expect(merged.length, n + k);
      // k log2(k) + k log2(N) ~ 20*5 + 20*13 = 360, far below N log2(N) ~ 60,000
      expect(comparisons, lessThan(800));
    });
  });
}
