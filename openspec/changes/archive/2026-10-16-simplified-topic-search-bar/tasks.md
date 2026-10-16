# Tasks

## 1. Localization & Scan Mode Model

- [x] 1.1 Add localization keys for scan mode presets, filter labels, tooltips, chips, and context-sensitive action buttons in `lib/l10n/app_en.arb`
- [x] 1.2 Add corresponding German translations in `lib/l10n/app_de.arb`
- [x] 1.3 Define `TopicScanMode` enum and strategy mapping utilities in `lib/src/features/search/models/topic_scan_mode.dart`

## 2. Compact Search Bar Component

- [x] 2.1 Create `TopicSearchBar` widget scaffold with responsive layout (`LayoutBuilder` / `Wrap`) in `lib/src/features/search/presentation/widgets/topic_search_bar.dart`
- [x] 2.2 Implement preset selector dropdown / segmented button for the 4 scan modes (`latestN`, `liveTail`, `timeRange`, `offsetEarliest`)
- [x] 2.3 Implement primary row controls: quick filter textfield, limit dropdown (50, 200, 500, 1000, All), and "Advanced" (`⚙️ Erweitert`) toggle
- [x] 2.4 Implement progressive disclosure drawer for advanced options: `Field` autocomplete, `FilterType` (Contains, Regex, Exact), `SearchScope` (Key, Value, Both), `Partition`, and `Fast Trace`
- [x] 2.5 Implement active filter chips displayed in the compact row when advanced options are collapsed
- [x] 2.6 Implement context-sensitive primary action button with dynamic labeling ("Fetch 200 Messages" vs "Start Live Stream" vs "Stop") and visual dirty-state highlight

## 3. Integration into `TopicDetailView`

- [x] 3.1 Replace the existing `ExpansionTile` and combinatorial start/end configuration in `lib/src/features/topic/topic_detail_view.dart` with `TopicSearchBar`
- [x] 3.2 Wire `TopicSearchBar` events to `MessageStreamController.startStreaming` and `stopStreaming`
- [x] 3.3 Implement search parameter snapshot tracking in `TopicDetailView` to trigger dirty-state indication when parameters change after messages have loaded
- [x] 3.4 Ensure clean backward compatibility with manual start/stop strategies when `offsetEarliest` or `timeRange` presets are selected

## 4. Testing & Verification

- [x] 4.1 Create widget tests for `TopicSearchBar` testing preset selection, progressive disclosure collapse/expand, active filter chips, and CTA button labeling in `test/src/features/search/presentation/widgets/topic_search_bar_test.dart`
- [x] 4.2 Run `flutter test` to verify all test suites pass
- [x] 4.3 Run `dart analyze` to ensure code adheres to linter and styling rules
