import 'package:json_diff/json_diff.dart';

enum NodeType {
  add, // Added node
  remove, // Removed node
  change, // Changed value
  node, // Structural node (Map/List)
  leaf, // Unchanged value
}

class DiffViewNode {
  final String key;
  final dynamic oldValue;
  final dynamic newValue;
  final NodeType type;
  List<DiffViewNode> children = [];
  bool isExpanded = true;
  int depth = 0;

  DiffViewNode({
    required this.key,
    this.oldValue,
    this.newValue,
    required this.type,
    this.children = const [],
    this.depth = 0,
  });
}

class JsonConverter {
  static List<DiffViewNode> fromDiff(DiffNode diff) {
    return _processNode(diff, "root", 0);
  }

  static List<DiffViewNode> _processNode(DiffNode diff, String key, int depth) {
    List<DiffViewNode> nodes = [];

    // Handle Added/Removed/Changed values at this level
    // Note: json_diff might structure this differently depending on version.
    // Based on typical DiffNode usage:

    // 1. Process added keys
    diff.added.forEach((k, v) {
      if (v is Map || v is List) {
        // It's recursive structure being added as a whole
        nodes.add(_processRawNode(k.toString(), v, NodeType.add, depth));
      } else {
        nodes.add(
          DiffViewNode(
            key: k.toString(),
            newValue: v,
            type: NodeType.add,
            depth: depth,
          ),
        );
      }
    });

    // 2. Process removed keys
    diff.removed.forEach((k, v) {
      if (v is Map || v is List) {
        // It's recursive structure being removed as a whole
        nodes.add(_processRawNode(k.toString(), v, NodeType.remove, depth));
      } else {
        nodes.add(
          DiffViewNode(
            key: k.toString(),
            oldValue: v,
            type: NodeType.remove,
            depth: depth,
          ),
        );
      }
    });

    // 3. Process changed keys (direct value changes)
    diff.changed.forEach((k, v) {
      // v is a list [old, new]
      if (v.length == 2) {
        nodes.add(
          DiffViewNode(
            key: k.toString(),
            oldValue: v[0],
            newValue: v[1],
            type: NodeType.change,
            depth: depth,
          ),
        );
      }
    });

    // 4. Process deep changes (nested objects/lists)
    // DiffNode has a 'node' map for children capable of diffing
    diff.node.forEach((k, v) {
      // v is another DiffNode
      List<DiffViewNode> children = _processNode(v, k.toString(), depth + 1);
      // Only add if there are actual diffs below, or if we want to show structure
      // A DiffNode always implies some difference below, or at least structure to traverse.
      if (children.isNotEmpty) {
        nodes.add(
          DiffViewNode(
            key: k.toString(),
            type: NodeType.node,
            children: children,
            depth: depth,
          ),
        );
      }
    });

    return nodes;
  }

  static DiffViewNode _processRawNode(
    String key,
    dynamic value,
    NodeType type,
    int depth,
  ) {
    if (value is Map) {
      List<DiffViewNode> children = [];
      value.forEach((k, v) {
        children.add(_processRawNode(k.toString(), v, type, depth + 1));
      });
      return DiffViewNode(
        key: key,
        type: type,
        children: children,
        depth: depth,
        newValue: type == NodeType.add ? value : null,
        oldValue: type == NodeType.remove ? value : null,
      );
    } else if (value is List) {
      List<DiffViewNode> children = [];
      value.asMap().forEach((i, v) {
        children.add(_processRawNode(i.toString(), v, type, depth + 1));
      });
      return DiffViewNode(
        key: key,
        type: type,
        children: children, // Use children to show list items
        depth: depth,
        newValue: type == NodeType.add ? value : null,
        oldValue: type == NodeType.remove ? value : null,
      );
    } else {
      return DiffViewNode(
        key: key,
        type: type,
        depth: depth,
        newValue: type == NodeType.add ? value : null,
        oldValue: type == NodeType.remove ? value : null,
      );
    }
  }
}
