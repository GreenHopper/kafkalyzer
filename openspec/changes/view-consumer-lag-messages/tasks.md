## 1. Backend Verification

- [ ] 1.1 Confirm `consume_with_filter` in `rust/src/api/kafka_consumer.rs` supports `start_offset` and `max_results` (Verified: Yes).
- [ ] 1.2 Verify `rdkafka` seek logic in `rust/kafkalyzer-kafka/src/kafka_consumer.rs` handles ad-hoc offset fetching correctly (Verified: Yes).

## 2. Flutter UI Implementation

- [ ] 2.1 Modify `lib/src/features/consumer/presentation/topic_partition_table.dart` to add a "View Message" icon button to each row.
- [ ] 2.2 Implement a new controller method or logic to fetch a single message for a given topic, partition, and offset.
- [ ] 2.3 Integrate `MessageDetailsDialog` (from `lib/src/ui/message_details_dialog.dart`) to show the fetched message content.
- [ ] 2.4 Add visual feedback (e.g., a small loading spinner) while the message is being fetched from the broker.

## 3. Verification & Polish

- [ ] 3.1 Test with a live Kafka cluster: Navigate to Consumer Lag, expand a group, and click "View Message" on a lagging partition.
- [ ] 3.2 Ensure the message inspector correctly displays key, payload, and headers for the lagging message.
- [ ] 3.3 Verify graceful handling of "Offset Out of Range" if the current consumer offset is no longer available on the broker.
