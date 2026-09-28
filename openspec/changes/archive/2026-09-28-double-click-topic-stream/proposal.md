## Why

When browsing Kafka clusters in the Topic Explorer, users frequently want to inspect recent messages immediately upon selecting a topic. Currently, opening a topic requires selecting it in the sidebar and then manually clicking the green "Stream" button in the search configuration area. Allowing users to simply double-click any topic in the topic explorer to open/focus the topic tab and immediately initiate streaming with default settings (latest 200 messages) significantly streamlines the exploratory workflow and saves repeated manual clicks.

## What Changes

- Add a double-click (`onDoubleTap`) interaction to topic items in the Topic Explorer sidebar list (`TopicListItem` and `ExplorerView`).
- Double-clicking a topic item will:
  1. Open the topic tab if it is not yet opened, or switch to the existing tab if already open.
  2. Immediately trigger message consumption on the active tab's `MessageStreamController` with the standard default parameters (`startFromTail: true`, `maxResults: 200`, `filterType: FilterType.contains`, `searchScope: SearchScope.both`, `runForever: false`).
- Support a trigger mechanism so that `TopicDetailView` or `ActiveConnectionController` / `MessageStreamController` properly coordinates starting the stream without requiring manual interaction with the "Stream" button.

## Capabilities

### Modified Capabilities
- `topic-search-tabs`: Add requirement for quick streaming on double-clicking a topic in the Explorer sidebar.

## Impact

- **Frontend UI (`lib/src/features/topic/` and `lib/src/features/explorer/`)**:
  - `TopicListItem`: Support optional `onDoubleTap` callback in `ListTile` / `InkWell`.
  - `ExplorerView`: Wire `onDoubleTap` on `TopicListItem` to open/focus the tab and trigger streaming.
  - `TopicDetailView` / `MessageStreamController`: Ensure seamless invocation of default search execution on double-click.
- **Backend / Rust**: No changes required (reuses existing `consumeWithFilter` / `startStreaming` bridge API).
