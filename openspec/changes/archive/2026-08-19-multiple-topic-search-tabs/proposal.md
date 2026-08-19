# Proposal: Multiple Topic Search Tabs

## Why

Currently, when browsing topics in the Explorer view, the application only allows one open tab per topic on a cluster. If a user tries to open or search a topic that is already open on the active cluster, the view switches to the existing tab instead of allowing a new, independent search session. Users frequently need to run multiple concurrent searches with different filter parameters, start/end offset conditions, or timestamps on the same topic simultaneously without losing their previous search results.

## What Changes

- Enable opening multiple independent search tabs for the same topic on the same cluster in the Explorer view.
- Assign a unique session/tab identifier to each open topic tab so that state, filters, streaming sessions, and message lists operate independently.
- Provide user actions to open a new search tab for a topic (e.g. from the sidebar topic list action / context menu or a "New Tab" / "Duplicate Tab" action).
- Enhance the tab bar to distinguish between multiple open tabs of the same topic (e.g. index/instance indicators or descriptive labels) and allow closing individual tabs independently.
- Update `ActiveConnectionController` to manage tab instances by unique tab IDs rather than strict `(cluster, topic)` singletons, ensuring independent lifecycle and disposal of `MessageStreamController` instances.

## Capabilities

### New Capabilities

- `topic-search-tabs`: Multi-instance topic search and detail tab management in Explorer view, allowing multiple concurrent, independently configured search sessions on the same topic and cluster.

### Modified Capabilities
<!-- None -->

## Impact

- **UI / Presentation**:
  - `lib/src/features/explorer/presentation/explorer_view.dart`: Update tab bar and tab view rendering to support unique tab instances, tab labels with instance numbers or distinct identifiers, and actions to open new tabs.
  - `lib/src/features/topic/presentation/widgets/topic_list_item.dart`: Add action/context option to open an additional tab for a topic.
  - `lib/src/features/topic/topic_detail_view.dart`: Bind to unique tab/stream controller instance.
- **State Management**:
  - `lib/src/features/cluster/presentation/controllers/active_connection_controller.dart`: Refactor `OpenTopicRecord` to include a unique `tabId`, update stream controller mapping and lifecycle methods (`setActiveTopic`, `openNewTopicTab`, `closeTopicTab`).
- **Localization**:
  - Add localized strings for opening new search tabs and tab actions in `app_en.arb` and `app_de.arb`.
