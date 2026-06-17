## 1. Backend API (Rust)

- [ ] 1.1 Add Rust struct definitions for `ConsumerGroup`, `TopicPartitionLag` in the API.
- [ ] 1.2 Implement a Kafka client utility to fetch all consumer groups using `rdkafka` AdminClient.
- [ ] 1.3 Implement a utility to fetch log end offsets (watermarks) for a given topic/partition.
- [ ] 1.4 Implement a utility to fetch committed offsets for a consumer group.
- [ ] 1.5 Create the main API endpoint (e.g. `GET /api/kafka/consumer-lags`) that coordinates fetching and computes the lag.
- [ ] 1.6 Add caching mechanism (e.g., using a short-lived memory cache) to prevent excessive load on Kafka.

## 2. Frontend UI (Dart/Flutter)

- [ ] 2.1 Create a new Flutter model class for `ConsumerGroupLag` matching the Rust API response.
- [ ] 2.2 Add an API service method in Dart to fetch the consumer lags from the backend.
- [ ] 2.3 Create `ConsumerLagView` widget that displays the overview of consumer groups (e.g., a data table or list).
- [ ] 2.4 Ensure the new view uses the existing UI components and strictly matches the current application design theme.
- [ ] 2.5 Add expandable rows or a detail view to show the specific lags per topic/partition for a selected consumer group.
- [ ] 2.6 Add a refresh button and/or auto-refresh capability to the `ConsumerLagView`.
- [ ] 2.7 Update the main sidebar navigation to include a link to the `ConsumerLagView`.

## 3. Integration & Testing

- [ ] 3.1 Verify the UI correctly queries the Rust backend and displays active and inactive consumers.
- [ ] 3.2 Test the performance when loading watermarks from multiple partitions.
- [ ] 3.3 Add unit tests in Rust for the lag calculation logic.
