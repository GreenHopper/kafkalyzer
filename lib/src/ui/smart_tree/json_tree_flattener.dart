import 'package:kafkalyzer/src/ui/smart_tree/context_window_calculator.dart';
import 'package:kafkalyzer/src/ui/smart_tree/entity_formatter_registry.dart';
import 'package:kafkalyzer/src/ui/smart_tree/virtual_json_node.dart';

class FlattenResult {
  final List<VirtualJsonNode> nodes;
  final Set<String> expandedPaths;
  final List<int> matchNodeIndices;
  final int hiddenNullCount;

  const FlattenResult({
    required this.nodes,
    required this.expandedPaths,
    required this.matchNodeIndices,
    this.hiddenNullCount = 0,
  });
}

class JsonTreeFlattener {
  /// Flattens a [root] JSON structure (Map, List, or primitive) into a linear list of [VirtualJsonNode]s.
  ///
  /// Respects [expandedPaths]. If [searchQuery] is non-empty, finds matches and automatically
  /// expands ancestor paths so that matching nodes are included in the result.
  ///
  /// When [hideNullFields] is true, object properties whose value is `null` are omitted from
  /// the tree, and [FlattenResult.hiddenNullCount] records the total number of omitted null entries.
  ///
  /// When [autoExpandSingleItemCollections] is true, lists with exactly 1 item and maps with
  /// exactly 1 entry are automatically expanded unless included in [manuallyCollapsedPaths].
  ///
  /// When [enableContextWindowing] is true and search matches exist inside an array,
  /// array items are segmented with a radius of [contextRadius] around matches,
  /// collapsing non-matching items into [JsonNodeType.collapsedRange] nodes unless
  /// in [manuallyExpandedRanges] or [forcedShowAllArrays].
  ///
  /// When [enableIndentationFlattening] is true, unbranched single-child hierarchy chains
  /// are collapsed into a single compound breadcrumb row (e.g. `parent . child`).
  static FlattenResult flatten(
    dynamic root, {
    Set<String>? expandedPaths,
    Set<String>? manuallyCollapsedPaths,
    String? searchQuery,
    bool defaultExpandRoot = true,
    bool enableContextWindowing = true,
    int contextRadius = 1,
    Set<String>? manuallyExpandedRanges,
    Set<String>? forcedShowAllArrays,
    bool enableIndentationFlattening = false,
    bool hideNullFields = false,
    bool autoExpandSingleItemCollections = false,
  }) {
    final activeExpanded = Set<String>.from(expandedPaths ?? {});
    final collapsed = Set<String>.from(manuallyCollapsedPaths ?? {});

    // Ensure root path is expanded by default if requested and empty
    if (defaultExpandRoot && activeExpanded.isEmpty) {
      activeExpanded.add('root');
    }

    final query = searchQuery?.trim().toLowerCase();
    final hasSearch = query != null && query.isNotEmpty;

    // Phase 1: Search indexing & ancestor path expansion
    if (hasSearch) {
      final matchingAncestorPaths = <String>{};
      _findMatchingAncestors(root, 'root', query, matchingAncestorPaths);
      activeExpanded.addAll(matchingAncestorPaths);
    }

    // Phase 2: Linear traversal
    final resultNodes = <VirtualJsonNode>[];
    final matchIndices = <int>[];
    int hiddenNulls = 0;

    void traverse(dynamic current, String key, String path, int depth) {
      String displayKey = key;
      String currentPath = path;
      dynamic currentNodeValue = current;

      // Indentation Flattening for unbranched single-child Map chains
      if (enableIndentationFlattening &&
          current is Map &&
          current.length == 1) {
        var checkMap = current;
        var checkKey = key;
        var checkPath = path;
        int chainDepth = 0;

        while (checkMap.length == 1 && chainDepth < 20) {
          final singleEntry = checkMap.entries.first;
          final childKey = singleEntry.key.toString();
          final childVal = singleEntry.value;

          if (childVal is Map || childVal is List) {
            checkKey = checkKey.isEmpty ? childKey : '$checkKey . $childKey';
            checkPath = '$checkPath.$childKey';
            currentNodeValue = childVal;
            if (childVal is Map) {
              checkMap = childVal;
            } else {
              break;
            }
          } else {
            break;
          }
          chainDepth++;
        }

        displayKey = checkKey;
        currentPath = checkPath;
      }

      bool isNodeMatch = false;
      if (hasSearch) {
        if (displayKey.toLowerCase().contains(query)) {
          isNodeMatch = true;
        }
      }

      if (currentNodeValue is Map) {
        final stringMap = <String, dynamic>{};
        for (final entry in currentNodeValue.entries) {
          final k = entry.key.toString();
          final v = entry.value;
          if (hideNullFields && v == null) {
            hiddenNulls++;
            continue;
          }
          stringMap[k] = v;
        }

        // Auto-expand single-entry collection by default if not manually collapsed
        if (autoExpandSingleItemCollections &&
            stringMap.length == 1 &&
            !collapsed.contains(currentPath) &&
            !collapsed.contains(path)) {
          activeExpanded.add(currentPath);
        }

        final isExp = activeExpanded.contains(currentPath) ||
            activeExpanded.contains(path);

        // Check EntityFormatterRegistry for progressive disclosure when collapsed
        final badge = EntityFormatterRegistry.tryFormat(stringMap);
        if (badge != null && !isExp) {
          if (hasSearch && badge.label.toLowerCase().contains(query)) {
            isNodeMatch = true;
          }
          final node = VirtualJsonNode(
            path: currentPath,
            key: displayKey,
            compoundPathKey: displayKey != key ? displayKey : null,
            value: stringMap,
            depth: depth,
            type: JsonNodeType.compositeBadge,
            badgeData: badge,
            isMatch: isNodeMatch,
            hasChildren: true,
            isExpanded: false,
          );
          if (isNodeMatch) {
            matchIndices.add(resultNodes.length);
          }
          resultNodes.add(node);
          return;
        }

        // Standard expandable object
        final node = VirtualJsonNode(
          path: currentPath,
          key: displayKey,
          compoundPathKey: displayKey != key ? displayKey : null,
          value: stringMap,
          depth: depth,
          type: JsonNodeType.object,
          isExpanded: isExp,
          hasChildren: stringMap.isNotEmpty,
          childCount: stringMap.length,
          isMatch: isNodeMatch,
        );
        if (isNodeMatch) {
          matchIndices.add(resultNodes.length);
        }
        resultNodes.add(node);

        if (isExp) {
          for (final entry in stringMap.entries) {
            traverse(
              entry.value,
              entry.key,
              '$currentPath.${entry.key}',
              depth + 1,
            );
          }
        }
      } else if (currentNodeValue is List) {
        final listBadge = EntityFormatterRegistry.tryFormatList(currentNodeValue);

        // Auto-expand single-item list by default if not manually collapsed
        // UNLESS it is eligible for compact badge rendering
        if (autoExpandSingleItemCollections &&
            currentNodeValue.length == 1 &&
            listBadge == null &&
            !collapsed.contains(currentPath) &&
            !collapsed.contains(path)) {
          activeExpanded.add(currentPath);
        }

        final isExp = activeExpanded.contains(currentPath) ||
            activeExpanded.contains(path);

        if (listBadge != null && !isExp) {
          if (hasSearch && listBadge.label.toLowerCase().contains(query)) {
            isNodeMatch = true;
          }
          final node = VirtualJsonNode(
            path: currentPath,
            key: displayKey,
            compoundPathKey: displayKey != key ? displayKey : null,
            value: currentNodeValue,
            depth: depth,
            type: JsonNodeType.compositeBadge,
            badgeData: listBadge,
            isMatch: isNodeMatch,
            hasChildren: true,
            isExpanded: false,
          );
          if (isNodeMatch) {
            matchIndices.add(resultNodes.length);
          }
          resultNodes.add(node);
          return;
        }

        final node = VirtualJsonNode(
          path: currentPath,
          key: displayKey,
          compoundPathKey: displayKey != key ? displayKey : null,
          value: currentNodeValue,
          depth: depth,
          type: JsonNodeType.array,
          isExpanded: isExp,
          hasChildren: currentNodeValue.isNotEmpty,
          childCount: currentNodeValue.length,
          isMatch: isNodeMatch,
        );
        if (isNodeMatch) {
          matchIndices.add(resultNodes.length);
        }
        resultNodes.add(node);

        if (isExp) {
          final isForcedShowAll =
              forcedShowAllArrays?.contains(currentPath) ?? false;

          // Check if Context Windowing should segment this array
          if (hasSearch && enableContextWindowing && !isForcedShowAll) {
            final arrayMatches = <int>{};
            for (int i = 0; i < currentNodeValue.length; i++) {
              final item = currentNodeValue[i];
              if ('[$i]'.contains(query) ||
                  hasMatchInSubtree(item, query)) {
                arrayMatches.add(i);
              }
            }

            if (arrayMatches.isNotEmpty) {
              final segments = ContextWindowCalculator.calculateSegments(
                totalLength: currentNodeValue.length,
                matchIndices: arrayMatches,
                radius: contextRadius,
                forceShowAll: false,
              );

              for (final segment in segments) {
                switch (segment) {
                  case VisibleItemSegment(:final index):
                    traverse(
                      currentNodeValue[index],
                      '[$index]',
                      '$currentPath[$index]',
                      depth + 1,
                    );

                  case CollapsedRangeSegment(
                      :final startIndex,
                      :final endIndex,
                      :final count
                    ):
                    final rangeKey =
                        '$currentPath[$startIndex-$endIndex]';
                    if (manuallyExpandedRanges?.contains(rangeKey) ?? false) {
                      for (int i = startIndex; i <= endIndex; i++) {
                        traverse(
                          currentNodeValue[i],
                          '[$i]',
                          '$currentPath[$i]',
                          depth + 1,
                        );
                      }
                    } else {
                      resultNodes.add(
                        VirtualJsonNode(
                          path: rangeKey,
                          key: '',
                          value: null,
                          depth: depth + 1,
                          type: JsonNodeType.collapsedRange,
                          collapsedRangeStart: startIndex,
                          collapsedRangeEnd: endIndex,
                          collapsedCount: count,
                        ),
                      );
                    }
                }
              }
              return;
            }
          }

          // Default full iteration when no segmentation applies
          for (int i = 0; i < currentNodeValue.length; i++) {
            traverse(
              currentNodeValue[i],
              '[$i]',
              '$currentPath[$i]',
              depth + 1,
            );
          }
        }
      } else {
        // Primitive
        if (hasSearch &&
            currentNodeValue != null &&
            currentNodeValue.toString().toLowerCase().contains(query)) {
          isNodeMatch = true;
        }
        final node = VirtualJsonNode(
          path: currentPath,
          key: displayKey,
          compoundPathKey: displayKey != key ? displayKey : null,
          value: currentNodeValue,
          depth: depth,
          type: JsonNodeType.primitive,
          isMatch: isNodeMatch,
        );
        if (isNodeMatch) {
          matchIndices.add(resultNodes.length);
        }
        resultNodes.add(node);
      }
    }

    if (root is Map || root is List) {
      if (root is Map) {
        final stringMap = <String, dynamic>{};
        for (final entry in root.entries) {
          final k = entry.key.toString();
          final v = entry.value;
          if (hideNullFields && v == null) {
            hiddenNulls++;
            continue;
          }
          stringMap[k] = v;
        }
        for (final entry in stringMap.entries) {
          traverse(entry.value, entry.key, 'root.${entry.key}', 0);
        }
      } else {
        for (int i = 0; i < root.length; i++) {
          traverse(root[i], '[$i]', 'root[$i]', 0);
        }
      }
    } else {
      traverse(root, 'value', 'root', 0);
    }

    return FlattenResult(
      nodes: resultNodes,
      expandedPaths: activeExpanded,
      matchNodeIndices: matchIndices,
      hiddenNullCount: hiddenNulls,
    );
  }

  static bool hasMatchInSubtree(dynamic current, String query) {
    if (current is Map) {
      for (final entry in current.entries) {
        if (entry.key.toString().toLowerCase().contains(query)) return true;
        if (hasMatchInSubtree(entry.value, query)) return true;
      }
    } else if (current is List) {
      for (int i = 0; i < current.length; i++) {
        if (hasMatchInSubtree(current[i], query)) return true;
      }
    } else if (current != null) {
      if (current.toString().toLowerCase().contains(query)) return true;
    }
    return false;
  }

  static bool _findMatchingAncestors(
    dynamic current,
    String path,
    String query,
    Set<String> ancestorsToExpand,
  ) {
    bool hasMatchInSubtree = false;

    if (current is Map) {
      final stringMap = <String, dynamic>{};
      for (final entry in current.entries) {
        stringMap[entry.key.toString()] = entry.value;
      }

      for (final entry in stringMap.entries) {
        final childKey = entry.key;
        final childPath = '$path.$childKey';
        final keyMatches = childKey.toLowerCase().contains(query);

        // For list badges, they are terminal (rendered as a single badge row when collapsed),
        // so if the badge matches, mark ancestor to expand and do NOT descend into child elements.
        bool isChildListBadge = false;
        bool badgeMatches = false;
        if (entry.value is List) {
          final listBadge = EntityFormatterRegistry.tryFormatList(entry.value as List);
          if (listBadge != null) {
            isChildListBadge = true;
            if (listBadge.label.toLowerCase().contains(query)) {
              badgeMatches = true;
            }
          }
        }

        final childMatches = isChildListBadge
            ? false
            : _findMatchingAncestors(
                entry.value,
                childPath,
                query,
                ancestorsToExpand,
              );

        if (keyMatches || childMatches || badgeMatches) {
          hasMatchInSubtree = true;
          ancestorsToExpand.add(path);
        }
      }
    } else if (current is List) {
      final listBadge = EntityFormatterRegistry.tryFormatList(current);
      if (listBadge != null) {
        // If the compact list itself matches, we don't expand its internal elements into rows;
        // we just ensure its parent ancestor path is marked to keep the badge visible.
        if (listBadge.label.toLowerCase().contains(query)) {
          hasMatchInSubtree = true;
          // Note: do NOT add 'path' to ancestorsToExpand, because 'path' is the list itself.
          // Adding 'path' would mark the list as isExpanded: true!
        }
      } else {
        for (int i = 0; i < current.length; i++) {
          final childPath = '$path[$i]';
          final childMatches = _findMatchingAncestors(
            current[i],
            childPath,
            query,
            ancestorsToExpand,
          );
          if (childMatches) {
            hasMatchInSubtree = true;
            ancestorsToExpand.add(path);
          }
        }
      }
    } else {
      if (current != null && current.toString().toLowerCase().contains(query)) {
        hasMatchInSubtree = true;
      }
    }

    return hasMatchInSubtree;
  }
}
