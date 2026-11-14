import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Extracts top-level ICU placeholder names (at brace depth 0 -> 1, before
/// any comma or closing brace, skipping plural/select inner branches).
Set<String> extractTopLevelPlaceholders(String message) {
  final result = <String>{};
  var depth = 0;
  var i = 0;
  while (i < message.length) {
    final ch = message[i];
    if (ch == "'") {
      // Skip ICU single-quoted escapes
      if (i + 1 < message.length && message[i + 1] == "'") {
        i += 2;
        continue;
      }
      i++;
      while (i < message.length) {
        if (message[i] == "'") {
          if (i + 1 < message.length && message[i + 1] == "'") {
            i += 2;
          } else {
            i++;
            break;
          }
        } else {
          i++;
        }
      }
      continue;
    }
    if (ch == '{') {
      if (depth == 0) {
        // Read identifier right after '{'
        final start = i + 1;
        var end = start;
        while (end < message.length &&
            RegExp(r'[a-zA-Z0-9_]').hasMatch(message[end])) {
          end++;
        }
        if (end > start) {
          result.add(message.substring(start, end));
        }
      }
      depth++;
    } else if (ch == '}') {
      if (depth > 0) depth--;
    }
    i++;
  }
  return result;
}

Map<String, int> countTopLevelKeys(String rawText) {
  final pattern = RegExp(r'^  "([^"]+)":', multiLine: true);
  final counts = <String, int>{};
  for (final match in pattern.allMatches(rawText)) {
    final key = match.group(1)!;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}

void main() {
  final enFile = File('lib/l10n/app_en.arb');
  final deFile = File('lib/l10n/app_de.arb');

  test('ARB files have no duplicate top-level keys', () {
    for (final file in [enFile, deFile]) {
      final raw = file.readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final counts = countTopLevelKeys(raw);
      final totalOccurrences = counts.values.fold<int>(0, (a, b) => a + b);
      final duplicateEntries = counts.entries
          .where((e) => e.value > 1)
          .toList();
      final duplicateCount = duplicateEntries.fold<int>(
        0,
        (sum, e) => sum + (e.value - 1),
      );
      expect(
        totalOccurrences,
        decoded.length + duplicateCount,
        reason:
            '${file.path} key regex count should match decoded + duplicates',
      );
      expect(
        duplicateEntries.map((e) => '${e.key} (x${e.value})').toList(),
        isEmpty,
        reason: 'Duplicate top-level keys found in ${file.path}',
      );
    }
  });

  test('app_en.arb and app_de.arb have identical message key sets', () {
    final enJson =
        jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
    final deJson =
        jsonDecode(deFile.readAsStringSync()) as Map<String, dynamic>;

    final enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();
    final deKeys = deJson.keys.where((k) => !k.startsWith('@')).toSet();

    expect(
      enKeys.difference(deKeys),
      isEmpty,
      reason: 'Keys present in app_en.arb but missing in app_de.arb',
    );
    expect(
      deKeys.difference(enKeys),
      isEmpty,
      reason: 'Keys present in app_de.arb but missing in app_en.arb',
    );
  });

  test(
    'top-level ICU placeholders match between en and de and are declared in @key.placeholders',
    () {
      final enJson =
          jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      final deJson =
          jsonDecode(deFile.readAsStringSync()) as Map<String, dynamic>;

      final enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();
      final deKeys = deJson.keys.where((k) => !k.startsWith('@')).toSet();
      final commonKeys = enKeys.intersection(deKeys);

      final mismatches = <String>[];
      final undeclared = <String>[];

      for (final key in commonKeys) {
        final enVal = enJson[key];
        final deVal = deJson[key];
        if (enVal is! String || deVal is! String) continue;

        final enPlaceholders = extractTopLevelPlaceholders(enVal);
        final dePlaceholders = extractTopLevelPlaceholders(deVal);

        if (!enPlaceholders.containsAll(dePlaceholders) ||
            !dePlaceholders.containsAll(enPlaceholders)) {
          mismatches.add('$key: en=$enPlaceholders de=$dePlaceholders');
        }

        if (enPlaceholders.isNotEmpty) {
          final meta = enJson['@$key'] as Map<String, dynamic>?;
          final declared =
              (meta?['placeholders'] as Map<String, dynamic>?)?.keys.toSet() ??
              <String>{};
          final missing = enPlaceholders.difference(declared);
          if (missing.isNotEmpty) {
            undeclared.add('$key: missing @key.placeholders for $missing');
          }
        }
      }

      expect(
        mismatches,
        isEmpty,
        reason: 'Placeholder mismatches between en and de',
      );
      expect(
        undeclared,
        isEmpty,
        reason: 'Undeclared placeholders in app_en.arb',
      );
    },
  );
}
