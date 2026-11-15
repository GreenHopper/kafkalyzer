import 'package:kafkalyzer/src/rust/api/json_diff.dart';

const int maxIgnoreSuggestions = 20;

final RegExp _digitsOnly = RegExp(r'^\d+$');
final List<RegExp> _volatilePatterns = [
  RegExp(r'^(id|uuid|guid)$', caseSensitive: false),
  RegExp(r'(timestamp|time|date|ts)$', caseSensitive: false),
  RegExp(
    r'(created|updated|modified|sent|received|processed)_?(at|on)$',
    caseSensitive: false,
  ),
  RegExp(
    r'(trace|span|correlation|request|message|event)_?id$',
    caseSensitive: false,
  ),
];

bool _isVolatileSegment(String segment) {
  return _volatilePatterns.any((re) => re.hasMatch(segment));
}

String? _lastNonIndexSegment(List<String> segments) {
  for (var i = segments.length - 1; i >= 0; i--) {
    final seg = segments[i];
    if (!_digitsOnly.hasMatch(seg)) {
      return seg;
    }
  }
  return null;
}

/// Suggests up to [maxIgnoreSuggestions] volatile field paths from changed
/// [JsonDiffEntry] items that are not already in [alreadyIgnored].
List<String> suggestVolatileIgnorePaths(
  Iterable<JsonDiffEntry> entries, {
  Iterable<String> alreadyIgnored = const [],
}) {
  final ignoredSet = alreadyIgnored.map((e) => e.trim()).toSet();
  final seen = <String>{};
  final suggestions = <String>[];

  for (final entry in entries) {
    if (entry.kind != JsonDiffKind.changed) continue;
    if (entry.path.isEmpty || entry.segments.isEmpty) continue;
    if (ignoredSet.contains(entry.path) || seen.contains(entry.path)) continue;

    final lastKey = _lastNonIndexSegment(entry.segments);
    if (lastKey == null || !_isVolatileSegment(lastKey)) continue;

    seen.add(entry.path);
    suggestions.add(entry.path);
    if (suggestions.length >= maxIgnoreSuggestions) {
      break;
    }
  }

  return suggestions;
}
