# Implementation Tasks: Drop JsonCardViewer & SmartVirtualJsonTree with Smart Badges (Phase 3)

## Phase 1: Entity Formatter Engine & Smart Composite Badge

- [x] 1.1 Implement `FormattedBadgeData` model and `EntityFormatterRegistry`
  - Create `lib/src/ui/smart_tree/entity_formatter_registry.dart` with `FormattedBadgeData` class.
  - Implement heuristic rules for postal addresses, start/end date-time windows, and GPS coordinates.
  - Implement generic compact flat object heuristic for small maps (1–4 primitive entries like `customer: {id, name}` or status codes).
  - Return `null` when no heuristic matches and object exceeds compact thresholds or contains nested structures.
- [x] 1.2 Write unit tests for `EntityFormatterRegistry`
  - Create `test/src/ui/smart_tree/entity_formatter_registry_test.dart`.
  - Test address matching with various key combinations (`ort`, `city`, `plz`, `street`).
  - Test date/time matching (`startDate`, `validFrom`, `endDate`, `validTo`).
  - Test geo coordinates (`lat`, `latitude`, `lon`, `lng`, `longitude`).
  - Test generic compact flat object matching (e.g. integer id + string name, 2-3 primitive fields).
  - Test rejection of deep/nested structures or maps with > 4 entries.
  - Verify with `flutter test test/src/ui/smart_tree/entity_formatter_registry_test.dart`.
- [x] 1.3 Implement `SmartCompositeBadge` widget
  - Create `lib/src/ui/smart_tree/smart_composite_badge.dart`.
  - Build badge trigger using `CompositedTransformTarget` with badge icon, property key, and summarized label.
  - Build popover overlay using `OverlayPortal` and `CompositedTransformFollower`.
  - Implement hover preview and click-to-pin mechanism with visual lock indicator.
  - Add "Copy whole object" button and `SelectableText` for each key-value pair in popover.
- [x] 1.4 Write widget tests for `SmartCompositeBadge`
  - Create `test/src/ui/smart_tree/smart_composite_badge_test.dart`.
  - Test badge rendering with icon and text.
  - Test hover triggers overlay.
  - Test click pins overlay and click again dismisses.
  - Test copy action copies stringified map to clipboard.
  - Verify with `flutter test test/src/ui/smart_tree/smart_composite_badge_test.dart`.

## Phase 2: Virtualized Flattened JSON Tree Core (`SmartVirtualJsonTree`)

- [x] 2.1 Implement `VirtualJsonNode` and `JsonTreeFlattener`
  - Create `lib/src/ui/smart_tree/virtual_json_node.dart` and `lib/src/ui/smart_tree/json_tree_flattener.dart`.
  - Traverse Maps, Lists, and primitives into a flat `List<VirtualJsonNode>`.
  - Integrate `EntityFormatterRegistry.tryFormat()`: emit a single `compositeBadge` node when an entity matches.
  - Maintain `Set<String> expandedPaths` for expand/collapse states.
  - Add search match indexing: collect matching node paths and auto-expand their ancestor chains.
- [x] 2.2 Write unit tests for `JsonTreeFlattener`
  - Create `test/src/ui/smart_tree/json_tree_flattener_test.dart`.
  - Test flattening of flat maps, nested maps, and arrays.
  - Test expansion and collapse toggles updating visible rows.
  - Test composite badge substitution preventing child recursion.
  - Test search match collection and ancestor auto-expansion.
  - Verify with `flutter test test/src/ui/smart_tree/json_tree_flattener_test.dart`.
- [x] 2.3 Implement `SmartVirtualJsonTree` widget
  - Create `lib/src/ui/smart_tree/smart_virtual_json_tree.dart`.
  - Use `ScrollablePositionedList.builder` or `ListView.builder` with `ItemScrollController` for $O(\text{visible})$ row rendering.
  - Render indentation guides, expand/collapse chevrons, syntax-colored keys/values, and `SmartCompositeBadge` items.
  - Support expand-all and collapse-all actions.
  - Highlight search query occurrences within keys and values.
  - Implement programmatic `jumpToMatch(int index)` scrolling to the matching node.
- [x] 2.4 Write widget tests for `SmartVirtualJsonTree`
  - Create `test/src/ui/smart_tree/smart_virtual_json_tree_test.dart`.
  - Test rendering of nested JSON trees and type coloring.
  - Test clicking chevron expands/collapses nodes.
  - Test search highlighting and `jumpToMatch` scrolling.
  - Verify with `flutter test test/src/ui/smart_tree/smart_virtual_json_tree_test.dart`.

## Phase 3: Drop `JsonCardViewer` & Update `JsonOrStringViewer`

- [x] 3.1 Delete `JsonCardViewer` and its tests
  - Delete `lib/src/ui/json_card_viewer.dart`.
  - Delete `test/src/ui/json_card_viewer_test.dart`.
- [x] 3.2 Update `JsonOrStringViewer`
  - Modify `lib/src/ui/json_or_string_viewer.dart`.
  - Replace `JsonCardViewer` and legacy `json_explorer` references with `SmartVirtualJsonTree`.
  - Update view mode toggle: change `ToggleButtons` from `[Raw, Tree, Cards]` to `[Raw, Tree]`.
  - Default view mode to `1` (`Tree`) when JSON is valid.
  - Forward `searchQuery`, `onMatchCountChanged`, and `jumpToMatch` calls directly to `SmartVirtualJsonTree`.
  - Remove obsolete `MatchRegistry`.
- [x] 3.3 Update existing tests for `JsonOrStringViewer`
  - Update `test/src/ui/json_or_string_viewer_test.dart` to assert only 2 toggles (`Raw` and `Tree`).
  - Verify all tests pass with `flutter test test/src/ui/json_or_string_viewer_test.dart`.

## Phase 4: Localization, Integration & Full Suite Verification

- [x] 4.1 Update localization files
  - Verified localization strings and fallback messaging.
- [x] 4.2 Full regression verification
  - Run `flutter test test/src/ui/` to verify all UI tests pass (127/127 passing).
  - Run `flutter test test/src/ui/messages/` to verify all inspector and stepper tests pass (48/48 passing).
  - Run `dart analyze` to ensure 0 lint errors or warnings (0 issues found).
