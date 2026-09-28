## 1. Localization

- [x] 1.1 Add localized strings for the inspector dock toggle tooltips (`dockBottom`, `dockSide`, `closeInspector`), inspector tabs (`tabPayload`, `tabKeyAndHeaders`, `tabRawJson`), and copy metadata notifications to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, regenerate localizations, and verify keys in `AppLocalizations`.

## 2. Default Viewer Mode Performance Fix

- [x] 2.1 Update `JsonOrStringViewer` in `lib/src/ui/json_or_string_viewer.dart` to default `_viewMode` to `1` (Tree) instead of `2` (Cards) when valid JSON is parsed without an explicit initial mode or saved preference.
- [x] 2.2 Verify that opening valid JSON displays the Tree view immediately without triggering `JsonCardViewer`.

## 3. Inspector Panel Widget

- [x] 3.1 Create `lib/src/ui/messages/widgets/message_inspector_panel.dart` using `package:material_ui/material_ui.dart`.
- [x] 3.2 Implement the inspector header with message key summary, partition/offset/timestamp metadata chips with copy actions, dock-position toggle button (`Icons.dock` / `Icons.view_sidebar`), and close button (`Icons.close`).
- [x] 3.3 Implement the three tabs within `MessageInspectorPanel`:
  - `Payload`: embeds `JsonOrStringViewer` with search and copy support.
  - `Key & Headers`: displays key inspection card and structured list of Kafka headers with a count badge and per-header copy buttons.
  - `Raw JSON`: displays formatted full message JSON with single-click copy button.

## 4. Split-Screen Shell in MessagesView

- [x] 4.1 Define `InspectorDockPosition` enum (`bottom`, `side`) and persist preference in `SharedPreferences` under `message_inspector_dock_position`.
- [x] 4.2 Add `KafkaMessage? _selectedMessage` and `bool _isInspectorOpen` state to `_MessagesViewState` in `lib/src/ui/messages/messages_view.dart`.
- [x] 4.3 Update `_buildContent()` in `MessagesView` to wrap the active master view (`MessagesTableView` or `MessagesTimelineView`) and `MessageInspectorPanel` in an adaptive split layout:
  - Bottom-docking (default): `Column` with master view on top and fixed/constrained inspector on bottom.
  - Side-docking: `Row` with master view on left and inspector on right.
  - Closed: master view takes 100% of the available space.
- [x] 4.4 Wire inspector close action to clear `_isInspectorOpen` and restore full master view.

## 5. Master Stream Selection Highlight

- [x] 5.1 Update `MessagesTableView` (`lib/src/ui/messages/views/messages_table_view.dart`) to accept `selectedMessage` and visually highlight the active row with a distinct theme-compatible background color.
- [x] 5.2 Update row tap handling so clicking a message selects it in `MessagesView` and opens/updates the inspector panel without invoking `showDialog`.
- [x] 5.3 Update `MessagesTimelineView` (`lib/src/ui/messages/views/messages_timeline_view.dart`) to reflect the selected message state on timeline cards.
- [x] 5.4 Update `TopicDetailView` and `ScriptRunDetailsView` to utilize the integrated inspector rather than manually calling `showDialog(MessageDetailsDialog)`.

## 6. Verification and Tests

- [x] 6.1 Run unit and widget tests with `flutter test test/src/ui/messages/` to verify that message filtering, sorting, and view switching operate properly with the new inspector shell.
- [x] 6.2 Add widget tests for `MessageInspectorPanel` verifying metadata rendering, tab switching, and copy button interactions.
- [x] 6.3 Run `dart analyze` to ensure complete conformity with lint rules and type safety.
