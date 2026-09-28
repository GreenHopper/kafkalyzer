# Design: Context Windowing (Treffer ±1), Indentation Flattening & Center-Scroll

## Context and Scope

In Phase 3, we introduced `SmartVirtualJsonTree` which virtualized payload rendering into a linear list of `VirtualJsonNode`s ($O(\text{visible})$) with progressive disclosure smart badges. 

Phase 4 addresses the remaining UX bottlenecks for deep and large payloads:
1. **Large Array Traversals During Search**: Arrays containing dozens of items (e.g. `leistungen[30]`) force users to scroll through irrelevant sibling elements even when the match is isolated.
2. **Horizontal Margin Loss on Laptops**: Repeated 16px indents for unbranched hierarchy chains consume substantial horizontal space on laptop screens.
3. **Match Centering**: Search navigation needs to center matches smoothly in the viewport (`alignment: 0.5`) with prominent active cursor styling.

## Architectural Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        JsonOrStringViewer                              │
│         (Search query, jumpToMatch index, match counter)               │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      SmartVirtualJsonTree                              │
│  - ItemScrollController.scrollTo(targetIndex, alignment: 0.5)          │
│  - Local state: _manuallyExpandedRanges, _forcedShowAllArrays          │
│  - Active match cursor tracking (_activeMatchIndex)                    │
└──────────────────┬───────────────────────────────┬─────────────────────┘
                   │                               │
                   ▼                               ▼
     ┌───────────────────────────┐   ┌──────────────────────────┐
     │    JsonTreeFlattener      │   │ ContextWindowCalculator  │
     │  - Path Compression       │◄──┤  - Match radius (±1)     │
     │  - Array Segmentation     │   │  - CollapsedRangeSegment │
     └─────────────┬─────────────┘   └──────────────────────────┘
                   │
                   ▼
     ┌───────────────────────────┐
     │     VirtualJsonNode       │
     │  - type: collapsedRange   │
     │  - compoundKey / depth    │
     │  - isFocusedMatch         │
     └───────────────────────────┘
```

---

## Technical Design

### 1. `ContextWindowCalculator` (Pure Domain Model)

File: `lib/src/ui/smart_tree/context_window_calculator.dart`

```dart
sealed class ListSegment {
  const ListSegment();
}

class VisibleItemSegment extends ListSegment {
  final int index;
  final bool isDirectMatch;

  const VisibleItemSegment({required this.index, required this.isDirectMatch});
}

class CollapsedRangeSegment extends ListSegment {
  final int startIndex;
  final int endIndex; // inclusive
  int get count => (endIndex - startIndex) + 1;

  const CollapsedRangeSegment({required this.startIndex, required this.endIndex});
}

class ContextWindowCalculator {
  static List<ListSegment> calculateSegments({
    required int totalLength,
    required Set<int> matchIndices,
    int radius = 1,
    bool forceShowAll = false,
  }) {
    if (totalLength == 0) return const [];
    if (forceShowAll || matchIndices.isEmpty) {
      return List.generate(
        totalLength,
        (i) => VisibleItemSegment(index: i, isDirectMatch: matchIndices.contains(i)),
      );
    }

    final visibleIndices = <int>{};
    for (final match in matchIndices) {
      final start = (match - radius).clamp(0, totalLength - 1);
      final end = (match + radius).clamp(0, totalLength - 1);
      for (int i = start; i <= end; i++) {
        visibleIndices.add(i);
      }
    }

    final segments = <ListSegment>[];
    int currentIndex = 0;

    while (currentIndex < totalLength) {
      if (visibleIndices.contains(currentIndex)) {
        segments.add(VisibleItemSegment(
          index: currentIndex,
          isDirectMatch: matchIndices.contains(currentIndex),
        ));
        currentIndex++;
      } else {
        final collapsedStart = currentIndex;
        while (currentIndex < totalLength && !visibleIndices.contains(currentIndex)) {
          currentIndex++;
        }
        segments.add(CollapsedRangeSegment(
          startIndex: collapsedStart,
          endIndex: currentIndex - 1,
        ));
      }
    }

    return segments;
  }
}
```

### 2. Extensions to `VirtualJsonNode`

File: `lib/src/ui/smart_tree/virtual_json_node.dart`

- Add `JsonNodeType.collapsedRange`.
- Add fields to `VirtualJsonNode`:
  - `final int? collapsedRangeStart;`
  - `final int? collapsedRangeEnd;`
  - `final int? collapsedCount;`
  - `final String? compoundPathKey;` (e.g. `leistungen[14].sortOrders[4]`)
  - `final bool isFocusedMatch;` (true when this node is the active target of `jumpToMatch`)

### 3. Updates to `JsonTreeFlattener`

File: `lib/src/ui/smart_tree/json_tree_flattener.dart`

- **Array Context Windowing**:
  - When traversing a `List` with `isExp == true`:
    - Determine which element indices contain matches.
    - If `hasSearch` is true and matches exist within the list, invoke `ContextWindowCalculator.calculateSegments(...)`.
    - For each `CollapsedRangeSegment`, check if the range path (e.g. `$path[$startIndex-$endIndex]`) is in `manuallyExpandedRanges`:
      - If manually expanded: emit a "Collapse range" marker followed by the child items.
      - If collapsed: emit a single `VirtualJsonNode` of type `JsonNodeType.collapsedRange`.
    - For each `VisibleItemSegment`: traverse child as normal.
    - If array has collapsed ranges, the array header node is tagged with match context info so `SmartVirtualJsonTree` can render the toggle control (`Alle N zeigen` / `Auf Treffer reduzieren`).

- **Indentation Flattening (Single-Child Compression)**:
  - When `enableIndentationFlattening == true`:
    - If a Map entry has a value that is a Map with exactly 1 entry, or an array element has an object with 1 entry:
    - Instead of creating an intermediate node and increasing `depth + 1`, merge the keys into `compoundPathKey` (e.g. `parentKey . childKey`) and retain the parent's `depth`.
    - Collapse/expansion toggles apply to the innermost expandable element.

### 4. Updates to `SmartVirtualJsonTree`

File: `lib/src/ui/smart_tree/smart_virtual_json_tree.dart`

- **Rendering `collapsedRange` Rows**:
  - Render an interactive container:
    - Left icon: `Icons.more_horiz`
    - Text: `… $count verborgene Elemente (Index $start bis $end) anzeigen`
    - Tap handler: adds `$path[$start-$end]` to `_manuallyExpandedRanges`, triggering rebuild and re-flattening.
- **Array Header Quick Actions**:
  - When an array has active context windowing, display an inline pill:
    - `${matchCount} Treffer (Fokus: Treffer ±1)`
    - Button: `Alle N zeigen` / `Auf Treffer reduzieren` (toggles `_forcedShowAllArrays`).
- **Match Centering**:
  - In `jumpToMatch(int index)`:
    - Resolve the target `VirtualJsonNode` index from `flattenResult.matchNodeIndices[index]`.
    - Scroll using:
      ```dart
      _itemScrollController.scrollTo(
        index: targetRowIndex,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      ```
    - Update `_focusedMatchNodeIndex = targetRowIndex` to render the active target indicator and accent border.

---

## State and Data Flow

```
User types in Search Bar
        │
        ▼
JsonOrStringViewer passes `searchQuery` to SmartVirtualJsonTree
        │
        ▼
SmartVirtualJsonTree calls JsonTreeFlattener.flatten(..., searchQuery, _manuallyExpandedRanges, _forcedShowAllArrays)
        │
        ├─► Finds matches & auto-expands ancestor paths
        ├─► Detects single-child chains & compresses compound keys
        ├─► Calculates array segments (±1 radius around matches)
        └─► Emits List<VirtualJsonNode> including CollapsedRange nodes
        │
        ▼
SmartVirtualJsonTree renders virtualized rows
        │
User taps "Next Match" (jumpToMatch)
        │
        ▼
_itemScrollController.scrollTo(targetIndex, alignment: 0.5)
        │
        ▼
Target row smoothly centers in viewport with 🎯 indicator & accent border
```

---

## Non-Goals & Out of Scope

- Modifying `TableView.builder` or master stream projections (Phase 5).
- Modifying backend Kafka Rust deserialization or schemas.
- Changing `MessageDetailsDialog` (which has already been retired in Phase 1 & 2).

---

## Alternatives Considered

1. **Pruning All Non-Matching Nodes (Strict Filtering)**:
   - *Alternative*: Hide every node that does not match the search term entirely.
   - *Why rejected*: Stripping all context makes it impossible to understand the structure of the message. The user cannot see whether a field belongs to `leistungen` or `sortOrders`. Context Windowing ($\pm 1$) provides the ideal balance: high visibility without scroll fatigue.

2. **Dialog-based Array Expansion**:
   - *Alternative*: Open a sub-dialog when clicking on a long array.
   - *Why rejected*: Reintroduces modal breaks, which is the exact anti-pattern eliminated in Phase 1.
