# Design: Explorer Onboarding and Auto-Preview

## Context

In Kafkalyzer `v1.5.0`, the `ExplorerView` serves as the primary workspace for Kafka topic exploration. However, several interaction states present blank or unhelpful views:
- When no cluster profile is connected, `_buildNoClusterSelected` displays a bare icon with `selectClusterToViewTopics`. The user must know to inspect the narrow sidebar to find clusters.
- When a cluster is connected but no topic tabs are open, `_buildNoTopicSelected` shows `"Select a topic from the sidebar to start"`.
- In `MessagesView`, when a topic tab is opened via a single click on a sidebar item, `messages.isEmpty` renders `Center(child: Text("No messages to display"))`. The user must either know that double-clicking the topic starts consumption or find the remote stream action.

This design introduces rich, interactive onboarding views for all three states, along with a recent topics history service.

## Goals / Non-Goals

**Goals:**
- Provide an interactive, actionable dashboard when no cluster profile is selected, displaying configured cluster cards with direct "Connect" actions, a quick button to add a cluster, and recently viewed topics.
- Provide an informative cluster overview when a cluster is connected but no topic tabs are open, displaying cluster metrics (total topic count, Schema Registry status) and fast-launch cards for recently viewed topics on that cluster.
- Replace the passive `"No messages to display"` in `MessagesView` with a contextual, actionable empty state card featuring a prominent `[ ► Letzte 200 Nachrichten jetzt abrufen ]` / `[ ► Fetch latest 200 messages ]` CTA button.
- Maintain a local history of recently visited topics (persisted via `shared_preferences`) with cluster association for fast 1-click re-opening.
- Ensure all new text, labels, tooltips, and buttons are fully localized in English and German via `AppLocalizations`.

**Non-Goals:**
- Modifying Kafka consumption protocols or Rust backend streaming logic (existing `streamTopicWithDefaults` and `startStreaming` APIs are utilized).
- Changing the compact scan presets or filter mechanics introduced in `simplified-topic-search-bar`.
- Replacing sidebar navigation; onboarding cards act as complementary accelerators in the empty main canvas.

## Decisions

### 1. Dedicated Modular Onboarding Widgets
Instead of bloating `ExplorerView` with monolithic inline builders, we introduce focused widgets in `lib/src/features/explorer/presentation/widgets/`:
- `ExplorerOnboardingView`: Renders the welcome dashboard with cluster cards, add cluster action, and global recent topics.
- `ClusterOverviewView`: Renders active cluster summary cards (topic count, schema registry status) and cluster-scoped recent topics.
- `ActionableTopicEmptyState`: Renders the topic message empty card with primary fetch button and double-click tip.

*Rationale:* Keeps `ExplorerView` clean and declarative, facilitates independent widget testing, and adheres to single-responsibility principles.

### 2. Recent Topics Persistence Service
Create `RecentTopicsService` registered in `getIt` backed by `SharedPreferences`.
- Data structure: `List<RecentTopicEntry>` stored as JSON array, where each entry contains `topicName`, `clusterName`, and `lastVisited` timestamp.
- Capped to the 10 most recent entries (LRU).
- Exposes methods: `Future<void> recordVisit(String clusterName, String topicName)`, `List<RecentTopicEntry> getRecentTopics({String? clusterName})`, and `Future<void> clearHistory()`.
- Automatically called when a topic tab is opened in `ActiveConnectionController`.

*Alternative Considered:* In-memory only history.
*Why Rejected:* Users frequently close and reopen the desktop app; persisting recent topics across sessions provides high value for daily Kafka triage.

### 3. Actionable Empty State Integration in `MessagesView` and `TopicDetailView`
`MessagesView` already receives `messages`. We extend `MessagesView` with:
- `final VoidCallback? onFetchLatest;`
- `final bool isStreaming;`
When `messages.isEmpty`:
- If `isStreaming` is `true`: Render an inline loading indicator with status text (`l10n.loadingMessages` or scan progress) instead of empty text.
- If `isStreaming` is `false`:
  - If `onFetchLatest != null`: Render `ActionableTopicEmptyState` with the primary `[ ► Letzte 200 Nachrichten jetzt abrufen ]` button and tip.
  - If `onFetchLatest == null`: Fall back to localized empty text.

In `TopicDetailView`, pass `onFetchLatest: startStreaming` and `isStreaming: streamController.isStreaming` into `MessagesView`.

*Rationale:* Minimizes changes to the core `MessagesView` while providing seamless wiring to the topic's stream controller.

### 4. Direct Connect & Navigation Flow
- Clicking a cluster card in `ExplorerOnboardingView` calls `activeController.selectProfile(cluster)`.
- Clicking `[+ Cluster hinzufügen]` / `[+ Add Cluster]` invokes `ClusterConfigDialog` or triggers navigation to settings.
- Clicking a recent topic item:
  - If connected to that cluster, directly opens/focuses the topic tab via `activeController.openTopic(topic: topic, profile: cluster)`.
  - If connected to a different cluster or disconnected, connects to the cluster first and then opens the topic tab.

## Risks / Trade-offs

- **Recent Topic Exists in History but Deleted from Kafka Broker:**
  - *Mitigation:* When clicking a recent topic, if the topic is not found in the cluster metadata, display an error SnackBar ("Topic no longer exists on this cluster") and allow removing it from recent history.
- **Visual Flash while Connecting:**
  - *Mitigation:* If `activeController.isConnecting` is `true`, render a smooth loading shimmer or spinner rather than jarring layout shifts between onboarding and cluster views.
