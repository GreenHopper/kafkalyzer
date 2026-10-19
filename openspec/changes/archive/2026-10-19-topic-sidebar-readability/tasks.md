# Tasks

## 1. Middle-Ellipsis & Highlight Span Utilities

- [x] 1.1 In `lib/src/features/topic/topic_utils.dart`, implement `computeMiddleEllipsisIndices(String topicName, int maxVisibleChars)` (and width-aware helper using `TextPainter`) that preserves the leading namespace prefix start and the terminal leaf segment (`leaf` after the last `.`), inserting `…` in the middle when the topic name exceeds the available single-line width.
- [x] 1.2 In `lib/src/features/topic/topic_utils.dart`, implement `buildTopicNameSpans(...)` that combines hierarchical segment styling (`prefix` dimmed normal weight, `leaf` bold weight), optional middle-ellipsis (`…`), and case-insensitive search match highlighting (`highlightQuery`) into a list of `TextSpan`s.
- [x] 1.3 Add unit tests in `test/src/features/topic/topic_utils_test.dart` covering `computeMiddleEllipsisIndices` and `buildTopicNameSpans` (short names, long hierarchical names with shared prefixes, single-segment long names, and case-insensitive match highlighting).

## 2. `TopicListItem` Refactoring (Badge Removal, Full Tooltip, Middle Ellipsis & Highlighting)

- [x] 2.1 Update `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` (and run `flutter gen-l10n`) if needed so the tooltip format cleanly supports displaying the schema status (`Schema: Avro`).
- [x] 2.2 In `lib/src/features/topic/presentation/widgets/topic_list_item.dart`, add an optional `String? highlightQuery` parameter to `TopicListItem`.
- [x] 2.3 Remove the inline `<N>P` partition micro-badge and `Avro` schema micro-badge from `TopicListItem._buildTrailing`, leaving only the selection checkmark, custom `trailing` widget, and `onOpenInNewTab` button.
- [x] 2.4 Update `TopicListItem._buildTooltipMessage` to always include the full `topic.name` on the first line, followed by partition count, replication factor, retention, cleanup policy, and `Schema: Avro` (when `hasSchema` is true).
- [x] 2.5 Update `TopicListItem._buildTitle` to use `LayoutBuilder` and `TextPainter` with `buildTopicNameSpans` so overflowing single-line topic names use middle-ellipsis (`…`) and highlight `highlightQuery` matches.
- [x] 2.6 Pass the active filter query (`highlightQuery`) to `TopicListItem` in `lib/src/features/explorer/presentation/explorer_view.dart` (`activeController.topicFilter`) and `lib/src/features/search/presentation/widgets/topic_selection_dialog.dart` (`_searchController.text`).

## 3. Resizable Explorer Sidebar

- [x] 3.1 In `lib/src/features/explorer/presentation/explorer_view.dart`, add `sidebarWidthPrefKey = 'explorer_sidebar_width'`, `defaultSidebarWidth = 360.0`, `minSidebarWidth = 260.0`, and `maxSidebarWidth = 700.0`, and load/restore `_sidebarWidth` from `SharedPreferences`.
- [x] 3.2 Add a vertical drag resize handle (`Key('explorer_sidebar_resize_handle')`) on the right edge of the expanded Explorer sidebar that updates `_sidebarWidth` within `[minSidebarWidth, maxSidebarWidth]` on horizontal drag and persists the width to `SharedPreferences` on drag end.

## 4. Widget Tests & Verification

- [x] 4.1 Update `test/src/features/topic/presentation/widgets/topic_list_item_test.dart` to verify that inline `<N>P` and `Avro` badges are omitted from the row, the tooltip includes the full topic name and `Schema: Avro`, long topic names truncate in the middle with `…` while keeping the leaf suffix visible, and `highlightQuery` highlights matching text.
- [x] 4.2 Add widget tests in `test/src/features/explorer/presentation/explorer_view_test.dart` verifying that dragging `explorer_sidebar_resize_handle` resizes the sidebar within bounds and persists `explorer_sidebar_width` in `SharedPreferences`.
- [x] 4.3 Run `dart analyze`, `dart format --output=none --set-exit-if-changed .`, and `flutter test` to verify all tests pass with zero warnings.
