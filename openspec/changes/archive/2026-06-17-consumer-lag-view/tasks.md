## 1. Backend API (Rust)

- [x] 1.1 Add Rust struct definitions for `ConsumerGroup`, `TopicPartitionLag` in the API.
- [x] 1.2 Implement a Kafka client utility to fetch all consumer groups using `rdkafka` AdminClient.
- [x] 1.3 Implement a utility to fetch log end offsets (watermarks) for a given topic/partition.
- [x] 1.4 Implement a utility to fetch committed offsets for a consumer group.
- [x] 1.5 Create the main API endpoint (e.g. `GET /api/kafka/consumer-lags`) that coordinates fetching and computes the lag.
- [x] 1.6 Add caching mechanism (e.g., using a short-lived memory cache) to prevent excessive load on Kafka.
- [x] 1.7 Implement `fetch_consumer_groups` to retrieve group headers immediately without querying offsets/watermarks.
- [x] 1.8 Implement `fetch_consumer_group_lag` to query offsets and calculate watermarks for a single specified group on demand.


## 2. Frontend UI (Dart/Flutter)

- [x] 2.1 Create a new Flutter model class for `ConsumerGroupLag` matching the Rust API response.
- [x] 2.2 Add an API service method in Dart to fetch the consumer lags from the backend.
- [x] 2.3 Create `ConsumerLagView` widget that displays the overview of consumer groups (e.g., a data table or list).
- [x] 2.4 Ensure the new view uses the existing UI components and strictly matches the current application design theme.
- [x] 2.5 Add expandable rows or a detail view to show the specific lags per topic/partition for a selected consumer group.
- [x] 2.6 Add a refresh button and/or auto-refresh capability to the `ConsumerLagView`.
- [x] 2.7 Update the main sidebar navigation to include a link to the `ConsumerLagView`.
- [x] 2.8 Add sorting dropdown (Name A-Z, Name Z-A, Lag Descending, Lag Ascending) and client-side sorting logic.
- [x] 2.9 Track load duration and group counts, rendering a success banner showing fetch stats.
- [x] 2.10 Implement post-frame callbacks to trigger single-group lag loading lazily when tiles are rendered on-screen, displaying loading spinners while unresolved.

## 3. Integration & Testing

- [x] 3.1 Verify the UI correctly queries the Rust backend and displays active and inactive consumers.
- [x] 3.2 Test the performance when loading watermarks from multiple partitions.
- [x] 3.3 Add unit tests in Rust for the lag calculation logic.
- [x] 3.4 Add widget tests for the sorting, loading stats, and lazy-loading behavior.
