# Design: Multiple Topic Search Tabs

## Context

See `proposal.md` for motivation and background.
Currently, `ActiveConnectionController` stores open tabs as `OpenTopicRecord(topic, profile)` and keys `MessageStreamController` instances strictly by `'$clusterName:$topicName'`. This restricts each topic on a cluster to a single tab and a single stream controller. When a user clicks a topic that is already open, it activates the existing tab instead of creating a new search session.

## Goals / Non-Goals

**Goals:**

- Allow multiple concurrent search/detail tabs for the same topic on the same cluster in the Explorer view.
- Ensure complete isolation of search state (stream controller, offset/timestamp strategies, search query, filter types, and buffer) between tabs.
- Provide clear UI actions to open a new tab session for a topic (e.g. context menu or trailing action on sidebar topic items, plus tab duplication actions).
- Visually disambiguate multiple tabs for the same topic in the tab bar with instance numbering (e.g. `orders (1)`, `orders (2)`).
- Ensure safe lifecycle management: closing a tab disposes only its `MessageStreamController` without affecting other open tabs.

**Non-Goals:**

- Syncing or linking search filters across different tabs (tabs are intentionally independent).
- Persisting open tabs and their active search results across app restarts.
- Changing search execution in the Rust backend crate (`kafkalyzer-kafka`), which already supports independent consumer streams.

## Decisions

### 1. Tab Identification via Unique Tab IDs

- **Choice**: Introduce a unique identifier (`tabId` generated using UUID or timestamp-based sequence) in `OpenTopicRecord`:

  ```dart
  class OpenTopicRecord {
    final String id;
    final TopicMetadata topic;
    final ClusterProfile profile;

    OpenTopicRecord({
      required this.id,
      required this.topic,
      required this.profile,
    });
  }
  ```

- **Rationale**: Relying on composite string keys like `'$clusterName:$topicName'` creates collisions when the same topic is opened multiple times. An explicit `id` guarantees O(1) lookups and safe cleanup.
- **Alternatives Considered**:
  - *Integer index based keys*: Fragile when tabs are closed out of order.
  - *Keep composite key with suffix*: More prone to parsing errors and synchronization bugs.

### 2. Stream Controller Lifecycle Scoped to Tab ID

- **Choice**: Key `ActiveConnectionController._streamControllers` by `record.id`.
- **Rationale**: Each tab gets its own `MessageStreamController` lifecycle. When a tab is closed, only its corresponding controller is canceled, disposed, and removed from the map.
- **Alternatives Considered**:
  - *Managing stream controller within `_TopicDetailViewState`*: Moving controller ownership entirely to widget state causes stream loss if the widget unmounts or rebuilds during navigation changes. Keeping it in `ActiveConnectionController` allows tabs to maintain active streams across navigation rail changes and background execution.

### 3. User Interaction for Opening Tabs

- **Choice**:
  - **Sidebar Topic Item Tap**: If no tab is open for the topic, open a new tab. If a tab already exists, activate the existing active tab for that topic (preserving default quick-navigation behavior).
  - **Sidebar Context Menu / Trailing Action**: Provide an explicit "Open in New Tab" action on each topic item.
  - **Tab Context Menu / Action**: Allow duplicating or opening a new search tab directly from the tab bar or tab header.
- **Rationale**: Preserves the familiar quick-navigation workflow for single-tab usage while giving an intuitive, explicit way to spawn additional tabs when needed.

### 4. Tab Bar Disambiguation

- **Choice**: Dynamically compute display titles in the tab bar. When multiple tabs share the same `(cluster, topic)` tuple, append an index suffix (e.g. `topic-name (1)`, `topic-name (2)`). If only one tab is open for that topic, display the plain topic name.
- **Rationale**: Clean and unambiguous UI without cluttering single-tab workflows.

### 5. IndexedStack View Mapping

- **Choice**: Key child views in `IndexedStack` using `ValueKey(record.id)` and pass `record` (or `record.id`) to `TopicDetailView`.
- **Rationale**: Flutter's `IndexedStack` preserves widget state (`AutomaticKeepAliveClientMixin`) across tab switches, ensuring filters and scroll positions remain intact while switching between tabs.

## Risks / Trade-offs

- **[Risk] Resource usage with many concurrent streams** → *Mitigation*: Each `MessageStreamController` streams independently; users can stop streams or close tabs. Stream cancellation on tab close ensures native Kafka consumers are cleanly stopped.
- **[Risk] Tab bar overflow with many open tabs** → *Mitigation*: `ExplorerView` already supports horizontal scrolling with smooth wheel / pointer drag configuration on the tab bar.
- **[Risk] Disconnecting or switching active cluster** → *Mitigation*: `ActiveConnectionController.disconnect()` cleans up and disposes all active stream controllers across all open tabs.
