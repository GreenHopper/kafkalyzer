## 1. Localization & Configuration

- [x] 1.1 Add localized strings for "Hide empty fields" (`hideEmptyFields`), "Show empty fields" (`showEmptyFields`), hidden field counters, and timestamp tooltip labels to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, and verify with `flutter gen-l10n`.

## 2. Tree Flattener Enhancements (Null Filtering & Auto-Expansion)

- [x] 2.1 Update `JsonTreeFlattener.flatten()` to support `bool hideNullFields = false`, skipping null map entries and updating child counts, and verify with unit tests in `test/src/ui/smart_tree/json_tree_flattener_test.dart`.
- [x] 2.2 Update `JsonTreeFlattener.flatten()` and `SmartVirtualJsonTreeState` to auto-expand single-item lists and single-entry maps by default unless explicitly collapsed, and verify with unit tests in `test/src/ui/smart_tree/json_tree_flattener_test.dart`.

## 3. Entity Formatter Engine (Null-Aware & Extended Badges)

- [x] 3.1 Refactor `EntityFormatterRegistry.tryFormat()` to filter nulls and empty collections before evaluating field counts and primitive constraints, enabling badges on objects with 5 fields where 3 are null, and verify with unit tests in `test/src/ui/smart_tree/entity_formatter_registry_test.dart`.
- [x] 3.2 Add time-window heuristic support in `EntityFormatterRegistry` for nested timestamp objects and German interval keys (`planTimestampVon`/`planTimestampBis`, `von`/`bis`), and verify with unit tests.
- [x] 3.3 Add standalone timestamp entity heuristic in `EntityFormatterRegistry` for timestamp-with-metadata objects (`timestamp` + `zeitQuelle`), and verify with unit tests.
- [x] 3.4 Add route / transport leg entity heuristic in `EntityFormatterRegistry` for paired directional keys (`von...`/`nach...`, `from`/`to`, `origin`/`destination`), and verify with unit tests.

## 4. UI Presentation & Toolbar Controls

- [x] 4.1 Implement localized smart timestamp formatting in `SmartVirtualJsonTree._buildPrimitiveText` with clock icon and raw/UTC tooltip inspection, and verify with widget tests in `test/src/ui/smart_tree/smart_virtual_json_tree_test.dart`.
- [x] 4.2 Add "Hide empty fields" toggle button with indicator to `JsonOrStringViewer` toolbar and wire through to `SmartVirtualJsonTree`, persisting user preference in `SharedPreferences`, and verify with widget tests.
- [x] 4.3 Update `TimelineMessageCard` / `TextPreviewUtils` to filter null-valued keys from JSON payload previews, and verify with unit tests in `test/src/ui/messages/widgets/timeline_message_card_test.dart`.

## 5. Verification & Analysis

- [x] 5.1 Run `dart analyze` and `flutter test` across all affected test suites (`test/src/ui/smart_tree/` and `test/src/ui/messages/`) to verify clean analysis and all passing tests.
