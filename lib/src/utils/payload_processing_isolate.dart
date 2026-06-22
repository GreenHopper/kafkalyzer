import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

final bool isTestMode =
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Parses a JSON string in a background isolate.
Future<dynamic> parseJsonInIsolate(String rawJson) async {
  if (isTestMode) return _decodeJson(rawJson);
  return compute(_decodeJson, rawJson);
}

dynamic _decodeJson(String rawJson) {
  return json.decode(rawJson);
}

/// Parses a hex string into a list of bytes in a background isolate.
Future<List<int>> parseHexToBytesInIsolate(String hexStr) async {
  if (isTestMode) return _hexToBytes(hexStr);
  return compute(_hexToBytes, hexStr);
}

List<int> _hexToBytes(String hex) {
  List<int> bytes = [];
  try {
    for (int i = 0; i < hex.length; i += 2) {
      if (i + 1 < hex.length) {
        bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
      }
    }
  } catch (_) {
    // Ignore parsing errors for partial hex
  }
  return bytes;
}

/// Generates a formatted hex dump string in a background isolate.
Future<String> generateHexDumpInIsolate(List<int> bytes) async {
  if (isTestMode) return _generateHexDump(bytes);
  return compute(_generateHexDump, bytes);
}

String _generateHexDump(List<int> bytes) {
  final buffer = StringBuffer();
  for (var i = 0; i < bytes.length; i += 16) {
    buffer.write('${i.toRadixString(16).padLeft(8, '0')}  ');
    for (var j = 0; j < 16; j++) {
      if (i + j < bytes.length) {
        buffer.write('${bytes[i + j].toRadixString(16).padLeft(2, '0')} ');
      } else {
        buffer.write('   ');
      }
      if (j == 7) buffer.write(' ');
    }
    buffer.write(' |');
    for (var j = 0; j < 16; j++) {
      if (i + j < bytes.length) {
        final byte = bytes[i + j];
        if (byte >= 32 && byte <= 126) {
          buffer.writeCharCode(byte);
        } else {
          buffer.write('.');
        }
      }
    }
    buffer.write('|\n');
  }
  return buffer.toString();
}
