# Tasks: Explorer Onboarding and Auto-Preview

## 1. Data Models and Services

- [x] 1.1 Create `RecentTopicEntry` data model and `RecentTopicsService` with `SharedPreferences` persistence and LRU history capping.
- [x] 1.2 Register `RecentTopicsService` in `lib/src/dependency_injection.dart`.
- [x] 1.3 Update `ActiveConnectionController` to record topic visits in `RecentTopicsService` whenever a topic tab is opened or streamed.

## 2. Localization

- [x] 2.1 Add localization keys in `lib/l10n/app_en.arb` for onboarding titles, cluster card buttons, cluster overview statistics, actionable empty state CTA, and helper tips.
- [x] 2.2 Add German translations for all new keys in `lib/l10n/app_de.arb`.

## 3. Actionable Topic Empty State in Messages View

- [x] 3.1 Create `ActionableTopicEmptyState` widget (`lib/src/ui/messages/widgets/actionable_topic_empty_state.dart`) with primary fetch button (`[ ► Letzte 200 Nachrichten jetzt abrufen ]`) and double-click tip.
- [x] 3.2 Update `MessagesView` in `lib/src/ui/messages/messages_view.dart` to accept `onFetchLatest` and `isStreaming`, displaying `ActionableTopicEmptyState` when `messages.isEmpty` and consumption is not active.
- [x] 3.3 Pass `onFetchLatest: startStreaming` and `isStreaming: streamController.isStreaming` from `TopicDetailView` in `lib/src/features/topic/topic_detail_view.dart`.

## 4. Explorer Onboarding and Cluster Overview Views

- [x] 4.1 Create `ExplorerOnboardingView` widget in `lib/src/features/explorer/presentation/widgets/explorer_onboarding_view.dart` with interactive cluster cards, connect actions, add cluster button, and recent topics.
- [x] 4.2 Create `ClusterOverviewView` widget in `lib/src/features/explorer/presentation/widgets/cluster_overview_view.dart` displaying topic counts, Schema Registry status, and cluster-scoped recent topics.
- [x] 4.3 Update `ExplorerView` in `lib/src/features/explorer/presentation/explorer_view.dart` to replace `_buildNoClusterSelected` with `ExplorerOnboardingView` and `_buildNoTopicSelected` with `ClusterOverviewView`.

## 5. Verification and Testing

- [x] 5.1 Add unit tests for `RecentTopicsService` verifying persistence, duplicate handling, and LRU capping.
- [x] 5.2 Add widget tests for `ActionableTopicEmptyState`, `ExplorerOnboardingView`, and `ClusterOverviewView`.
- [x] 5.3 Run `flutter test` and `dart analyze` to verify code quality, formatting, and test execution.
