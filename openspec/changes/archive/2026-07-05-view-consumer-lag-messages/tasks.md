## 1. Backend Verification

- [x] 1.1 Confirm `consume_with_filter` in `rust/src/api/kafka_consumer.rs` supports `start_offset` and `max_results` (Verified: Yes).
- [x] 1.2 Verify `rdkafka` seek logic in `rust/kafkalyzer-kafka/src/kafka_consumer.rs` handles ad-hoc offset fetching correctly (Verified: Yes).

## 2. Flutter UI Implementation

- [x] 2.1 Modify `lib/src/features/consumer/presentation/topic_partition_table.dart` to add a "View Message" icon button to each row.
- [x] 2.2 Implement a new controller method or logic to fetch a single message for a given topic, partition, and offset.
- [x] 2.3 Integrate `MessageDetailsDialog` (from `lib/src/ui/message_details_dialog.dart`) to show the fetched message content.
- [x] 2.4 Add visual feedback (e.g., a small loading spinner) while the message is being fetched from the broker.

## 3. Verification & Polish

- [x] 3.1 Run `flutter analyze` to ensure no regressions in UI code.
- [x] 3.2 Verify the feature manually in the dev environment (or provide instructions for the user to do so).
- [x] 3.3 Verify graceful handling of "Offset Out of Range" if the current consumer offset is no longer available on the broker.
