import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/utils/nested_value_decoder.dart';

const int defaultMaxRawRowChars = 1024;
const int defaultMaxRawMatches = 100000;
const int syncRawSearchThreshold = 64 * 1024;

final bool isTestMode =
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Computes the start UTF-16 code unit offset of each display row.
///
/// A row ends after `\n`, or after [maxRowChars] UTF-16 code units, whichever
/// comes first, without splitting UTF-16 surrogate pairs. A trailing `\n` does
/// not create an extra empty row.
Int32List computeRawRowIndex(
  String text, {
  int maxRowChars = defaultMaxRawRowChars,
}) {
  if (text.isEmpty) return Int32List(0);
  final starts = <int>[];
  var start = 0;
  final len = text.length;
  while (start < len) {
    starts.add(start);
    final limit = math.min(start + maxRowChars, len);
    var pos = start;
    while (pos < limit && text.codeUnitAt(pos) != 0x0A) {
      pos++;
    }
    if (pos < limit) {
      start = pos + 1;
    } else {
      var cut = limit;
      if (cut < len &&
          cut - 1 > start &&
          _isHighSurrogate(text.codeUnitAt(cut - 1)) &&
          _isLowSurrogate(text.codeUnitAt(cut))) {
        cut--;
      }
      start = cut;
    }
  }
  return Int32List.fromList(starts);
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

/// Computes display row start offsets off the UI thread (synchronous in tests).
Future<Int32List> computeRawRowIndexInIsolate(
  String text, {
  int maxRowChars = defaultMaxRawRowChars,
}) async {
  if (isTestMode) {
    return computeRawRowIndex(text, maxRowChars: maxRowChars);
  }
  return compute(
    (({String text, int maxRowChars}) args) =>
        computeRawRowIndex(args.text, maxRowChars: args.maxRowChars),
    (text: text, maxRowChars: maxRowChars),
  );
}

/// Returns the exclusive end offset of display row [rowIndex] with its
/// trailing line break (`\n` or `\r\n`) removed.
int rawRowTextEnd(String text, Int32List rowStarts, int rowIndex) {
  final start = rowStarts[rowIndex];
  var end = rowIndex + 1 < rowStarts.length
      ? rowStarts[rowIndex + 1]
      : text.length;
  if (end > start && text.codeUnitAt(end - 1) == 0x0A) {
    end--;
    if (end > start && text.codeUnitAt(end - 1) == 0x0D) {
      end--;
    }
  }
  return end;
}

String _asciiLowerCase(String input) {
  final units = Uint16List(input.length);
  for (var i = 0; i < input.length; i++) {
    final c = input.codeUnitAt(i);
    units[i] = (c >= 0x41 && c <= 0x5A) ? c + 32 : c;
  }
  return String.fromCharCodes(units);
}

/// Finds non-overlapping case-insensitive match start offsets in [text] up to
/// [cap] matches, returning whether additional matches beyond [cap] exist.
({Int32List offsets, bool capped}) findRawMatches(
  String text,
  String query, {
  int cap = defaultMaxRawMatches,
}) {
  if (query.isEmpty || text.isEmpty || cap <= 0) {
    return (offsets: Int32List(0), capped: false);
  }
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final useUnicodeLower =
      lowerText.length == text.length && lowerQuery.length == query.length;
  final searchText = useUnicodeLower ? lowerText : _asciiLowerCase(text);
  final searchQuery = useUnicodeLower ? lowerQuery : _asciiLowerCase(query);

  final offsets = <int>[];
  var capped = false;
  var index = 0;
  final qLen = searchQuery.length;
  while (true) {
    final found = searchText.indexOf(searchQuery, index);
    if (found == -1) break;
    if (offsets.length >= cap) {
      capped = true;
      break;
    }
    offsets.add(found);
    index = found + qLen;
  }
  return (offsets: Int32List.fromList(offsets), capped: capped);
}

/// Runs [findRawMatches] off the UI thread for payloads >= 64 KiB (synchronous
/// below 64 KiB and under `flutter test`).
Future<({Int32List offsets, bool capped})> findRawMatchesInIsolate(
  String text,
  String query, {
  int cap = defaultMaxRawMatches,
}) async {
  if (isTestMode || text.length < syncRawSearchThreshold) {
    return findRawMatches(text, query, cap: cap);
  }
  return compute(
    (({String text, String query, int cap}) args) =>
        findRawMatches(args.text, args.query, cap: args.cap),
    (text: text, query: query, cap: cap),
  );
}

/// Parses a JSON string in a background isolate (synchronously in test mode or
/// below [syncDecodeThreshold]).
Future<dynamic> parseJsonInIsolate(String rawJson) async {
  if (isTestMode || rawJson.length < syncDecodeThreshold) {
    return _decodeJson(rawJson);
  }
  return compute(_decodeJson, rawJson);
}

/// Decodes a nested value on demand in a background isolate (synchronously in
/// test mode or below [syncDecodeThreshold]).
Future<DecodeResult> decodeValueAsync(Object input, DecodeKind kind) async {
  final int inputLength = input is String
      ? input.length
      : (input as Uint8List).length;
  if (isTestMode || inputLength < syncDecodeThreshold) {
    return decodeValue(input, kind);
  }
  return compute(_decodeNestedValue, (input: input, kind: kind));
}

DecodeResult _decodeNestedValue(({Object input, DecodeKind kind}) args) {
  return decodeValue(args.input, args.kind);
}

dynamic _decodeJson(String rawJson) {
  return json.decode(rawJson);
}

int _hexNibble(int codeUnit) {
  if (codeUnit >= 0x30 && codeUnit <= 0x39) return codeUnit - 0x30;
  if (codeUnit >= 0x41 && codeUnit <= 0x46) return codeUnit - 0x41 + 10;
  if (codeUnit >= 0x61 && codeUnit <= 0x66) return codeUnit - 0x61 + 10;
  return -1;
}

/// Parses a hex string into a [Uint8List] in a background isolate.
///
/// Stops at the first invalid hex pair and ignores a trailing odd nibble.
Future<Uint8List> parseHexToBytesInIsolate(String hexStr) async {
  if (isTestMode) return _hexToBytes(hexStr);
  return compute(_hexToBytes, hexStr);
}

Uint8List _hexToBytes(String hex) {
  final maxBytes = hex.length ~/ 2;
  final out = Uint8List(maxBytes);
  var count = 0;
  for (var i = 0; i + 1 < hex.length; i += 2) {
    final hi = _hexNibble(hex.codeUnitAt(i));
    final lo = _hexNibble(hex.codeUnitAt(i + 1));
    if (hi < 0 || lo < 0) break;
    out[count++] = (hi << 4) | lo;
  }
  return count == maxBytes ? out : Uint8List.sublistView(out, 0, count);
}

/// Formats a single 16-byte row at [rowIndex] without a trailing newline.
String formatHexRow(List<int> bytes, int rowIndex) {
  final offset = rowIndex * 16;
  final buffer = StringBuffer();
  buffer.write('${offset.toRadixString(16).padLeft(8, '0')}  ');
  for (var j = 0; j < 16; j++) {
    if (offset + j < bytes.length) {
      buffer.write('${bytes[offset + j].toRadixString(16).padLeft(2, '0')} ');
    } else {
      buffer.write('   ');
    }
    if (j == 7) buffer.write(' ');
  }
  buffer.write(' |');
  for (var j = 0; j < 16; j++) {
    if (offset + j < bytes.length) {
      final byte = bytes[offset + j];
      if (byte >= 32 && byte <= 126) {
        buffer.writeCharCode(byte);
      } else {
        buffer.write('.');
      }
    }
  }
  buffer.write('|');
  return buffer.toString();
}

/// Generates a formatted hex dump string in a background isolate.
Future<String> generateHexDumpInIsolate(List<int> bytes) async {
  if (isTestMode) return _generateHexDump(bytes);
  return compute(_generateHexDump, bytes);
}

String _generateHexDump(List<int> bytes) {
  final rowCount = (bytes.length + 15) ~/ 16;
  final buffer = StringBuffer();
  for (var row = 0; row < rowCount; row++) {
    buffer.write(formatHexRow(bytes, row));
    buffer.write('\n');
  }
  return buffer.toString();
}
