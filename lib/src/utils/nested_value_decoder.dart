import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Maximum input size (characters for text, bytes for binary) accepted by
/// [decodeValue].
const int maxDecodeInputSize = 8 * 1024 * 1024;

/// Maximum output size (bytes) produced by [decodeValue].
const int maxDecodeOutputSize = 16 * 1024 * 1024;

/// Input size below which decoding / JSON parsing runs synchronously without
/// spawning an isolate.
const int syncDecodeThreshold = 32 * 1024;

enum DecodeKind { json, base64, gzip }

enum DecodeError {
  invalidJson,
  invalidBase64,
  notGzip,
  corruptGzip,
  inputTooLarge,
  outputTooLarge,
}

sealed class DecodeResult {
  const DecodeResult();
}

final class DecodedJson extends DecodeResult {
  final Object? value;
  const DecodedJson(this.value);
}

final class DecodedText extends DecodeResult {
  final String text;
  const DecodedText(this.text);
}

final class DecodedBytes extends DecodeResult {
  final Uint8List bytes;
  const DecodedBytes(this.bytes);
}

final class DecodeFailure extends DecodeResult {
  final DecodeError error;
  final int? limit;
  const DecodeFailure(this.error, {this.limit});
}

enum EpochUnit { seconds, milliseconds, microseconds, nanoseconds }

final class EpochGuess {
  final DateTime utc;
  final EpochUnit unit;
  const EpochGuess(this.utc, this.unit);
}

const int _minEpochSec = 946684800; // 2000-01-01T00:00:00Z
const int _maxEpochSec = 4102444800; // 2100-01-01T00:00:00Z

/// Checks whether [value] is an integer within plausible epoch bounds
/// (2000-01-01 to 2100-01-01 UTC) in seconds, milliseconds, microseconds, or
/// nanoseconds.
EpochGuess? guessEpoch(Object? value) {
  if (value is! int) return null;
  if (value >= _minEpochSec && value < _maxEpochSec) {
    return EpochGuess(
      DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true),
      EpochUnit.seconds,
    );
  }
  if (value >= _minEpochSec * 1000 && value < _maxEpochSec * 1000) {
    return EpochGuess(
      DateTime.fromMillisecondsSinceEpoch(value, isUtc: true),
      EpochUnit.milliseconds,
    );
  }
  if (value >= _minEpochSec * 1000000 && value < _maxEpochSec * 1000000) {
    return EpochGuess(
      DateTime.fromMillisecondsSinceEpoch(value ~/ 1000, isUtc: true),
      EpochUnit.microseconds,
    );
  }
  if (value >= _minEpochSec * 1000000000 && value < _maxEpochSec * 1000000000) {
    return EpochGuess(
      DateTime.fromMillisecondsSinceEpoch(value ~/ 1000000, isUtc: true),
      EpochUnit.nanoseconds,
    );
  }
  return null;
}

/// Decodes [input] (`String` or `Uint8List`) on demand according to [kind].
DecodeResult decodeValue(Object input, DecodeKind kind) {
  final int inputLength;
  if (input is String) {
    inputLength = input.length;
  } else if (input is Uint8List) {
    inputLength = input.length;
  } else {
    throw ArgumentError.value(input, 'input', 'Expected String or Uint8List');
  }

  if (inputLength > maxDecodeInputSize) {
    return const DecodeFailure(
      DecodeError.inputTooLarge,
      limit: maxDecodeInputSize,
    );
  }

  switch (kind) {
    case DecodeKind.json:
      if (input is! String) {
        return const DecodeFailure(DecodeError.invalidJson);
      }
      try {
        return DecodedJson(json.decode(input));
      } on FormatException {
        return const DecodeFailure(DecodeError.invalidJson);
      }

    case DecodeKind.base64:
      if (input is! String) {
        return const DecodeFailure(DecodeError.invalidBase64);
      }
      final bytes = _decodeBase64Normalized(input);
      if (bytes == null) {
        return const DecodeFailure(DecodeError.invalidBase64);
      }
      return _classifyBytes(bytes);

    case DecodeKind.gzip:
      final Uint8List compressed;
      if (input is String) {
        final decoded = _decodeBase64Normalized(input);
        if (decoded == null) {
          return const DecodeFailure(DecodeError.invalidBase64);
        }
        compressed = decoded;
      } else {
        compressed = input as Uint8List;
      }
      return _gunzipBounded(compressed);
  }
}

Uint8List? _decodeBase64Normalized(String raw) {
  final sb = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final cu = raw.codeUnitAt(i);
    // Strip ASCII whitespace: space, tab, LF, VT, FF, CR
    if (cu == 0x20 ||
        cu == 0x09 ||
        cu == 0x0A ||
        cu == 0x0B ||
        cu == 0x0C ||
        cu == 0x0D) {
      continue;
    }
    if (cu == 0x2D) {
      // '-' -> '+'
      sb.writeCharCode(0x2B);
    } else if (cu == 0x5F) {
      // '_' -> '/'
      sb.writeCharCode(0x2F);
    } else {
      sb.writeCharCode(cu);
    }
  }

  var normalized = sb.toString();
  if (normalized.isEmpty) return Uint8List(0);
  final rem = normalized.length % 4;
  if (rem == 1) return null;
  if (rem == 2) {
    normalized = '$normalized==';
  } else if (rem == 3) {
    normalized = '$normalized=';
  }

  try {
    return base64.decode(normalized);
  } on FormatException {
    return null;
  }
}

DecodeResult _gunzipBounded(Uint8List compressed) {
  if (compressed.length < 2 || compressed[0] != 0x1F || compressed[1] != 0x8B) {
    return const DecodeFailure(DecodeError.notGzip);
  }

  final sink = _CappedByteSink(maxDecodeOutputSize);
  try {
    final conversion = GZipCodec().decoder.startChunkedConversion(sink);
    const chunkSize = 64 * 1024;
    for (var offset = 0; offset < compressed.length; offset += chunkSize) {
      final end = math.min(offset + chunkSize, compressed.length);
      conversion.add(Uint8List.sublistView(compressed, offset, end));
    }
    conversion.close();
  } on _OutputLimitExceeded {
    return const DecodeFailure(
      DecodeError.outputTooLarge,
      limit: maxDecodeOutputSize,
    );
  } on Object {
    return const DecodeFailure(DecodeError.corruptGzip);
  }

  return _classifyBytes(sink.takeBytes());
}

DecodeResult _classifyBytes(Uint8List bytes) {
  if (bytes.length > maxDecodeOutputSize) {
    return const DecodeFailure(
      DecodeError.outputTooLarge,
      limit: maxDecodeOutputSize,
    );
  }
  try {
    return DecodedText(utf8.decode(bytes, allowMalformed: false));
  } on FormatException {
    return DecodedBytes(bytes);
  }
}

final class _OutputLimitExceeded implements Exception {
  const _OutputLimitExceeded();
}

final class _CappedByteSink extends ByteConversionSink {
  final int _limit;
  final BytesBuilder _builder = BytesBuilder(copy: false);
  int _total = 0;

  _CappedByteSink(this._limit);

  @override
  void add(List<int> chunk) {
    _total += chunk.length;
    if (_total > _limit) {
      _builder.clear();
      throw const _OutputLimitExceeded();
    }
    _builder.add(chunk);
  }

  @override
  void close() {}

  Uint8List takeBytes() => _builder.takeBytes();
}

/// Regex matching Rust's binary header fallback format: `0x` followed by one or
/// more hex byte pairs.
final RegExp hexFallbackPattern = RegExp(r'^0x([0-9a-fA-F]{2})+$');

/// Parses a `0x...` hex fallback string into bytes, or returns `null` if it
/// does not match [hexFallbackPattern].
Uint8List? tryParseHexFallback(String value) {
  if (!hexFallbackPattern.hasMatch(value)) return null;
  final byteCount = (value.length - 2) ~/ 2;
  final out = Uint8List(byteCount);
  for (var i = 0; i < byteCount; i++) {
    final hi = _hexVal(value.codeUnitAt(2 + i * 2));
    final lo = _hexVal(value.codeUnitAt(2 + i * 2 + 1));
    out[i] = (hi << 4) | lo;
  }
  return out;
}

int _hexVal(int cu) {
  if (cu >= 0x30 && cu <= 0x39) return cu - 0x30;
  if (cu >= 0x41 && cu <= 0x46) return cu - 0x41 + 10;
  return cu - 0x61 + 10;
}
