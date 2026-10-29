# Proposal

## Why

The topic detail screen currently presents two separate buttons that trigger message retrieval: a primary "Stream" / "Stop" button in the header progress tile (top right) and a duplicate action button ("Fetch N Messages" / "Start Live Stream" / "Stop") in the search bar control row (lower right). Having two distinct buttons that perform the same message retrieval action creates visual clutter, takes up horizontal space needed for search and filter inputs, and confuses users about which control to interact with. Removing the lower-right button consolidates message retrieval triggering in the header and streamlines the search bar.

## What Changes

- Remove the lower-right action button (`_buildActionButton`) from `TopicSearchBar` in both wide and narrow responsive layouts.
- Reclaim the horizontal space previously occupied by the action button, allowing the quick filter input to expand naturally.
- Remove obsolete button parameters and properties (`isStreaming`, `isDirty`, `onStop`) from `TopicSearchBar` where they were solely used to render and style the lower-right button.
- Retain the quick filter field's `onSubmitted` submission trigger so users can still press Enter to initiate retrieval with active filters.
- Update `TopicDetailView` to stop passing the removed action-button parameters to `TopicSearchBar`.
- Update widget unit and integration tests to verify the streamlined search bar without the lower-right action button and assert message streaming controls on the header progress tile.

## Capabilities

### New Capabilities

*(None)*

### Modified Capabilities

- `topic-consumption`: Modify message consumption triggers by removing the search bar integrated action button requirement and its corresponding dirty-state indicator, consolidating consumption controls in the header progress tile.

## Impact

- **UI Components**: `TopicSearchBar` in `lib/src/features/search/presentation/widgets/topic_search_bar.dart` and `TopicDetailView` in `lib/src/features/topic/topic_detail_view.dart`.
- **Localization**: Strings `fetchMessagesCount` and `fetchMessages` in `lib/l10n/app_*.arb` and generated files can be retired or kept deprecated.
- **Tests**: `test/src/features/search/presentation/widgets/topic_search_bar_test.dart` and any related widget tests expecting `search_bar_start_button` or `search_bar_stop_button`.
- **Dependencies & Backend**: None. No Rust bridge or Kafka transport changes required.
