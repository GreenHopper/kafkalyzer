# Tasks

## 1. Localization & Model Setup

- [x] 1.1 Define localized labels and tooltips in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` for filtering duplicate occurrences (`filterDuplicatesInMessages`) and jumping to sample offset (`jumpToSampleOffset`), then verify generation with `flutter gen-l10n`.
- [x] 1.2 Create `DuplicateNavigationTarget` model under `lib/src/features/topic/models/duplicate_navigation_target.dart` encapsulating key, payload preview, count, scope, sample partition, sample offset, and navigation mode (`filterOccurrences`), and verify unit test passes.

## 2. Duplicate Inspection Views & Dialog Integration

- [x] 2.1 Update `DuplicateDetailsDialog` to provide the primary action button to filter duplicate occurrences across the topic, and a secondary action to jump directly to the sample offset coordinates. Verify in `test/src/features/topic/presentation/widgets/analysis/duplicate_details_dialog_test.dart`.
- [x] 2.2 Update `DuplicateAnalysisView` and `TopicAnalysisView` navigation callbacks to accept `DuplicateNavigationTarget` and forward it upwards. Verify existing duplicate analysis widget tests pass.

## 3. Topic Detail View Navigation & Search Bar Pre-population

- [x] 3.1 Implement `_handleDuplicateNavigation(DuplicateNavigationTarget target)` in `TopicDetailView`:
  - When `target.filterOccurrences` is true: populate `_filterController.text` with key or payload preview excerpt, set `_searchScope` (`key` vs `value`), set `_filterType` (`exact` vs `contains`), clear `_partitionController`, set `_scanMode = TopicScanMode.offsetEarliest`, set `_startStrategy = MultiSearchStartStrategy.earliest`, update `_offsetController.text = '0'`, ensure `_maxResultsController` is at least the duplicate count, and trigger `startStreaming()`.
  - When `target.filterOccurrences` is false: populate `_partitionController` and `_offsetController` with sample coordinates, set `_scanMode = TopicScanMode.offsetEarliest`, set `_startStrategy = MultiSearchStartStrategy.customOffset`, and trigger `startStreaming()`.
- [x] 3.2 Write and execute widget tests in `test/src/features/topic/topic_detail_view_duplicate_navigation_test.dart` asserting that clicking duplicate navigation sets the correct search bar fields, scan mode, and partition criteria.

## 4. Verification & Quality Assurance

- [x] 4.1 Run full project test suite (`flutter test`) and verify all tests pass.
- [x] 4.2 Run `dart format --output=none --set-exit-if-changed .` and `flutter analyze` to ensure code formatting and linting pass with zero warnings.

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Sync delta specs to main specs.
