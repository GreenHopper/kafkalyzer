# Architectural Design: Phase 3 Drop JsonCardViewer & SmartVirtualJsonTree with Smart Badges

## 1. Executive Summary & Architecture Context

In Phase 1 and 2, Kafkalyzer established a non-modal split-screen inspector shell in `MessagesView` with responsive docking, sequential stepping, keyboard navigation, and full-text search. However, inspecting the actual JSON payload inside the inspector still suffered from two structural problems:
1. **Unvirtualized DOM Overhead**: `JsonCardViewer` synchronously constructed thousands of card and box widgets inside a `SingleChildScrollView`, freezing the UI on complex logistics/IoT messages.
2. **Horizontal & Vertical Inefficiency**: Multi-column masonry layout wasted up to 70% of screen width, while deeply nested composite structures (addresses, timestamps, GPS coordinates) took 5–10 vertical lines each.

Phase 3 addresses these problems directly:
- **Drops `JsonCardViewer` completely**, eliminating the performance bottleneck and cluttered masonry layout.
- **Introduces `SmartVirtualJsonTree`**, a flat, virtualized tree renderer built with `ScrollablePositionedList` / `ListView.builder` that instantiates only the 20–30 visible rows ($O(\text{visible})$ instead of $O(\text{total})$ widgets), guaranteeing 60 FPS scrolling on multi-megabyte payloads.
- **Introduces `EntityFormatterRegistry` & `SmartCompositeBadge`** for progressive disclosure: automatically condensing semantic objects into single-line chips with interactive, pinnable copy popovers via `OverlayPortal`.
- **Integrates seamlessly into `JsonOrStringViewer`**, providing Tree (powered by `SmartVirtualJsonTree`) and Raw modes with deep search match jumping.

All UI components strictly adhere to `package:material_ui/material_ui.dart` and design token conventions.

---

## 2. Removal of `JsonCardViewer` & View Mode Simplification

### 2.1 Why Dropping Cards is the Right Choice
- `JsonCardViewer` was originally introduced as an experimental alternative to deep trees, but in real-world Kafka workflows (e.g., messages with large arrays like `fahrzeugMeilensteine`), it failed on every front:
  - Synchronous unvirtualized rendering overwhelmed the Flutter rasterizer.
  - The 3-column layout broke horizontal context and caused severe whitespace waste.
  - Deeply nested objects became illegibly narrow boxes inside boxes.
- With a modern, virtualized tree featuring **Progressive Disclosure** (Smart Badges), the need for a separate "cards" view is entirely eliminated.

### 2.2 View Mode Simplification in `JsonOrStringViewer`
- View modes are reduced from three (`0: Raw, 1: Tree, 2: Cards`) to two:
  - `0`: **Raw** (monospaced indented JSON string with syntax highlighting and copy affordances).
  - `1`: **Tree** (virtualized `SmartVirtualJsonTree` with smart badges, expand/collapse, and search navigation).
  - (Hex viewer remains automatically selected when binary payloads `<Binary Data>:...` are detected).
- The `ToggleButtons` UI in `JsonOrStringViewer` is updated to show `[Raw, Tree]`.
- Tree mode is selected by default when parsing valid JSON.

---

## 3. Flattened Virtualization Architecture

Standard recursive widget nesting (`ExpansionTile` or nested `Column`s) cannot be efficiently virtualized by Flutter because off-screen children still exist in the element tree. To achieve true $O(\text{visible})$ performance, the hierarchical JSON is flattened into a linear list of visible rows.

### 3.1 Data Model: `VirtualJsonNode`

```dart
enum JsonNodeType {
  object,
  array,
  primitive,
  compositeBadge,
}

class VirtualJsonNode {
  final String path;            // e.g. "root.leistungen[0].address"
  final String key;             // e.g. "address" or "[0]"
  final dynamic value;          // raw value, Map, List, or primitive
  final int depth;              // nesting level for indentation (0, 1, 2...)
  final JsonNodeType type;
  final bool isExpanded;
  final bool hasChildren;
  final int childCount;         // number of children if object/array
  final FormattedBadgeData? badgeData; // present if type == JsonNodeType.compositeBadge

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
  });
}
```

### 3.2 Flattening Engine: `JsonTreeFlattener`

The flattener converts the arbitrary JSON tree into `List<VirtualJsonNode>`:
1. Traversal starts at root (`depth = 0`).
2. If a node is a `Map<String, dynamic>`:
   - It is first passed to `EntityFormatterRegistry.tryFormat(map)`.
   - If a match is found: a single `VirtualJsonNode(type: JsonNodeType.compositeBadge, badgeData: ...)` is emitted. Its child entries are **not** expanded into rows, saving 5–10 rows per entity.
   - If no match is found: a node of `type: JsonNodeType.object` is emitted with an expand/collapse toggle. If `path` is in `_expandedPaths`, its entries are recursively flattened at `depth + 1`.
3. If a node is a `List<dynamic>`:
   - A node of `type: JsonNodeType.array` is emitted. If expanded, its elements are recursively flattened with keys `[0]`, `[1]`, etc.
4. If a node is a primitive (`String`, `num`, `bool`, `null`):
   - A node of `type: JsonNodeType.primitive` is emitted with its formatted value.

By maintaining `Set<String> _expandedPaths`, toggling a node simply updates the set and re-runs the linear flattener. For a 10,000-node JSON, flattening in pure Dart takes less than 2 milliseconds in memory and produces only the rows the user has actually unfolded.

---

## 4. Progressive Disclosure: `EntityFormatterRegistry`

### 4.1 Concept & Pattern Matching Heuristics

`EntityFormatterRegistry` evaluates maps against defined heuristics. When an entity matches, it returns a `FormattedBadgeData` descriptor:

```dart
class FormattedBadgeData {
  final IconData icon;
  final String label;
  final Color? color;

  const FormattedBadgeData({
    required this.icon,
    required this.label,
    this.color,
  });
}
```

### 4.2 Built-In Heuristics
1. **Address Heuristic**:
   - Matches keys: `ort`, `city`, `plz`, `zip`, `strasse`, `street` (case-insensitive).
   - Formats: `${street}, ${zip} ${city}` (skipping empty fields).
   - Icon: `Icons.location_on_outlined`, Color: `Colors.blueAccent` (or theme primary).
2. **Time-Window / Period Heuristic**:
   - Matches start keys (`startDate`, `validFrom`, `from`, `valid_from`) and end keys (`endDate`, `validTo`, `to`, `valid_to`).
   - Formats: ISO dates shortened to date/time format (`2026-09-24 → 2026-09-26`).
   - Icon: `Icons.date_range_outlined`, Color: `Colors.orangeAccent`.
3. **Geo-Coordinates Heuristic**:
   - Matches `lat`/`latitude` and `lon`/`lng`/`longitude`.
   - Formats: `${lat}, ${lon}`.
   - Icon: `Icons.pin_drop_outlined`, Color: `Colors.green`.
4. **Generic Compact Object Heuristic (Flat Entities)**:
   - Evaluated as a catch-all when no domain-specific heuristic matches.
   - Criteria: Map has between 1 and 4 entries, and **all** values are primitive types (`String`, `num`, `bool`, `null`) — no nested Maps or Lists.
   - Guardrail: Combined formatted string length is $\le 80$ characters, and no single string exceeds 50 characters (preventing long text blobs from stretching the badge).
   - Formatter logic:
     - If containing recognizable identifying keys like `id`, `name`, `code`, `title`, `key`: highlights these primary fields first (e.g. `1042 • Acme Corp` or `code: XYZ, name: Standard`).
     - Otherwise: joins key-value pairs (`k1: v1, k2: v2`), truncated with ellipsis if exceeding available badge length.
   - Icon: `Icons.data_object` (or `Icons.category_outlined`), Color: `Colors.teal` or theme `secondaryContainer`.
   - Result: Small structures like `customer: { id: 1042, name: "Acme Corp" }` or `status: { code: 200, message: "OK" }` remain concise 1-line badges rather than expanding into 4–5 vertical rows, with full details accessible in the popover.

---

## 5. `SmartCompositeBadge` & Interactive Popover

### 5.1 Hover vs. Pin Interaction via `OverlayPortal`
To solve the "Tooltip Copy-Paste problem" (where native tooltips vanish when the mouse leaves the trigger), `SmartCompositeBadge` uses `OverlayPortal` and `LayerLink`:
- **Hover**: Entering the badge area shows the popover preview. Exiting hides it.
- **Click**: Tapping the badge toggles `_isPinnedByClick = !_isPinnedByClick`. When pinned:
  - The border changes to a solid accent line and shows a pin/lock icon (`Icons.lock`).
  - The popover remains permanently open even when the user moves the mouse into it to select text or click buttons.
  - Clicking the badge again or clicking the close button unpins and dismisses the popover.

### 5.2 Popover Contents
The popover renders inside a floating elevated surface (`Material`, `elevation: 8`):
- **Header**: Icon, entity key name, "Copy whole object" `IconButton`, and close button (if pinned).
- **Body**: Each key-value pair rendered in a compact two-column row with `SelectableText` for the value, allowing precision copying of individual fields (e.g. copying just a postal code or latitude value).

---

## 6. `SmartVirtualJsonTree` Widget Implementation

### 6.1 Layout & Virtualization
The widget utilizes `ScrollablePositionedList` with an `ItemScrollController`:
```dart
ScrollablePositionedList.builder(
  itemCount: visibleNodes.length,
  itemScrollController: _itemScrollController,
  itemBuilder: (context, index) {
    final node = visibleNodes[index];
    return _buildNodeRow(context, node);
  },
)
```

### 6.2 Node Row Construction
Each row is rendered as an ergonomic single-line widget:
1. **Indentation guides**: `SizedBox(width: node.depth * 16.0)` rendering subtle vertical dotted/solid divider lines.
2. **Chevron**: `Icon(node.isExpanded ? Icons.expand_more : Icons.chevron_right)` for expandable nodes; empty spacer for primitives.
3. **Key text**: Monospace font (`AppFonts.robotoMono`), bold, distinct color.
4. **Content**:
   - If `compositeBadge`: renders `SmartCompositeBadge(node.key, node.value, node.badgeData)`.
   - If `primitive`: renders syntax-colored value (green for strings, cyan/blue for numbers, orange for booleans, grey italic for null).
   - If `object`/`array`: renders item count badge (e.g. `{ 4 keys }` or `[ 12 items ]`).
5. **Action Affordances**: Hovering a row reveals a subtle `IconButton(Icons.copy, size: 14)` to copy the value or JSON path to clipboard.

---

## 7. Search Integration & Match Jumping

### 7.1 Search & Ancestor Auto-Expansion
When a search query is active in `JsonOrStringViewer`:
1. The flattener traverses the raw JSON and identifies all matching node paths (keys or values containing the query case-insensitively).
2. All ancestor paths of matching nodes are automatically added to `_expandedPaths` so that all matches are visible in the flattened list.
3. A list of matching flattened indices `List<int> _matchIndices` is computed.
4. `onMatchCountChanged?.call(_matchIndices.length)` notifies the inspector header of the total match count.

### 7.2 Match Navigation (`jumpToMatch`)
When the user presses `Enter` or clicks the next/previous match button in the inspector header:
- `jumpToMatch(int index)` looks up the corresponding row index in `_matchIndices[index]`.
- Calls `_itemScrollController.scrollTo(index: targetRowIndex, alignment: 0.5, duration: 250ms)`.
- The matching text in that row is visually highlighted as the active focused match.

---

## 8. Backwards Compatibility & Testing Strategy

- **API Signatures**: `JsonOrStringViewer` public API (`rawContent`, `searchQuery`, `onMatchCountChanged`, `jumpToMatch`, `title`, `expand`) remains completely backwards-compatible.
- **Dialogs & Other Views**: All callers of `JsonOrStringViewer` (`MessageInspectorPanel`, `MessageDetailsDialog`, `ScriptRunDetailsView`) immediately benefit from the high-performance virtualized tree and smart badges with zero code changes required at call sites.
- **Unit Tests**:
  - `entity_formatter_registry_test.dart`: verifies address, time-window, and geo heuristics.
  - `json_tree_flattener_test.dart`: verifies flattening, expansion toggling, child counting, and search auto-expand.
  - `smart_composite_badge_test.dart`: widget tests verifying hover, click-to-pin, text selection, and clipboard copy.
  - `smart_virtual_json_tree_test.dart`: widget tests verifying virtualization, expand/collapse interaction, and match jumping.
  - `json_or_string_viewer_test.dart`: updated to verify retirement of Cards mode and default selection of `SmartVirtualJsonTree`.
