import 'package:kafkalyzer/src/ui/smart_tree/entity_formatter_registry.dart';

enum JsonNodeType {
  object,
  array,
  primitive,
  compositeBadge,
  collapsedRange,
}

/// A single flattened row item in the virtualized JSON tree.
class VirtualJsonNode {
  final String path;
  final String key;
  final dynamic value;
  final int depth;
  final JsonNodeType type;
  final bool isExpanded;
  final bool hasChildren;
  final int childCount;
  final FormattedBadgeData? badgeData;
  final bool isMatch;

  /// Range start index for [JsonNodeType.collapsedRange].
  final int? collapsedRangeStart;

  /// Range end index for [JsonNodeType.collapsedRange].
  final int? collapsedRangeEnd;

  /// Total count of collapsed elements for [JsonNodeType.collapsedRange].
  final int? collapsedCount;

  /// Compound breadcrumb path key (e.g. `parent.child` or `[0].subItem`) for path-flattened nodes.
  final String? compoundPathKey;

  /// Whether this node is the active target of the search match stepper.
  final bool isFocusedMatch;

  const VirtualJsonNode({
    required this.path,
    required this.key,
    required this.value,
    required this.depth,
    required this.type,
    this.isExpanded = false,
    this.hasChildren = false,
    this.childCount = 0,
    this.badgeData,
    this.isMatch = false,
    this.collapsedRangeStart,
    this.collapsedRangeEnd,
    this.collapsedCount,
    this.compoundPathKey,
    this.isFocusedMatch = false,
  });

  VirtualJsonNode copyWith({
    String? path,
    String? key,
    dynamic value,
    int? depth,
    JsonNodeType? type,
    bool? isExpanded,
    bool? hasChildren,
    int? childCount,
    FormattedBadgeData? badgeData,
    bool? isMatch,
    int? collapsedRangeStart,
    int? collapsedRangeEnd,
    int? collapsedCount,
    String? compoundPathKey,
    bool? isFocusedMatch,
  }) {
    return VirtualJsonNode(
      path: path ?? this.path,
      key: key ?? this.key,
      value: value ?? this.value,
      depth: depth ?? this.depth,
      type: type ?? this.type,
      isExpanded: isExpanded ?? this.isExpanded,
      hasChildren: hasChildren ?? this.hasChildren,
      childCount: childCount ?? this.childCount,
      badgeData: badgeData ?? this.badgeData,
      isMatch: isMatch ?? this.isMatch,
      collapsedRangeStart: collapsedRangeStart ?? this.collapsedRangeStart,
      collapsedRangeEnd: collapsedRangeEnd ?? this.collapsedRangeEnd,
      collapsedCount: collapsedCount ?? this.collapsedCount,
      compoundPathKey: compoundPathKey ?? this.compoundPathKey,
      isFocusedMatch: isFocusedMatch ?? this.isFocusedMatch,
    );
  }
}
