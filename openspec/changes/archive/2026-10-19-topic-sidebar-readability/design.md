# Design

## Context

In `v1.5.0`, `TopicListItem` (`lib/src/features/topic/presentation/widgets/topic_list_item.dart`) renders topic names on a single line (`maxLines: 1, overflow: TextOverflow.ellipsis`) inside a fixed `360px` sidebar in `ExplorerView`. Because enterprise Kafka clusters frequently use deep dot-separated namespaces (e.g., `dataops.cdc.db2.jdbc.LKW_...` or `kaenup.lopoco.temp.migration...`), the first 20–30 characters are identical across many topics while inline `<N>P` and `Avro` micro-badges consume ~80px on the right. Consequently, `TextOverflow.ellipsis` cuts off the distinguishing leaf name at the end, leaving dozens of visually identical rows.

## Goals / Non-Goals

**Goals:**
- Keep `TopicListItem` strictly single-line (`maxLines: 1`) to preserve high vertical density (~8–12 topics visible simultaneously).
- Free up horizontal space in `TopicListItem` by removing inline `<N>P` and `Avro` micro-badges from the row and consolidating all metadata (including the full topic name and schema presence) into the hover tooltip.
- Implement dynamic **middle-ellipsis truncation (`…`)** so that when a topic name exceeds the available width, the middle of the string is elided while preserving both the leading prefix start and the bold terminal leaf segment.
- Support **case-insensitive search match highlighting** (`highlightQuery`) within the rendered topic name (both in `ExplorerView` and `TopicSelectionDialog`), working seamlessly alongside hierarchical styling (`prefix` dimmed, `leaf` bold) and middle-ellipsis truncation.
- Make the `ExplorerView` sidebar horizontally resizable via a drag divider (`260px`–`700px`, default `360px`) with persistence in `SharedPreferences`.

**Non-Goals:**
- Multi-line topic cards or collapsible namespace tree folders in the sidebar.
- Modifying Rust backend metadata fetching or `TopicMetadata` FFI structs.

## Decisions

### 1. Removing Inline Micro-Badges & Enriching the Hover Tooltip
- **Decision:** Remove `_buildMicroBadge` calls for `<N>P` (partition count) and `Avro` (schema indicator) from `TopicListItem._buildTrailing`. Keep only the selection checkmark (`isSelected`), custom `trailing` widget (used in `TopicSelectionDialog`), and the `onOpenInNewTab` icon button.
- **Tooltip Structure:** `_buildTooltipMessage(BuildContext context)` will always place `topic.name` on the first line, followed by a newline (`\n`) and the metadata summary:
  - Line 1: `<topic.name>`
  - Line 2: `Partitions: <N> • RF: <M> [• Retention: <R> • Cleanup: <C>] [• Schema: Avro]` (localized via `AppLocalizations`).
- **Rationale:** Removing the two badges reclaims ~75–85px per row (over 35% of the previously available text width), allowing most topic names to fit without truncation even at the default 360px sidebar width.

### 2. Single-Line Middle-Ellipsis Truncation (`…`) with Hierarchical & Highlight Spans
- **Decision:** Use `LayoutBuilder` inside `TopicListItem._buildTitle` to obtain `constraints.maxWidth` and compute the displayed character ranges lazily for the visible list items.
- **Truncation Algorithm (`truncateTopicNameMiddle` in `topic_utils.dart`):**
  1. Measure the full `topic.name` using `TextPainter(maxLines: 1)` with the effective bold/normal text metrics. If it fits within `maxWidth`, render the full `topic.name` with zero truncation.
  2. If it overflows `maxWidth`:
     - We want to preserve a leading slice of length $L_{\text{head}}$ (`topic.name.substring(0, headEnd)`) and a trailing slice of length $L_{\text{tail}}$ (`topic.name.substring(tailStart)`), joined by `'…'`.
     - Prioritize preserving the terminal leaf segment (`leaf` after the last `.`) up to `65%` of total visible characters (and at least `min(6, prefix.length)` leading characters of `prefix` so the namespace origin remains clear, e.g., `dataops.cdc…LKW_TRANSPORT_ORDER`).
     - If the `leaf` alone is wider than `65%` of `maxWidth`, keep the first ~35% of characters from the start of `topic.name` and the last ~65% of characters from the end of `topic.name` so the very end of the topic name (often version numbers or suffixes like `...PreSelection` / `...Rejected`) is always visible.
     - Use binary search on total visible character count $K \in [4, N-1]$ with `TextPainter` to find the maximum $K$ that fits `maxWidth`.
- **Unified Span Builder (`buildTopicNameSpans`):**
  - Given the original `topic.name` (with `lastDotIndex` separating `prefix` `[0, lastDotIndex + 1)` and `leaf` `[lastDotIndex + 1, N)`), the optional `highlightQuery`, and the optional elided range `[headEnd, tailStart)`:
  - For each visible character index $i$, we know:
    - Whether $i$ belongs to `prefix` (normal weight, dimmed color) or `leaf` (bold weight, primary surface color).
    - Whether $i$ falls within a case-insensitive match of `highlightQuery` in `topic.name` (or within the visible substring). When highlighted, apply `backgroundColor: colorScheme.tertiaryContainer` (or `primaryContainer` / `primary.withValues(alpha: 0.22)`), `color: colorScheme.onSurface`, and `FontWeight.bold`.
  - Contiguous characters sharing the same style are grouped into minimal `TextSpan` runs, with a dimmed `'…'` `TextSpan` inserted at `headEnd` when truncated.
- **Performance:** Because `ListView.builder` only builds the ~15–25 items currently in the viewport, running a fast binary search (at most 6–7 `TextPainter.layout` calls only on overflowing items) takes `< 0.2ms` per frame and maintains 60/120 FPS scrolling.

### 3. Resizable Explorer Sidebar with `SharedPreferences` Persistence
- **Decision:** In `ExplorerView` (`lib/src/features/explorer/presentation/explorer_view.dart`):
  - Add static constants:
    - `sidebarWidthPrefKey = 'explorer_sidebar_width'`
    - `defaultSidebarWidth = 360.0`
    - `minSidebarWidth = 260.0`
    - `maxSidebarWidth = 700.0`
  - Store `double _sidebarWidth = defaultSidebarWidth;` in `_ExplorerViewState`.
  - Load `_sidebarWidth` in `_loadSidebarPreference()` alongside `_isSidebarCollapsed`.
  - When `_isSidebarCollapsed` is `false`, render a `Row(mainAxisSize: MainAxisSize.min)` containing the `SizedBox(width: _sidebarWidth, child: _buildSidebar(...))` and a `6px` interactive resize divider (`Key('explorer_sidebar_resize_handle')`) with `MouseRegion(cursor: SystemMouseCursors.resizeLeftRight)` and `GestureDetector(onHorizontalDragUpdate: ..., onHorizontalDragEnd: ...)`.
  - During `onHorizontalDragUpdate`, update `_sidebarWidth = (_sidebarWidth + details.delta.dx).clamp(minSidebarWidth, maxSidebarWidth)` via `setState`.
  - Persist `_sidebarWidth` to `SharedPreferences` in `onHorizontalDragEnd` (avoiding disk writes on every drag pixel).

## Risks / Trade-offs

- **Widget Tests Searching for Plain Text on Truncated Items:** Existing tests in `topic_list_item_test.dart` and `explorer_view_test.dart` use short topic names like `'test-topic'` or `'com.company.orders.incoming'`, which easily fit within the default width without truncation. However, existing tests in `topic_list_item_test.dart` that assert `find.text('3P')`, `find.text('12P')`, or `find.text('Avro')` on the card face must be updated to verify that those badges are no longer rendered inline and instead appear in the `Tooltip` message along with the topic name.
