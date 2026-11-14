import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/utils/nested_value_decoder.dart';
import 'package:kafkalyzer/src/utils/payload_processing_isolate.dart';

void main() {
  group('decodeValue - json', () {
    test('decodes valid JSON object and array', () {
      final objResult = decodeValue('{"a": 1, "b": [2, 3]}', DecodeKind.json);
      expect(objResult, isA<DecodedJson>());
      expect((objResult as DecodedJson).value, {
        'a': 1,
        'b': [2, 3],
      });
    });

    test('decodes JSON string literal as DecodedJson(String) for chaining', () {
      final strResult = decodeValue('"{\\"nested\\": true}"', DecodeKind.json);
      expect(strResult, isA<DecodedJson>());
      final inner = (strResult as DecodedJson).value;
      expect(inner, '{"nested": true}');

      final second = decodeValue(inner!, DecodeKind.json);
      expect(second, isA<DecodedJson>());
      expect((second as DecodedJson).value, {'nested': true});
    });

    test('returns invalidJson for malformed JSON', () {
      final res = decodeValue('{bad json', DecodeKind.json);
      expect(res, isA<DecodeFailure>());
      expect((res as DecodeFailure).error, DecodeError.invalidJson);
    });
  });

  group('decodeValue - base64', () {
    test(
      'decodes standard, URL-safe, unpadded, and multi-line Base64 text',
      () {
        const sample = '{"hello": "world?"}'; // includes chars producing + / =
        final std = base64.encode(utf8.encode(sample));
        final urlSafeUnpadded = base64Url
            .encode(utf8.encode(sample))
            .replaceAll('=', '');
        final multiLine = '${std.substring(0, 8)}\n  ${std.substring(8)}';

        for (final encoded in [std, urlSafeUnpadded, multiLine]) {
          final res = decodeValue(encoded, DecodeKind.base64);
          expect(res, isA<DecodedText>());
          expect((res as DecodedText).text, sample);
        }
      },
    );

    test('classifies non-UTF-8 Base64 output as DecodedBytes', () {
      final rawBytes = Uint8List.fromList([0xFF, 0xFE, 0x00, 0x01, 0x80]);
      final encoded = base64.encode(rawBytes);

      final res = decodeValue(encoded, DecodeKind.base64);
      expect(res, isA<DecodedBytes>());
      expect((res as DecodedBytes).bytes, rawBytes);
    });

    test('returns invalidBase64 for malformed Base64', () {
      final res = decodeValue('not!valid!base64!', DecodeKind.base64);
      expect(res, isA<DecodeFailure>());
      expect((res as DecodeFailure).error, DecodeError.invalidBase64);
    });
  });

  group('decodeValue - gzip', () {
    test('decompresses gzip from Base64 text and from raw Uint8List', () {
      const text = '{"compressed": true, "count": 42}';
      final gzBytes = Uint8List.fromList(gzip.encode(utf8.encode(text)));
      final b64 = base64.encode(gzBytes);

      final fromText = decodeValue(b64, DecodeKind.gzip);
      expect(fromText, isA<DecodedText>());
      expect((fromText as DecodedText).text, text);

      final fromBytes = decodeValue(gzBytes, DecodeKind.gzip);
      expect(fromBytes, isA<DecodedText>());
      expect((fromBytes as DecodedText).text, text);
    });

    test('returns DecodedBytes when gunzipped payload is non-UTF-8', () {
      final rawBytes = Uint8List.fromList([0xFF, 0x00, 0xAB, 0xCD]);
      final gzBytes = Uint8List.fromList(gzip.encode(rawBytes));

      final res = decodeValue(gzBytes, DecodeKind.gzip);
      expect(res, isA<DecodedBytes>());
      expect((res as DecodedBytes).bytes, rawBytes);
    });

    test('returns notGzip when magic bytes do not match', () {
      final notGz = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]);
      final res = decodeValue(notGz, DecodeKind.gzip);
      expect(res, isA<DecodeFailure>());
      expect((res as DecodeFailure).error, DecodeError.notGzip);

      final b64NotGz = decodeValue(base64.encode(notGz), DecodeKind.gzip);
      expect(b64NotGz, isA<DecodeFailure>());
      expect((b64NotGz as DecodeFailure).error, DecodeError.notGzip);
    });

    test(
      'returns corruptGzip when magic bytes match but stream is corrupt',
      () {
        final valid = gzip.encode(utf8.encode('hello corrupt gzip world'));
        final corrupt = Uint8List.fromList(valid);
        corrupt[10] ^= 0xFF;
        corrupt[11] ^= 0xFF;
        final res = decodeValue(corrupt, DecodeKind.gzip);
        expect(res, isA<DecodeFailure>());
        expect((res as DecodeFailure).error, DecodeError.corruptGzip);
      },
    );
  });

  group('decodeValue - size limits', () {
    test('returns inputTooLarge when input exceeds 8 MiB', () {
      final big = 'a' * (maxDecodeInputSize + 1);
      final res = decodeValue(big, DecodeKind.json);
      expect(res, isA<DecodeFailure>());
      final failure = res as DecodeFailure;
      expect(failure.error, DecodeError.inputTooLarge);
      expect(failure.limit, maxDecodeInputSize);
    });

    test('stops gzip bomb above 16 MiB and returns outputTooLarge', () {
      // 17 MiB of zeros compresses to ~17 KiB (well under 8 MiB input cap).
      final zeros = Uint8List(17 * 1024 * 1024);
      final gzBomb = Uint8List.fromList(gzip.encode(zeros));
      expect(gzBomb.length, lessThan(maxDecodeInputSize));

      final res = decodeValue(gzBomb, DecodeKind.gzip);
      expect(res, isA<DecodeFailure>());
      final failure = res as DecodeFailure;
      expect(failure.error, DecodeError.outputTooLarge);
      expect(failure.limit, maxDecodeOutputSize);
    });
  });

  group('decodeValueAsync & parseJsonInIsolate', () {
    test('decodeValueAsync decodes small and large inputs', () async {
      final small = await decodeValueAsync('{"ok": 1}', DecodeKind.json);
      expect(small, isA<DecodedJson>());
      expect((small as DecodedJson).value, {'ok': 1});

      final largePayload = '{"s": "${'x' * (syncDecodeThreshold + 1024)}"}';
      final large = await decodeValueAsync(largePayload, DecodeKind.json);
      expect(large, isA<DecodedJson>());
      expect(
        ((large as DecodedJson).value as Map)['s'],
        hasLength(syncDecodeThreshold + 1024),
      );
    });

    test(
      'parseJsonInIsolate handles below and above 32 KiB threshold',
      () async {
        final small = await parseJsonInIsolate('{"a":1}');
        expect(small, {'a': 1});

        final largeStr = '{"k":"${'y' * (syncDecodeThreshold + 512)}"}';
        final large = await parseJsonInIsolate(largeStr);
        expect((large as Map)['k'], hasLength(syncDecodeThreshold + 512));
      },
    );
  });

  group('guessEpoch', () {
    test(
      'identifies seconds, milliseconds, microseconds, and nanoseconds bounds',
      () {
        // Lower bounds: 2000-01-01T00:00:00Z
        expect(guessEpoch(946684800)?.unit, EpochUnit.seconds);
        expect(guessEpoch(946684800)?.utc, DateTime.utc(2000, 1, 1));
        expect(guessEpoch(946684800000)?.unit, EpochUnit.milliseconds);
        expect(guessEpoch(946684800000000)?.unit, EpochUnit.microseconds);
        expect(guessEpoch(946684800000000000)?.unit, EpochUnit.nanoseconds);

        // Upper bounds - 1
        expect(guessEpoch(4102444800 - 1)?.unit, EpochUnit.seconds);
        expect(guessEpoch(4102444800000 - 1)?.unit, EpochUnit.milliseconds);
        expect(guessEpoch(4102444800000000 - 1)?.unit, EpochUnit.microseconds);
        expect(
          guessEpoch(4102444800000000000 - 1)?.unit,
          EpochUnit.nanoseconds,
        );
      },
    );

    test(
      'returns null for non-ints, negatives, small ints, and values between ranges',
      () {
        expect(guessEpoch(42), isNull);
        expect(guessEpoch(3.5), isNull);
        expect(guessEpoch(1768812660.123), isNull);
        expect(guessEpoch(-1700000000), isNull);
        expect(guessEpoch('1768812660123'), isNull);
        expect(guessEpoch(null), isNull);

        // Upper bounds (exclusive) and gaps between ranges
        expect(guessEpoch(4102444800), isNull);
        expect(guessEpoch(946684800000 - 1), isNull);
        expect(guessEpoch(4102444800000), isNull);
        expect(guessEpoch(946684800000000 - 1), isNull);
        expect(guessEpoch(4102444800000000), isNull);
        expect(guessEpoch(946684800000000000 - 1), isNull);
        expect(guessEpoch(4102444800000000000), isNull);
      },
    );
  });

  group('tryParseHexFallback', () {
    test('parses 0x + hex pairs and rejects non-hex or odd length', () {
      expect(
        tryParseHexFallback('0x00ff10'),
        Uint8List.fromList([0x00, 0xff, 0x10]),
      );
      expect(tryParseHexFallback('0x'), isNull);
      expect(tryParseHexFallback('0xabc'), isNull);
      expect(tryParseHexFallback('hello'), isNull);
    });
  });
}
