## Context

In Kafkalyzer's Explorer view, the left sidebar lists clusters and their topics via `ExplorerView` and `TopicListItem`. Selecting a topic opens or switches to its tab, but starting message streaming requires an additional click on the "Stream" button inside `TopicDetailView`.

The search configuration defaults in `TopicDetailView` are:
- `startStrategy`: `MultiSearchStartStrategy.latest` (`startFromTail: true`)
- `endStrategy`: `MultiSearchEndStrategy.latest` (`runForever: false`)
- `maxResults`: `200`
- `filterType`: `FilterType.contains`
- `searchScope`: `SearchScope.both`
- `filterTerms`: `null` (no filter)

## Goals / Non-Goals

**Goals:**
- Provide a quick double-click action on topics in the Explorer sidebar to open/focus the topic tab and immediately start streaming with the default configuration (latest 200 messages).
- Keep single-click behavior unchanged (select/open topic without auto-starting stream).
- Ensure smooth UI feedback and tab synchronization during double-click streaming.

**Non-Goals:**
- Modifying custom search presets or changing default search parameter values.
- Auto-streaming on single click or from other views like Search or Consumer Lag.

## Decisions

### 1. Handling Double-Click in `TopicListItem`
- **Decision**: Add an `onDoubleTap` callback parameter to `TopicListItem`. Implement double-tap handling using `GestureDetector` or `InkResponse`/`InkWell` within `TopicListItem` without breaking existing `onTap` single-click handling or ripple animations.
- **Alternatives considered**:
  - *Replace `ListTile` entirely*: Unnecessary refactor; wrapping `ListTile` or setting `onDoubleTap` via `InkWell` preserves Material styling.

### 2. Centralized Execution via `ActiveConnectionController`
- **Decision**: Add a helper method `streamTopicWithDefaults(TopicMetadata topic, [ClusterProfile? profile])` in `ActiveConnectionController`.
  1. Opens or focuses the topic tab via `openTopic(topic: topic, profile: profile, forceNew: false)`.
  2. Resolves the tab's `MessageStreamController` via `getStreamController(record.id)`.
  3. Invokes `streamController.startStreaming(...)` with the standard default parameters (`maxResults: 200`, `startFromTail: true`, `filterType: FilterType.contains`, `searchScope: SearchScope.both`, `runForever: false`).
- **Rationale**: `ActiveConnectionController` manages tab records and stream controller lifecycles. Triggering the stream from the controller ensures that even if `TopicDetailView` is being mounted, the `MessageStreamController` begins listening immediately and updates reactive UI listeners.
- **Alternatives considered**:
  - *Pass a trigger flag into `TopicDetailView`*: More complex, requires prop drilling and state synchronization across widget rebuilds.

## Risks / Trade-offs

- **[Double-click conflict with single-click]** → In Flutter, `GestureDetector`/`InkWell` handles `onTap` and `onDoubleTap`. Single-click opens the tab; double-click opens and immediately streams. No unwanted side-effects since opening the tab is a prerequisite to streaming it.
