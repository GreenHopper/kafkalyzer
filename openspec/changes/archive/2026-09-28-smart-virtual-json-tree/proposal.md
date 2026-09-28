# Proposal: Drop JsonCardViewer & Introduce SmartVirtualJsonTree with Smart Badges (Phase 3)

## Why

In Kafka stream analysis within logistics, telemetry, and enterprise backends, messages routinely contain large, deeply nested JSON documents with dozens of items in arrays (e.g., status changes, tracking waypoints, sub-orders). Kafkalyzer currently faces severe performance and usability limitations in message inspection:

1. **Massive Performance Bottleneck in `JsonCardViewer`**:
   - `JsonCardViewer` synchronously instantiates nested widget hierarchies (`Container`, `Card`, `Wrap`, `Column`, `Row`) for the entire JSON payload inside an unvirtualized `SingleChildScrollView`.
   - On typical logistics payloads containing hundreds of milestones or items, this causes the Flutter UI thread to freeze, frame-drop, and stutter for seconds upon opening.
   - Despite these flaws, `JsonOrStringViewer` historically defaulted to `Cards` mode (`_viewMode = 2`), exposing users to the slowest possible experience.

2. **Severe Space Waste & Readability Collapse (Card-in-Card Syndrome)**:
   - The card viewer's rigid 3-column masonry layout pushes any dominant array into the leftmost column (~30% of window width), leaving over 70% of the horizontal screen area completely blank.
   - Deeper nested sub-objects are repeatedly indented and enclosed in nested box borders, squeezing text fields into tiny, illegible widths while forcing massive vertical scrolling.

3. **Inflexibility of Third-Party `json_explorer`**:
   - The current tree implementation uses the external `json_explorer` package (v0.1.2). While virtualized, it is a rigid black-box: it does not support progressive disclosure, custom semantic badges, path compacting, or interactive entity popovers.

4. **Information Overload from Composite Semantic Structures**:
   - Common composite structures (such as postal addresses, geographical coordinates, and date/time validity ranges) consume 5 to 10 vertical rows each in a standard tree view.
   - Analysts need **Progressive Disclosure**: compressing recognizable composite structures into a single-line **Smart Badge** chip, while preserving instant full-detail inspection and copyability via an interactive popover.

## What

This change executes **Phase 3** of the Kafka Message UI Optimization concept:

1. **Retire `JsonCardViewer` Completely**:
   - Delete `lib/src/ui/json_card_viewer.dart` and its associated tests.
   - Remove the `Cards` mode option from `JsonOrStringViewer` view toggles, keeping `Tree` and `Raw` (plus `Hex` for binary data).

2. **Introduce `SmartVirtualJsonTree`**:
   - Build a custom, highly performant, virtualized JSON tree widget using `ListView.builder` or `ScrollablePositionedList`.
   - Transforms hierarchical JSON (Maps and Lists) into a flat list of visible rows ($O(\text{visible})$ instead of $O(\text{total})$ widgets), guaranteeing steady 60 FPS even with multi-megabyte payloads.
   - Supports expanding and collapsing nodes with persistent state.
   - Full 100% horizontal screen width utilization without artificial 3-column masonry partitioning.
   - Monospace typography, clear syntax coloring for keys and primitive value types (strings, numbers, booleans, null), and visual indentation guide lines.
   - Quick copy affordances for node keys, values, and full JSON paths.

3. **Progressive Disclosure with `EntityFormatterRegistry` & `SmartCompositeBadge`**:
   - **`EntityFormatterRegistry`**: A rule-based heuristics engine that inspects Map objects before node expansion:
     - **Address Heuristic**: Objects containing address keys (`ort`/`city`/`plz`/`strasse`/`street`) condense into a location badge (`📍 Musterstraße 12, 1010 Wien`).
     - **Time-Window / Period Heuristic**: Objects with start/end timestamps (`startDate`/`validFrom` and `endDate`/`validTo`) condense into a period badge (`⏱ 2026-09-24 → 2026-09-26`).
     - **Geo-Coordinates Heuristic**: Objects with latitude/longitude keys (`lat`/`latitude` and `lon`/`lng`/`longitude`) condense into a coordinate badge (`🌐 48.2082, 16.3738`).
     - **Generic Flat Object Heuristic**: Small flat objects (1–4 primitive fields, e.g. `customer: { id: 1042, name: "Acme Corp" }`) condense into a compact summary badge (`📦 1042 • Acme Corp` or `id: 1042, name: Acme Corp`), preventing vertical clutter for lightweight key-value structures while keeping full interactive details in the popover.
   - **`SmartCompositeBadge`**:
     - Rendered inline in place of deep multi-row expansions.
     - Hover or click displays an interactive popover using `OverlayPortal` with `LayerLink`.
     - Click-to-pin mechanism prevents the popover from disappearing when the user moves the mouse into it to select text or copy individual fields (`SelectableText`).
     - One-click "Copy entire object" button for instant clipboard access.

4. **Seamless Integration into `JsonOrStringViewer` & In-Inspector Search**:
   - Update `JsonOrStringViewer` to use `SmartVirtualJsonTree` for its `Tree` mode (`_viewMode = 1`).
   - Integrate in-inspector search: auto-expand ancestor nodes leading to search matches, highlight matching text in keys and values, and bind `jumpToMatch(index)` to smoothly scroll the virtualized tree to the active match.

## How

- **Domain / Processing Layer**:
  - Implement `EntityFormatterRegistry` with extensible heuristic matchers returning `FormattedBadgeData(icon, label, color)`.
  - Implement `JsonTreeFlattener` and `VirtualJsonNode` data models that transform arbitrary JSON structures into a flat `List<VirtualJsonNode>` based on an active set of expanded node paths (`Set<String> _expandedPaths`).
  - When a Map matches an entity heuristic, the flattener generates a single `VirtualJsonNode` with `isCompositeBadge: true` and attached `FormattedBadgeData`, omitting its child entries from the flattened list unless explicitly expanded.

- **Presentation Layer**:
  - Implement `SmartCompositeBadge` using Flutter's `OverlayPortal`, `CompositedTransformTarget`, and `CompositedTransformFollower`. Provide a pinned state on click, copy button, and selectable row details.
  - Implement `SmartVirtualJsonTree` using `ScrollablePositionedList` (or `ListView.builder` with `ItemScrollController`) to enable $O(\text{visible})$ widget rendering and millisecond-precision scrolling to search matches.
  - Refactor `JsonOrStringViewer`:
    - Remove `JsonCardViewer` and legacy `MatchRegistry`.
    - Update `ToggleButtons` to `[Raw, Tree]`.
    - Wire `searchQuery` and `jumpToMatch` to `SmartVirtualJsonTree`.
  - Delete `lib/src/ui/json_card_viewer.dart` and `test/src/ui/json_card_viewer_test.dart`.

- **Localization**:
  - Add localized strings for badge popover titles, copy tooltips, and pin affordances in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.

## Impact on Existing Capabilities

- **`smart-virtual-json-tree` (NEW capability)**:
  - Defines the virtualized JSON tree viewer, entity formatter heuristics, and smart composite badges with interactive popovers.
- **`message-inspector-shell` (MODIFIED capability)**:
  - Updates `Requirement: Default Viewer Mode Performance` to retire the deprecated `Cards` view mode and mandate `SmartVirtualJsonTree` as the high-performance default for payload inspection.
  - Updates `Requirement: Structured Multi-Tab Inspection` so the `Payload` tab uses `SmartVirtualJsonTree` with progressive disclosure.
