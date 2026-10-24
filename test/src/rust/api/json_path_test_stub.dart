import 'dart:convert';

import 'package:mockito/mockito.dart';

import 'rust_mocks.mocks.dart';

/// Test stand-in for the Rust field-path resolver used by projected columns and
/// script extractions. It understands the dotted and bracket forms that the
/// Dart-side fixtures use; the grammar itself is covered by the Rust tests in
/// `rust/kafkalyzer-core/src/json_path.rs`.
void stubJsonPathResolver(MockKafkalyzerRustLibApi api) {
  when(
    api.crateApiJsonPathResolveJsonPathBatch(
      payloads: anyNamed('payloads'),
      paths: anyNamed('paths'),
    ),
  ).thenAnswer((invocation) async {
    final payloads = invocation.namedArguments[#payloads] as List<String>;
    final paths = invocation.namedArguments[#paths] as List<String>;
    return [
      for (final payload in payloads)
        for (final path in paths) _resolve(payload, path),
    ];
  });
}

/// shortcut: pointer (`/a/b`) and `$` forms are unused by Dart fixtures; add
/// them here if a test starts pinning those notations.
String? _resolve(String payload, String path) {
  dynamic node;
  try {
    node = jsonDecode(payload);
  } catch (_) {
    return null;
  }

  for (final token in RegExp(r'[^.\[\]]+|\d+').allMatches(path)) {
    final part = token.group(0)!;
    if (node is List) {
      final index = int.tryParse(part);
      if (index == null || index >= node.length) return null;
      node = node[index];
    } else if (node is Map && node.containsKey(part)) {
      node = node[part];
    } else {
      return null;
    }
  }

  return node == null ? null : '$node';
}
