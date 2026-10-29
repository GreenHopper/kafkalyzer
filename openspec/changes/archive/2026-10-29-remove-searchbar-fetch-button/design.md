# Design

## Context

In `TopicDetailView`, topic operations are controlled across two visual tiers:
1. The topic header bar, which includes `TopicProgressTile` with `_buildProgressActions` hosting the primary Stream/Stop button (`FilledButton.icon`) and Clear Messages button.
2. The search bar (`TopicSearchBar`), which contains scan mode selector, limit dropdown, quick filter input, advanced filters toggle button, and an integrated trailing action button (`_buildActionButton`) displaying dynamic labels ("Fetch N Messages", "Start Live Stream", "Stop", or "Refresh" when parameters are dirty).

Because both the header tile and the search bar provide buttons that invoke `startStreaming()` and `streamController.stopStreaming()`, the lower-right button in `TopicSearchBar` is redundant.

## Goals / Non-Goals

**Goals:**
- Remove `_buildActionButton` from `TopicSearchBar` across both wide and narrow responsive layout branches.
- Expand the quick filter input to take full advantage of available horizontal space in the search bar row.
- Retain keyboard submission (`onSubmitted` in the quick filter `TextField`) calling `_onStart()` so users can still trigger retrieval via the Enter key.
- Remove obsolete parameters (`isStreaming`, `isDirty`, `onStop`) from `TopicSearchBar` and clean up their callers in `TopicDetailView`.
- Refactor existing widget tests to verify the updated layout and test filter submission via Enter.

**Non-Goals:**
- Changing the header `TopicProgressTile` or modifying its Stream/Stop button behavior.
- Altering any Kafka consumer logic, streaming parameters, or Rust bridge interfaces.
- Changing advanced filter controls, chips, or scan mode options.

## Decisions

### Decision 1: Remove `_buildActionButton` and its responsive row placement
- **Choice**: Completely remove `_buildActionButton` and its trailing `SizedBox(width: 8)` from both `isWide` (single-row) and narrow (two-row) branches of `TopicSearchBar`. The trailing element in the primary row is now `_buildAdvancedToggleButton`.
- **Rationale**: The header button is always visible when viewing messages. Removing the search bar action button eliminates visual redundancy and prevents layout crowding on smaller desktop window sizes.
- **Alternatives considered**:
  - *Convert to a compact icon-only button*: Still duplicates functionality and clutters the search bar.
  - *Conditionally show only when dirty*: Inconsistent UI affordance where a button appears and disappears.

### Decision 2: Retain `onStart` callback for keyboard submission
- **Choice**: Keep `final VoidCallback onStart` and `_onStart()` in `TopicSearchBar`, invoked from `_buildQuickFilterInput`'s `onSubmitted`.
- **Rationale**: Desktop users expect pressing Enter in a search/filter input to execute the search immediately.
- **Alternatives considered**:
  - *Remove `onStart` completely*: Forces users to leave the keyboard and click the top-right Stream button after typing a query.

### Decision 3: Remove unused properties (`isStreaming`, `isDirty`, `onStop`) from `TopicSearchBar`
- **Choice**: Strip `widget.isStreaming`, `widget.isDirty`, and `widget.onStop` from `TopicSearchBar` and update `TopicDetailView` accordingly.
- **Rationale**: `TopicSearchBar` is an internal feature widget. Retaining dead callbacks and state properties increases cognitive overhead and maintenance costs.
- **Alternatives considered**:
  - *Keep parameters marked optional*: Leaves dead parameters in place with no UI effect.

### Decision 4: Adapt Widget Tests to Validate New Layout
- **Choice**: In `topic_search_bar_test.dart`, remove tests asserting `search_bar_start_button` / `search_bar_stop_button` rendering and update regex/start tests to trigger `tester.testTextInput.receiveAction(TextInputAction.done)` or `tester.sendKeyEvent(LogicalKeyboardKey.enter)` on the filter input. Verify that `search_bar_start_button` is no longer found.
- **Rationale**: Preserves test coverage of regex validation and search invocation while reflecting the updated UI contract.

## Risks / Trade-offs

- **[Risk]** Users accustomed to clicking the lower-right button to start retrieval may momentarily look for it.
  → **Mitigation**: The top-right Stream button is styled prominently with a green fill and play icon right next to the scan progress bar, making it immediately visible. In addition, pressing Enter in the filter text field immediately executes the retrieval.
- **[Trade-off]** The visual dirty-state indicator (refresh icon and badge) that was attached to the lower-right button will no longer be shown in the search bar.
  → **Mitigation**: Parameters take effect immediately upon next stream invocation, matching typical desktop search bar semantics.
