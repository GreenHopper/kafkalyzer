import 'dart:convert';

class TextPreviewUtils {
  /// Safely truncates the payload for preview purposes, replacing newlines with spaces.
  /// If the text is longer than [maxLength], it truncates and appends an ellipsis.
  /// When [filterNulls] is true and [payload] is valid JSON, keys with null values are omitted.
  static String getPayloadPreview(
    String? payload, {
    int maxLength = 300,
    bool filterNulls = true,
  }) {
    if (payload == null || payload.isEmpty) {
      return "";
    }

    String content = payload;
    if (filterNulls && (content.startsWith('{') || content.startsWith('['))) {
      try {
        final decoded = json.decode(content);
        if (decoded is Map) {
          final pruned = _pruneNulls(decoded);
          content = json.encode(pruned);
        } else if (decoded is List) {
          final prunedList = decoded.map((item) {
            if (item is Map) return _pruneNulls(item);
            return item;
          }).toList();
          content = json.encode(prunedList);
        }
      } catch (_) {
        // Fallback to raw string if decoding fails
      }
    }

    String preview = content;
    if (preview.length > maxLength) {
      preview = "${preview.substring(0, maxLength)}...";
    }

    // Replace newlines and multiple spaces for a compact single-line preview
    return preview.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Map<String, dynamic> _pruneNulls(Map map) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final key = entry.key.toString();
      final val = entry.value;
      if (val == null) continue;
      if (val is Map) {
        result[key] = _pruneNulls(val);
      } else if (val is List) {
        result[key] = val.map((e) => e is Map ? _pruneNulls(e) : e).toList();
      } else {
        result[key] = val;
      }
    }
    return result;
  }
}
