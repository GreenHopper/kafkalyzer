# Proposal: Context Windowing (Treffer ±1), Indentation Flattening & Center-Scroll (Phase 4)

## Why

Following Phase 3's introduction of `SmartVirtualJsonTree` and progressive disclosure smart badges, Kafka messages with deeply nested objects and long arrays (e.g. logistics tracking with dozens of items in `leistungen`, telemetry milestones, IoT sensor batches) still present usability friction:

1. **Large Array Traversal Fatigue During Search**:
   - In Kafka messages where arrays contain dozens or hundreds of items (e.g. `leistungen[30]`), searching for a specific transport ID or status code often matches a deeply nested item (e.g. `leistungen[14].sortOrders[4].transportId`).
   - Even though ancestor nodes are auto-expanded, the user still has to scroll past dozens of non-matching items (`leistungen[0]` through `leistungen[13]`), losing context and disorientation.
   - Analysts need **Context Windowing (Treffer $\pm 1$)**: automatically showing only the direct match and its immediate adjacent neighbor items (context $\pm 1$), while collapsing preceding (`[0..12]`) and subsequent (`[16..29]`) items into compact, interactive placeholder controls.

2. **Horizontal Screen Space Depletion (Deep Indentation Chains)**:
   - On typical laptop screens (13–15 inches, 1080p with 125–150% scaling, ~1200–1400 logical pixels wide), deeply nested single-child paths (e.g., `fahrzeugMeilensteine[0] -> transportMeilensteine[0] -> transportId`) consume excessive horizontal margins due to repeated 16px hierarchy indents (e.g., 6–8 indentation levels waste 96–128px of horizontal width).
   - Unbranched hierarchy chains should be compressed into single compound breadcrumb rows:
     `▼ fahrzeugMeilensteine[0] . transportMeilensteine[0]`
     preserving horizontal viewport space and improving visual flow.

3. **Sub-optimal Match Navigation & Viewport Alignment**:
   - Currently, match navigation positions items at the top or edge of the viewport.
   - Stepping through search matches should smoothly scroll the active match directly into the vertical center (`alignment: 0.5`) of the visible viewport, with prominent active match styling (e.g. accent border, active target indicator) to distinguish the current cursor from passive matches.

## What

This change executes **Phase 4** of the Kafka Message UI Optimization concept:

1. **`ContextWindowCalculator` & List Segmentation**:
   - Introduce a domain calculator that evaluates arrays based on active search matches:
     - Calculates visible item segments (`radius = 1` by default) around matching indices.
     - Groups non-matching consecutive indices into `CollapsedRangeSegment`s (e.g. `13 vorherige Elemente (Index 0–12)`).
   - Supports interactive user expansion:
     - Click-to-expand on individual collapsed placeholders to reveal hidden elements inline.
     - Array header toggle button to switch between focused context mode ("Auf Treffer reduzieren") and full list view ("Alle N zeigen").

2. **Indentation Flattening (Path Compression)**:
   - In `JsonTreeFlattener`, detect unbranched object and array chains where a node has exactly one child (e.g. a single-key Map containing another Map or List, or a single-item array).
   - Compress the chain into a single compound breadcrumb key (e.g. `parent.child` or `items[0].detail`), flattened to the parent's indentation level.
   - Maintain interactive expand/collapse functionality on the compound node.

3. **Auto-Focus & Center-Scroll to Search Matches**:
   - Update `SmartVirtualJsonTree.jumpToMatch(index)` to center the active match in the viewport with smooth animation curve and `alignment: 0.5`.
   - Enhance in-tree search presentation with active match focus styling:
     - Passive matches display the standard highlighted background.
     - The active match displays an accent highlight, distinct border, and match indicator (`🎯`).

4. **Integration with `JsonTreeFlattener` and `VirtualJsonNode`**:
   - Add support for `JsonNodeType.collapsedRange` in `VirtualJsonNode`.
   - Expose configuration flags (`enableContextWindowing`, `enableIndentationFlattening`) on `SmartVirtualJsonTree` with ergonomic defaults.

## How

- **Domain / Algorithmic Components**:
  - `ContextWindowCalculator`: Pure Dart class with `calculateSegments({required int totalLength, required Set<int> matchIndices, int radius = 1, bool forceShowAll = false})` returning `List<ListSegment>` (`VisibleItemSegment` and `CollapsedRangeSegment`).
  - `JsonTreeFlattener`:
    - Extend array flattening: when search matches exist within a list and context windowing is active, use `ContextWindowCalculator` to emit `VisibleItemSegment`s and `CollapsedRangeNode`s.
    - Implement path compression pass: detect single-child hierarchy steps and merge compound keys and paths before emitting `VirtualJsonNode`.

- **Presentation / UI Components**:
  - `VirtualJsonNode`:
    - Add `collapsedRangeStart`, `collapsedRangeEnd`, `collapsedCount`, and `compoundKey` properties.
    - Add `JsonNodeType.collapsedRange`.
  - `SmartVirtualJsonTree`:
    - Render `collapsedRange` nodes as interactive, compact placeholder banners (`… N verborgene Elemente (Index X bis Y) anzeigen`).
    - Manage local expansion state for manually expanded ranges (`Set<String> _manuallyExpandedRanges`) and array `forceShowAll` toggles.
    - Render compound keys with breadcrumb styling (e.g., subtle separators between path segments).
    - Update `ItemScrollController.scrollTo(..., alignment: 0.5)` for smooth center-scrolling.
    - Style the currently active match index distinctly from other passive matches.

- **Localization**:
  - Add localized strings for collapsed range placeholders, "show all items", "reduce to matches", and match focus labels in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.

## Impact on Existing Capabilities

- **`smart-virtual-json-tree` (MODIFIED capability)**:
  - Adds `Requirement: Context Windowing for Array Lists` with scenarios for match-radius calculation, collapsed placeholder interaction, and full toggle.
  - Adds `Requirement: Indentation Flattening for Single-Child Chains` with scenarios for compound key compression and depth reduction.
  - Modifies `Requirement: In-Tree Search Highlighting and Match Navigation` to require viewport center-alignment (`alignment: 0.5`) and distinct active match emphasis.
