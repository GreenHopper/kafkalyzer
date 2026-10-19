# Proposal

## Why

In Kafka clusters with hierarchical dot-separated topic naming conventions (such as `dataops.cdc.db2.jdbc.<TABLE>` or `kaenup.lopoco.temp.<EVENT>`), dozens of topics share a 20–30 character namespace prefix while the distinguishing segment is at the end. In the current 360px fixed-width sidebar, `TopicListItem` renders the topic name on a single line with end-truncation (`TextOverflow.ellipsis`) alongside inline partition (`12P`) and schema (`Avro`) micro-badges. Because the badges and shared prefix consume the available width, the distinguishing leaf name is truncated (`dataops.cdc.db2.jdbc.LK...`), making rows visually identical. Furthermore, the hover tooltip omits the full topic name and schema indicator, and the sidebar cannot be resized.

## What Changes

- **Remove Inline Metadata Micro-Badges from `TopicListItem`**: Remove the `<N>P` partition badge and `Avro` schema badge from the `TopicListItem` row so the entire horizontal space is dedicated to the topic name and trailing action button(s).
- **Comprehensive Hover Tooltip**: Update the `TopicListItem` tooltip to always include the full untruncated topic name on the first line, followed by partition count, replication factor, retention, cleanup policy, and schema status (`Avro` when present).
- **Single-Line Middle-Ellipsis Truncation (`…`)**: When a single-line topic name exceeds the available width in `TopicListItem`, dynamically truncate the middle of the string (`prefix` / middle segments) with `…` via `LayoutBuilder` and `TextPainter`, preserving both the leading context and the bold terminal leaf segment (or the end of the leaf segment if the leaf alone exceeds the width).
- **Search Match Highlighting**: Pass the active filter query (`highlightQuery`) into `TopicListItem` (in both `ExplorerView` and `TopicSelectionDialog`) and highlight matching substrings within the single-line rendered topic name.
- **Resizable Explorer Sidebar**: Replace the fixed `360px` sidebar width in `ExplorerView` with a user-resizable width (drag handle on the right sidebar border, clamped between `260px` and `700px`, persisted in `SharedPreferences` under `explorer_sidebar_width`).

## Capabilities

### New Capabilities

### Modified Capabilities
- `compact-topic-sidebar`: Update `High-Density Topic List Items` requirement to omit inline `<N>P` and `Avro` micro-badges from the row, move all metadata (including full topic name and schema status) into the hover tooltip, apply single-line middle-ellipsis truncation (`…`), highlight active search filter matches, and add a `Resizable Topic Sidebar` requirement.

## Impact

- **UI Widgets**:
  - `lib/src/features/topic/presentation/widgets/topic_list_item.dart`
  - `lib/src/features/topic/topic_utils.dart`
  - `lib/src/features/explorer/presentation/explorer_view.dart`
  - `lib/src/features/search/presentation/widgets/topic_selection_dialog.dart`
- **Localization**:
  - `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb` (tooltip strings with schema indicator if needed)
- **Tests**:
  - `test/src/features/topic/presentation/widgets/topic_list_item_test.dart`
  - `test/src/features/explorer/presentation/explorer_view_test.dart`
