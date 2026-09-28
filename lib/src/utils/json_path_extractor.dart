import 'dart:convert';

/// A utility for extracting values from JSON data structures using dot-notation
/// and array-index JSON paths (e.g. `customer.name`, `leistungen[0].transportId`).
class JsonPathExtractor {
  /// Extracts a string representation of the value at [path] from a raw JSON [payload].
  ///
  /// Returns `null` if the payload is null, empty, unparseable, or the path does not exist.
  static String? extractFromPayload(String? payload, String path) {
    if (payload == null || payload.trim().isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(payload);
      return extract(decoded, path);
    } catch (_) {
      return null;
    }
  }

  /// Extracts a string representation of the value at [path] from decoded JSON [data].
  ///
  /// Returns `null` if [data] is null or the path cannot be resolved.
  static String? extract(dynamic data, String path) {
    final raw = extractRaw(data, path);
    if (raw == null) return null;
    if (raw is String) return raw;
    if (raw is num || raw is bool) return raw.toString();
    if (raw is Map || raw is List) {
      try {
        return jsonEncode(raw);
      } catch (_) {
        return raw.toString();
      }
    }
    return raw.toString();
  }

  /// Extracts the raw dynamic value at [path] from decoded JSON [data].
  ///
  /// Supports dot notation (`a.b.c`), list indices (`items[0]`, `items.0`),
  /// and arbitrary combinations (`order.items[0].sku`).
  static dynamic extractRaw(dynamic data, String path) {
    final cleanPath = normalizePath(path);
    if (cleanPath.isEmpty || data == null) return null;

    final tokens = _tokenize(cleanPath);
    dynamic current = data;

    for (final token in tokens) {
      if (current == null) return null;

      if (token is int) {
        if (current is List && token >= 0 && token < current.length) {
          current = current[token];
        } else {
          return null;
        }
      } else if (token is String) {
        if (current is Map) {
          if (current.containsKey(token)) {
            current = current[token];
          } else {
            return null;
          }
        } else if (current is List) {
          final index = int.tryParse(token);
          if (index != null && index >= 0 && index < current.length) {
            current = current[index];
          } else {
            return null;
          }
        } else {
          return null;
        }
      }
    }

    return current;
  }

  /// Normalizes a path by trimming whitespace and removing any leading `root.` or `root` prefixes.
  static String normalizePath(String path) {
    var p = path.trim();
    if (p.startsWith('root.')) {
      p = p.substring(5);
    } else if (p == 'root') {
      p = '';
    }
    return p;
  }

  static List<dynamic> _tokenize(String path) {
    final tokens = <dynamic>[];
    final regex = RegExp(r'([^.\[\]]+)|\[(\d+)\]');

    for (final match in regex.allMatches(path)) {
      if (match.group(2) != null) {
        tokens.add(int.parse(match.group(2)!));
      } else if (match.group(1) != null) {
        final token = match.group(1)!;
        tokens.add(token);
      }
    }

    return tokens;
  }
}
