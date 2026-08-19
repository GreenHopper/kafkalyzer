# Tasks: Multiple Topic Search Tabs

## 1. State Management & Data Model

- [x] 1.1 Refactor `OpenTopicRecord` in `active_connection_controller.dart` to include a unique `id` (tab ID) field.
- [x] 1.2 Update `ActiveConnectionController` to key `_streamControllers` and active tab selection by unique tab ID.
- [x] 1.3 Add `openTopic({required TopicMetadata topic, ClusterProfile? profile, bool forceNew = false})` to support both selecting existing tabs and opening new tab instances.
- [x] 1.4 Add `closeTopicTab(String tabId)` to cancel and dispose only the closed tab's `MessageStreamController` and properly manage active tab fallback.

## 2. Localization

- [x] 2.1 Add localization entries for opening new tabs (e.g., `openInNewTab`, `duplicateTab`) in `lib/l10n/app_en.arb`.
- [x] 2.2 Add German translations in `lib/l10n/app_de.arb`.
- [x] 2.3 Run flutter localization generation to update `AppLocalizations`.

## 3. UI Presentation & Tab Management

- [x] 3.1 Update `TopicListItem` in `topic_list_item.dart` to provide an "Open in New Tab" context menu or action button.
- [x] 3.2 Update `_buildTabBar` in `explorer_view.dart` to compute and display disambiguated tab titles (e.g., `topic (1)`, `topic (2)`) when multiple tabs are open for the same topic.
- [x] 3.3 Add tab context action (e.g., duplicate / new tab) to tab items in `ExplorerView`.
- [x] 3.4 Update `_buildTabViews` in `explorer_view.dart` to pass unique tab identifiers to `TopicDetailView` keyed by `ValueKey(record.id)`.
- [x] 3.5 Update `TopicDetailView` in `topic_detail_view.dart` to consume the tab-specific `MessageStreamController` using the unique tab ID.

## 4. Testing & Verification

- [x] 4.1 Write unit tests in `test/features/cluster/active_connection_controller_test.dart` verifying multiple tab instances, stream controller isolation, and closing tabs.
- [x] 4.2 Write widget tests for `ExplorerView` verifying multi-tab rendering, instance numbering, switching active tabs, and tab closure.
- [x] 4.3 Run `dart analyze` and `flutter test` to ensure all tests pass and formatting conforms to rules.
