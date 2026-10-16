# Proposal: Explorer Onboarding and Auto-Preview

## Why

In `v1.5.0`, new or occasional users face significant cognitive friction and "dead-end" states when launching Kafkalyzer:
1. **Passive Cold Start:** When Kafkalyzer starts without an active cluster connection, roughly 85% of the screen is empty, displaying only a faint `Icons.hub_outlined` and static text (`selectClusterToViewTopics`). The cluster list on the left appears static without status badges or quick connect actions, and there is no direct prompt to configure a new cluster.
2. **Empty Cluster State:** After selecting a cluster, the main content area remains blank with a bare English string `"Select a topic from the sidebar to start"`. There is no summary of cluster health, topic count, or quick links to recently examined topics.
3. **Dead-End Topic Open (No Messages Loaded):** A single click on a topic opens a tab but displays an intimidating configuration header alongside an unhelpful message `"No messages to display"`. Users are often unaware that messages must be explicitly triggered (via the top-right stream button or double-clicking the topic in the sidebar).

Introducing guided onboarding cards, an active cluster dashboard, and an actionable empty state with a 1-click message fetch will drastically reduce time-to-first-message and eliminate confusing dead-end views.

## What Changes

1. **Interactive Cluster Selection Empty State (`ExplorerView`):**
   - Replace the passive `_buildNoClusterSelected` placeholder with an interactive onboarding dashboard.
   - Display selectable cluster cards for all configured profiles showing name, bootstrap host, security protocol badge (`PLAINTEXT`, `SSL`, `SASL_SSL`), and a primary "Connect" button.
   - Provide a prominent `[+ Cluster hinzufügen]` / `[+ Add Cluster]` action that guides users to create or import a cluster profile.
   - Show a "Recently Viewed Topics" list across recent sessions to allow 1-click resumption of inspection.

2. **Cluster Overview Empty State (`ExplorerView`):**
   - When a cluster is actively selected but no topic tabs are open (`openTopics.isEmpty`), display an informative cluster overview instead of a static `"Select a topic..."` label.
   - Render cluster statistics: total topic count, partition totals (if loaded), and Schema Registry integration status.
   - Display a quick-access list of the most recently inspected topics for this cluster, plus a search shortcut.

3. **Actionable Empty State in Topic Messages View (`MessagesView` & `TopicDetailView`):**
   - When a topic tab is open with 0 messages loaded and message streaming is inactive, replace `"No messages to display"` with an actionable onboarding card:
     - Title: *"Noch keine Nachrichten geladen"* / *"No messages loaded yet"*.
     - Descriptive guidance explaining that latest messages can be loaded immediately or search parameters adjusted.
     - Primary Action Button: `[ ► Letzte 200 Nachrichten jetzt abrufen ]` / `[ ► Fetch latest 200 messages ]` that immediately triggers streaming with current/default parameters.
     - Secondary helper tip informing users that double-clicking a topic in the sidebar starts fetching immediately.

## Capabilities

### New Capabilities
- `explorer-onboarding`: Covers interactive onboarding dashboards for initial cluster selection, active cluster overview when no topic tabs are open, and actionable empty states with quick-fetch triggers in topic detail and message views.

### Modified Capabilities
<!-- No requirement changes to existing specs. Existing capabilities retain their contracts. -->

## Impact

- **Affected Files:**
  - `lib/src/features/explorer/presentation/explorer_view.dart`: Replace `_buildNoClusterSelected` and `_buildNoTopicSelected` with onboarding and cluster overview widgets.
  - `lib/src/ui/messages/messages_view.dart`: Update empty state rendering when `messages.isEmpty` to accept or display an actionable CTA.
  - `lib/src/features/topic/topic_detail_view.dart`: Wire the primary fetch action callback from `MessagesView` to `startStreaming()`.
  - `lib/l10n/app_en.arb` & `lib/l10n/app_de.arb`: Add localized strings for cluster cards, empty state headings, CTA buttons, and helpful tips.
- **Dependencies & State:**
  - Uses `ClusterListController` and `ActiveConnectionController` for profile data and cluster connection triggers.
  - Uses `SharedPreferences` (or existing recent topic tracking) to store and load recent topic history.
  - No breaking changes to Rust backend or bridge APIs.
