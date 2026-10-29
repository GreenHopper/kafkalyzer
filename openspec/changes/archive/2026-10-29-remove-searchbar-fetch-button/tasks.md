# Tasks

## 1. UI Refactoring

- [x] 1.1 Remove `_buildActionButton` and its trailing spacing from both wide and narrow responsive layout rows in `TopicSearchBar` (`lib/src/features/search/presentation/widgets/topic_search_bar.dart`), preserving `onSubmitted` in the quick filter field to trigger `_onStart()`. Verify the search bar renders with the advanced filter toggle as the trailing element.
- [x] 1.2 Remove obsolete `isStreaming`, `isDirty`, and `onStop` parameters from `TopicSearchBar` and update its call site in `TopicDetailView` (`lib/src/features/topic/topic_detail_view.dart`). Verify that `TopicDetailView` continues to trigger streaming exclusively through the header `TopicProgressTile` action buttons.
- [x] 1.3 Run `dart analyze lib/` and verify that there are no compilation errors or unused member warnings in the modified files.

## 2. Test Updates & Verification

- [x] 2.1 Update `test/src/features/search/presentation/widgets/topic_search_bar_test.dart` by removing assertions for `search_bar_start_button` and `search_bar_stop_button`, and updating test cases to verify filter execution via keyboard submit (`TextInputAction.done`) on the search field.
- [x] 2.2 Run `flutter test test/src/features/search/presentation/widgets/topic_search_bar_test.dart` and `flutter test test/src/features/topic/topic_detail_view_test.dart` and verify all tests pass.
- [x] 2.3 Run full test suite via `flutter test` to confirm no regressions across other feature areas.
