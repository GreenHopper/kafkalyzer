# Tasks: Context Windowing (Treffer ±1), Indentation Flattening & Center-Scroll

## 1. Domain Model: ContextWindowCalculator
- [x] 1.1 Implement `ContextWindowCalculator` and segment types (`VisibleItemSegment`, `CollapsedRangeSegment`) in `lib/src/ui/smart_tree/context_window_calculator.dart`
- [x] 1.2 Write unit tests in `test/src/ui/smart_tree/context_window_calculator_test.dart` covering edge cases:
  - Empty array
  - No matches
  - Match at start (index 0) with radius 1
  - Match at end (index N-1) with radius 1
  - Match in middle (e.g. index 14 of 30)
  - Overlapping match radii (e.g. indices 5 and 7 merging visible range 4..8)
  - `forceShowAll = true` flag bypass
- [x] 1.3 Verify domain unit tests pass with `flutter test test/src/ui/smart_tree/context_window_calculator_test.dart`

## 2. Data Model: VirtualJsonNode Extensions
- [x] 2.1 Update `lib/src/ui/smart_tree/virtual_json_node.dart`:
  - Add `JsonNodeType.collapsedRange`
  - Add fields `collapsedRangeStart`, `collapsedRangeEnd`, `collapsedCount`, `compoundPathKey`, and `isFocusedMatch`
  - Update `copyWith` method
- [x] 2.2 Verify compilation and existing tests pass

## 3. Flattener Enhancements: JsonTreeFlattener
- [x] 3.1 Update `lib/src/ui/smart_tree/json_tree_flattener.dart`:
  - Integrate `ContextWindowCalculator` during array traversal when search matches are present in array elements
  - Support `manuallyExpandedRanges` (`Set<String>`) and `forcedShowAllArrays` (`Set<String>`)
  - Implement indentation flattening for unbranched single-child hierarchy chains (compress compound keys and depth)
- [x] 3.2 Add comprehensive unit tests in `test/src/ui/smart_tree/json_tree_flattener_test.dart`:
  - Verifying array segmentation and `collapsedRange` nodes during search
  - Verifying manual range expansion overrides
  - Verifying path compression for single-child Map/List chains
- [x] 3.3 Verify flattener tests pass with `flutter test test/src/ui/smart_tree/json_tree_flattener_test.dart`

## 4. UI Presentation: SmartVirtualJsonTree Enhancements
- [x] 4.1 Implement `collapsedRange` row rendering in `lib/src/ui/smart_tree/smart_virtual_json_tree.dart`:
  - Interactive placeholder banner (`… N verborgene Elemente (Index X bis Y) anzeigen`)
  - On tap, add range to `_manuallyExpandedRanges` and trigger rebuild
- [x] 4.2 Add array header context badge and toggle button:
  - Display `${matches.length} Treffer (Fokus: Treffer ±1)` badge
  - Toggle between `Alle N zeigen` and `Auf Treffer reduzieren`
- [x] 4.3 Implement center-scrolling in `jumpToMatch`:
  - Update `ItemScrollController.scrollTo` with `alignment: 0.5` and smooth duration/curve
  - Track `_activeMatchIndex` and render distinct active match styling (accent border and target badge)
- [x] 4.4 Render compound breadcrumb keys with clear styling (e.g. `parent . child`)

## 5. Localization
- [x] 5.1 Add localized strings to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`:
  - Collapsed range placeholder template
  - "Show all items" / "Reduce to matches" buttons
  - Array match focus badge label
- [x] 5.2 Run `flutter gen-l10n` if required and verify localization compilation

## 6. Widget Verification & Test Suite
- [x] 6.1 Add widget tests in `test/src/ui/smart_tree/smart_virtual_json_tree_test.dart`:
  - Verifying collapsed range placeholder display and tap expansion
  - Verifying array toggle button functionality
  - Verifying `jumpToMatch` centers on target match row and applies active focus indicator
  - Verifying compound breadcrumb rows
- [x] 6.2 Run full test suite (`flutter test test/src/ui/`)
- [x] 6.3 Run `dart analyze` to guarantee 0 lint/analysis issues
