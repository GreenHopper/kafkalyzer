import 'dart:convert';

import 'package:kafkalyzer/src/rust/api/json_diff.dart';

enum NodeType {
  add, // Added node
  remove, // Removed node
  change, // Changed value
  node, // Structural node (Map/List)
  leaf, // Unchanged value
}

class DiffViewNode {
  final String key;
  final String? path;
  final dynamic oldValue;
  final dynamic newValue;
  final NodeType type;
  List<DiffViewNode> children;
  bool isExpanded = true;
  int depth;

  DiffViewNode({
    required this.key,
    this.path,
    this.oldValue,
    this.newValue,
    required this.type,
    this.children = const [],
    this.depth = 0,
  });
}

class DiffTreeBuilder {
  static List<DiffViewNode> fromEntries(List<JsonDiffEntry> entries) {
    final root = _TreeBucket();
    for (final entry in entries) {
      if (entry.segments.isEmpty) {
        _insertLeaf(root, '', entry, 0);
        continue;
      }
      var bucket = root;
      for (var i = 0; i < entry.segments.length - 1; i++) {
        bucket = bucket.children.putIfAbsent(
          entry.segments[i],
          _TreeBucket.new,
        );
      }
      _insertLeaf(
        bucket,
        entry.segments.last,
        entry,
        entry.segments.length - 1,
      );
    }
    return _emit(root, 0, const []);
  }

  static void _insertLeaf(
    _TreeBucket bucket,
    String key,
    JsonDiffEntry entry,
    int depth,
  ) {
    switch (entry.kind) {
      case JsonDiffKind.added:
        final newVal = _decodeJsonValue(entry.newValue);
        bucket.added.add(
          _processRawNode(
            key,
            newVal,
            NodeType.add,
            depth,
            path: entry.path,
            segments: entry.segments,
          ),
        );
      case JsonDiffKind.removed:
        final oldVal = _decodeJsonValue(entry.oldValue);
        bucket.removed.add(
          _processRawNode(
            key,
            oldVal,
            NodeType.remove,
            depth,
            path: entry.path,
            segments: entry.segments,
          ),
        );
      case JsonDiffKind.changed:
        bucket.changed.add(
          DiffViewNode(
            key: key,
            path: entry.path,
            oldValue: _decodeJsonValue(entry.oldValue),
            newValue: _decodeJsonValue(entry.newValue),
            type: NodeType.change,
            depth: depth,
          ),
        );
    }
  }

  static dynamic _decodeJsonValue(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  static List<DiffViewNode> _emit(
    _TreeBucket bucket,
    int depth,
    List<String> prefixSegments,
  ) {
    final nodes = <DiffViewNode>[
      ...bucket.added,
      ...bucket.removed,
      ...bucket.changed,
    ];
    for (final entry in bucket.children.entries) {
      final childSegments = [...prefixSegments, entry.key];
      final childNodes = _emit(entry.value, depth + 1, childSegments);
      if (childNodes.isNotEmpty) {
        nodes.add(
          DiffViewNode(
            key: entry.key,
            path: _buildCanonicalPath(childSegments),
            type: NodeType.node,
            children: childNodes,
            depth: depth,
          ),
        );
      }
    }
    return nodes;
  }

  static DiffViewNode _processRawNode(
    String key,
    dynamic value,
    NodeType type,
    int depth, {
    String? path,
    List<String> segments = const [],
  }) {
    final resolvedPath = path ?? _buildCanonicalPath(segments);
    if (value is Map) {
      final children = <DiffViewNode>[];
      value.forEach((k, v) {
        final ks = k.toString();
        children.add(
          _processRawNode(ks, v, type, depth + 1, segments: [...segments, ks]),
        );
      });
      return DiffViewNode(
        key: key,
        path: resolvedPath,
        type: type,
        children: children,
        depth: depth,
        newValue: type == NodeType.add ? value : null,
        oldValue: type == NodeType.remove ? value : null,
      );
    } else if (value is List) {
      final children = <DiffViewNode>[];
      value.asMap().forEach((i, v) {
        final ks = i.toString();
        children.add(
          _processRawNode(ks, v, type, depth + 1, segments: [...segments, ks]),
        );
      });
      return DiffViewNode(
        key: key,
        path: resolvedPath,
        type: type,
        children: children,
        depth: depth,
        newValue: type == NodeType.add ? value : null,
        oldValue: type == NodeType.remove ? value : null,
      );
    } else {
      return DiffViewNode(
        key: key,
        path: resolvedPath,
        type: type,
        depth: depth,
        newValue: type == NodeType.add ? value : null,
        oldValue: type == NodeType.remove ? value : null,
      );
    }
  }

  static String _buildCanonicalPath(List<String> segments) {
    if (segments.isEmpty) return '';
    final allSafe = segments.every(_isSafeSegment);
    if (allSafe) {
      return segments.join('.');
    }
    return '/${segments.map((s) => s.replaceAll('~', '~0').replaceAll('/', '~1')).join('/')}';
  }

  static bool _isSafeSegment(String seg) {
    if (seg.isEmpty || seg.startsWith(r'$')) return false;
    if (RegExp(r'^\d+$').hasMatch(seg)) return false;
    return !seg.contains(RegExp(r'[./\[\]~ \t\n\r]'));
  }
}

class _TreeBucket {
  final List<DiffViewNode> added = [];
  final List<DiffViewNode> removed = [];
  final List<DiffViewNode> changed = [];
  final Map<String, _TreeBucket> children = {};
}
