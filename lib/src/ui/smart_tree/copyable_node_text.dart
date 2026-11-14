import 'dart:convert';

/// Formats a tree or composite node [value] for clipboard copying.
///
/// Serializes [Map] and [List] values as pretty-printed JSON, falls back to
/// `value.toString()` on encoding failure, returns `'null'` for `null`, and
/// returns `value.toString()` for scalar values.
String copyableNodeText(Object? value) {
  if (value == null) return 'null';
  if (value is Map || value is List) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }
  return value.toString();
}
