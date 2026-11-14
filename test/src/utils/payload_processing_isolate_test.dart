import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/utils/payload_processing_isolate.dart';

void main() {
  group('computeRawRowIndex', () {
    test('returns empty index for empty text', () {
      expect(computeRawRowIndex(''), isEmpty);
    });

    test(
      'handles \\n, \\r\\n, and trailing newline without extra empty row',
      () {
        const text = 'alpha\nbeta\r\ngamma\n';
        final starts = computeRawRowIndex(text);
        expect(starts, [0, 6, 12]);
        expect(
          text.substring(starts[0], rawRowTextEnd(text, starts, 0)),
          'alpha',
        );
        expect(
          text.substring(starts[1], rawRowTextEnd(text, starts, 1)),
          'beta',
        );
        expect(
          text.substring(starts[2], rawRowTextEnd(text, starts, 2)),
          'gamma',
        );
      },
    );

    test(
      'splits 2 MB single line into <= 1024 char rows preserving all chars',
      () {
        final input = 'x' * (2 * 1024 * 1024 + 17);
        final starts = computeRawRowIndex(input);
        expect(starts.length, (input.length / 1024).ceil());
        final reconstructed = StringBuffer();
        for (var i = 0; i < starts.length; i++) {
          final end = rawRowTextEnd(input, starts, i);
          final row = input.substring(starts[i], end);
          expect(row.length, lessThanOrEqualTo(1024));
          reconstructed.write(row);
        }
        expect(reconstructed.toString(), input);
      },
    );

    test('does not split UTF-16 surrogate pair at cut position', () {
      // 1023 ASCII chars + 1 surrogate-pair emoji (2 UTF-16 code units: 1023, 1024)
      const emoji = '\u{1F600}';
      final input = '${'a' * 1023}$emoji${'b' * 10}';
      final starts = computeRawRowIndex(input, maxRowChars: 1024);
      expect(starts, [0, 1023]);
      expect(
        input.substring(starts[0], rawRowTextEnd(input, starts, 0)),
        'a' * 1023,
      );
      expect(
        input.substring(starts[1], rawRowTextEnd(input, starts, 1)),
        '$emoji${'b' * 10}',
      );
    });

    test('indexes 20 MB input cleanly', () async {
      final line = '${'a' * 99}\n';
      final input = line * 200000;
      final starts = await computeRawRowIndexInIsolate(input);
      expect(starts.length, 200000);
      expect(starts.first, 0);
      expect(starts.last, input.length - 100);
    });
  });

  group('findRawMatches', () {
    test('empty query returns empty offsets and capped false', () {
      final res = findRawMatches('hello world', '');
      expect(res.offsets, isEmpty);
      expect(res.capped, isFalse);
    });

    test('finds case-insensitive non-overlapping matches', () {
      final res = findRawMatches('ababa ABABA', 'aba');
      expect(res.offsets, [0, 6]);
      expect(res.capped, isFalse);
    });

    test(
      'preserves original offsets when Unicode lowercasing changes length',
      () {
        // '\u0130' (Turkish capital I with dot) lowercases to 'i\u0307' (length 2).
        const text = '\u0130abc_ABC';
        final res = findRawMatches(text, 'abc');
        expect(res.offsets, [1, 5]);
        expect(text.substring(res.offsets[0], res.offsets[0] + 3), 'abc');
        expect(text.substring(res.offsets[1], res.offsets[1] + 3), 'ABC');
      },
    );

    test('respects cap and sets capped flag only when more matches exist', () {
      final exact = findRawMatches('aaa', 'a', cap: 3);
      expect(exact.offsets, [0, 1, 2]);
      expect(exact.capped, isFalse);

      final over = findRawMatches('aaaa', 'a', cap: 3);
      expect(over.offsets, [0, 1, 2]);
      expect(over.capped, isTrue);
    });

    test('searches 20 MB input cleanly', () async {
      final chunk = '${'z' * 999}\n';
      final input = '${chunk * 19999}needle\n';
      final res = await findRawMatchesInIsolate(input, 'NEEDLE');
      expect(res.offsets, [19999 * 1000]);
      expect(res.capped, isFalse);
    });
  });

  group('parseHexToBytesInIsolate and formatHexRow', () {
    test(
      'decodes hex to Uint8List, stopping on invalid pair and ignoring odd nibble',
      () async {
        final bytes = await parseHexToBytesInIsolate('48656c6c6f');
        expect(bytes, isA<Uint8List>());
        expect(utf8.decode(bytes), 'Hello');

        // Trailing odd nibble ignored
        final odd = await parseHexToBytesInIsolate('48656');
        expect(odd, [0x48, 0x65]);

        // Stops on invalid hex pair
        final invalid = await parseHexToBytesInIsolate('4865ZZ6c');
        expect(invalid, [0x48, 0x65]);
      },
    );

    test(
      'formatHexRow matches generateHexDumpInIsolate for Hello World and pads partial row',
      () async {
        final bytes = Uint8List.fromList(utf8.encode('Hello World'));
        final fullDump = await generateHexDumpInIsolate(bytes);
        final row0 = formatHexRow(bytes, 0);
        expect(
          row0,
          '00000000  48 65 6c 6c 6f 20 57 6f  72 6c 64                 |Hello World|',
        );
        expect(fullDump, '$row0\n');
      },
    );
  });
}
