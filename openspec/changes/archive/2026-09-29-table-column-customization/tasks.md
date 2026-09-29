## 1. Data Models, Localization & Presets Persistence

- [x] 1.1 Define standard column identifiers, default column widths, and extend column configuration model (`TableColumnConfig`) with JSON serialization supporting hidden columns, custom widths, and projected columns with legacy list migration; verify with unit tests.
- [x] 1.2 Add localization strings in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` for column configuration menu, hide column action, and reset layout; verify with `flutter gen-l10n`.
- [x] 1.3 Update preset loading and saving in `MessagesView` (`_loadProjectedColumnsPreference` and `_saveProjectedColumnsPreference`) to persist both column visibility and widths; verify via SharedPreferences persistence test.

## 2. Table Column Resizing Implementation

- [x] 2.1 Refactor `MessagesTableView` column spans to use dynamic pixel widths from configuration with boundary clamping (minimum 60px, maximum 800px); verify standard and projected columns render with correct initial widths.
- [x] 2.2 Implement interactive header resize handles on column borders using `MouseRegion` (resize cursor) and `GestureDetector` (horizontal drag); verify drag gestures dynamically adjust column widths during dragging.
- [x] 2.3 Add completion callback (`onColumnWidthChanged`) on drag end to persist the updated widths without rebuilding cached message row data; verify state updates cleanly.
- [x] 2.4 Implement double-click auto-fit logic on header resize handles measuring header text and sample row contents using `TextPainter`, clamping within bounds, and updating width; verify double-tap auto-fits column width.

## 3. Column Visibility Management UI

- [x] 3.1 Update column index mapping and span computation in `MessagesTableView` to support hiding any standard column (Timestamp, Partition, Offset, Key, Content, Step, Topic); verify table renders properly when standard columns are hidden.
- [x] 3.2 Add quick-hide action to column headers and context action to remove/hide any column; verify hiding updates the visible column list.
- [x] 3.3 Add a "Columns" configuration menu button (`MenuAnchor`) in the `MessagesView` toolbar with checkboxes for toggling standard and projected columns, enforcing at least one visible column safeguard; verify UI behavior.
- [x] 3.4 Update the "Reset columns" toolbar action to restore all standard columns to visible and reset all column widths to default; verify reset restores default layout.

## 4. Testing & Verification

- [x] 4.1 Add widget tests in `test/src/ui/messages/views/messages_table_view_customization_test.dart` verifying column resizing and standard column hiding.
- [x] 4.2 Add integration widget tests in `test/src/ui/messages/messages_view_column_customization_test.dart` verifying toolbar column menu toggles, presets persistence, and reset behavior.
- [x] 4.3 Run `flutter test` and `dart analyze` to ensure zero regressions across all test suites.
