## 1. UI Parameter Extension
- [x] 1.1 Add `previousLags` property to `GroupDetailsView` widget class and pass it from `consumer_lag_view.dart`.
- [x] 1.2 Add `previousLags` property to `TopicPartitionTable` widget class and pass it from `group_details_view.dart`.

## 2. Topic Header Delta Badges
- [x] 2.1 Implement `_calculateTopicDelta` in `_GroupDetailsViewState`.
- [x] 2.2 Implement `_buildTopicDeltaWidget` in `_GroupDetailsViewState` matching color and sign rules.
- [x] 2.3 Add the topic delta widget to the `ExpansionTile`'s trailing section.

## 3. Partition Table Processed Column
- [x] 3.1 Increase `TopicPartitionTable` layout to 5 columns and add "Abarbeitung" / "Processed" header cell.
- [x] 3.2 Add the localized and color-coded delta cell to each row of the table.
- [x] 3.3 Implement sorting logic in `TopicPartitionTable` for the new Abarbeitung column (column index 4).

## 4. Verification & Testing
- [x] 4.1 Update widget tests in `consumer_lag_view_test.dart` to verify that topic deltas and partition deltas are calculated and displayed correctly.
- [x] 4.2 Verify that clicking the new partition column sorts partition rows by delta correctly.
