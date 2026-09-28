## 1. Domain & Extraction Utilities

- [x] 1.1 Implement `JsonPathExtractor` in `lib/src/utils/json_path_extractor.dart` supporting dot-notation (`customer.name`), list index brackets (`items[0].id`), and null-safe traversal; verify via `dart analyze`.
- [x] 1.2 Write unit tests for `JsonPathExtractor` in `test/src/utils/json_path_extractor_test.dart` covering primitives, nested maps, array indices, missing keys, null payloads, and malformed JSON; verify via `flutter test test/src/utils/json_path_extractor_test.dart`.
- [x] 1.3 Create `ProjectedColumn` model in `lib/src/ui/messages/models/projected_column.dart` with JSON serialization for persistence and header label formatting; verify via `dart analyze`.

## 2. Dynamic Field Projection in MessagesTableView

- [x] 2.1 Extend `_TableRowData` in `lib/src/ui/messages/views/messages_table_view.dart` to cache pre-extracted `projectedValues` map (`Map<String, String>`); verify via `dart analyze`.
- [x] 2.2 Update `MessagesTableView` parameters to accept `List<ProjectedColumn> projectedColumns` and `ValueChanged<ProjectedColumn>? onRemoveProjectedColumn`; verify via `dart analyze`.
- [x] 2.3 Implement dynamic `TableSpan` column calculation and cell builder rendering for projected columns in `MessagesTableView`, including `EntityFormatterRegistry` badge integration; verify via `dart analyze`.
- [x] 2.4 Add sortable header with sort indicators, substring filter dialog, and remove column icon button for projected columns in `MessagesTableView`; verify via `dart analyze`.
- [x] 2.5 Write widget tests in `test/src/ui/messages/views/messages_table_view_projection_test.dart` verifying projected column rendering, sorting, filtering, and remove action callback; verify via `flutter test test/src/ui/messages/views/messages_table_view_projection_test.dart`.

## 3. "Pin to Table Column" Action in SmartVirtualJsonTree

- [x] 3.1 Extend `SmartVirtualJsonTree` in `lib/src/ui/smart_tree/smart_virtual_json_tree.dart` with `ValueChanged<String>? onPinToColumn` callback and add "Pin as Column" icon button to node rows; verify via `dart analyze`.
- [x] 3.2 Implement path normalization in `SmartVirtualJsonTree` to convert node hierarchy paths (`root.leistungen[0].transportId`) to standard JSON paths (`leistungen[0].transportId`); verify via `dart analyze`.
- [x] 3.3 Plumb `onPinToColumn` through `JsonOrStringViewer` (`lib/src/ui/json_or_string_viewer.dart`) and `MessageInspectorPanel` (`lib/src/ui/messages/widgets/message_inspector_panel.dart`); verify via `dart analyze`.
- [x] 3.4 Write widget tests in `test/src/ui/smart_tree/smart_virtual_json_tree_pin_test.dart` verifying that clicking the pin button invokes `onPinToColumn` with the normalized path; verify via `flutter test test/src/ui/smart_tree/smart_virtual_json_tree_pin_test.dart`.

## 4. Preset Persistence & MessagesView Integration

- [x] 4.1 Update `MessagesView` in `lib/src/ui/messages/messages_view.dart` to maintain active `List<ProjectedColumn>` state and provide `addProjectedColumn`, `removeProjectedColumn`, and `resetProjectedColumns`; verify via `dart analyze`.
- [x] 4.2 Implement loading and saving projected column presets in `SharedPreferences` scoped by topic name (`topic_columns_preset_<topic>`); verify via `dart analyze`.
- [x] 4.3 Add a reset/clear columns action in `MessagesView` toolbar when projected columns are active; verify via `dart analyze`.
- [x] 4.4 Add localized strings for English (`lib/l10n/app_en.arb`) and German (`lib/l10n/app_de.arb`) and run `flutter gen-l10n`; verify localization generation succeeds.
- [x] 4.5 Write integration widget tests in `test/src/ui/messages/messages_view_projection_test.dart` verifying end-to-end pinning from inspector to table, column removal, and preset persistence; verify via `flutter test test/src/ui/messages/messages_view_projection_test.dart`.

## 5. Verification & Quality Assurance

- [x] 5.1 Run `dart analyze` across the entire codebase to ensure 0 lint or static analysis issues.
- [x] 5.2 Run `flutter test test/src/ui/` to ensure all existing and new UI tests pass cleanly without regression.
