# Tasks

## 1. Localization & String Resources

- [x] 1.1 Add localized strings for the partition health dialog title and header tooltips in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, and verify with `flutter gen-l10n`.

## 2. Compact Schema Provenance in Message Cards

- [x] 2.1 Refactor `MessageMetadataCard` in `lib/src/ui/messages/widgets/message_metadata_card.dart` to remove verbose multi-line schema text and negative placeholders (`schemaNone`), replacing them with a compact inline schema indicator (e.g. `#<schemaId>` or `v<version>`).
- [x] 2.2 Update unit and widget tests in `test/src/ui/messages/widgets/message_metadata_card_test.dart` to verify compact schema rendering and absence of negative placeholders, running `flutter test test/src/ui/messages/widgets/message_metadata_card_test.dart`.

## 3. Partition Health Header Integration & Dialog

- [x] 3.1 Create `TopicPartitionHealthDialog` in `lib/src/features/topic/presentation/widgets/topic_partition_health_dialog.dart` to display partition replication breakdown, broker resolution, and refresh action in a Material 3 dialog.
- [x] 3.2 Update `TopicDetailView` in `lib/src/features/topic/topic_detail_view.dart` to remove the static inline `TopicPartitionHealthTable` banner from the messages view, and wire header partition tags and health warning tags to open `TopicPartitionHealthDialog` on tap.
- [x] 3.3 Update tests in `test/src/features/topic/topic_detail_view_test.dart` to verify the inline banner is removed and opening the dialog from the header works, running `flutter test test/src/features/topic/topic_detail_view_test.dart`.

## 4. Partition Health Integration in Topic Analysis

- [x] 4.1 Embed partition health and replication status into `TopicAnalysisView` in `lib/src/features/topic/presentation/widgets/analysis/topic_analysis_view.dart` alongside `PartitionBalanceView`.
- [x] 4.2 Update tests in `test/src/features/topic/presentation/widgets/analysis/topic_analysis_view_test.dart` to verify partition health displays within the analysis tab, running `flutter test test/src/features/topic/presentation/widgets/analysis/topic_analysis_view_test.dart`.

## 5. Verification & Code Formatting

- [x] 5.1 Format all modified Dart files using `dart format` and verify there are no analysis errors using `dart analyze`.
- [x] 5.2 Run the full test suite (`flutter test`) to ensure all regressions and integrations pass cleanly.
