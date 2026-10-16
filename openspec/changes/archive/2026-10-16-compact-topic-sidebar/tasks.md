# Tasks

## 1. Localization & String Assets

- [x] 1.1 Add localized strings for internal topics filter chip and Kafka stream topics filter chip in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.
- [x] 1.2 Add localized tooltip template strings (partitions, replication factor, retention, cleanup policy) in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.
- [x] 1.3 Run `flutter gen-l10n` to regenerate `AppLocalizations`.

## 2. High-Density `TopicListItem` Component

- [x] 2.1 Implement `parseTopicNameSegments` helper function to extract dot-separated prefix and terminal leaf name.
- [x] 2.2 Refactor `TopicListItem` title layout using `Text.rich` to render the namespace prefix in dimmed secondary text and the leaf name in bold primary text.
- [x] 2.3 Update metadata badges to render compact micro-badges (`<N>P` and `Avro`) and remove `RF`, `cleanup.policy`, `retention.ms`, and inline Schema button from the card face.
- [x] 2.4 Add desktop-responsive `Tooltip` (`waitDuration: 350ms`) to `TopicListItem` containing full broker configuration details.
- [x] 2.5 Adjust card margins, content padding, and visual density to achieve a compact item height of ~44–48px while maintaining single-click, double-click, and "open in new tab" actions.

## 3. Compact Filter Controls in `ExplorerView`

- [x] 3.1 Refactor `_buildSidebarTopicFilter` in `lib/src/features/explorer/presentation/explorer_view.dart` to replace vertical `Switch` rows with compact `FilterChip` widgets.
- [x] 3.2 Connect filter chips to `activeController.toggleShowInternalTopics` and `activeController.toggleShowStreamTopics`.
- [x] 3.3 Ensure visual active state (selected checkmark and tonal container styling) aligns with Material 3 styling.

## 4. Testing & Verification

- [x] 4.1 Update and expand `test/src/features/topic/presentation/widgets/topic_list_item_test.dart` to verify hierarchical name formatting, micro-badge rendering, and metadata tooltip generation.
- [x] 4.2 Update `test/src/features/explorer/presentation/explorer_view_test.dart` to verify compact filter chip rendering and topic list filtering behavior.
- [x] 4.3 Run `flutter test` and `dart analyze lib test` to ensure zero regressions and clean static analysis.
