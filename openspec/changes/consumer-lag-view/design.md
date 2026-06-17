## Context

The system currently processes data via Kafka streams and topics. Administrators need a way to monitor the health of these consumers to identify bottlenecks or stuck processing, specifically by observing "consumer lag" - the difference between the latest message offset and the offset processed by the consumer group.

## Goals / Non-Goals

**Goals:**
- Provide a clear, real-time overview of all consumer groups in the Kafka cluster.
- Accurately calculate and display lag per topic and partition for each consumer group.
- Implement an efficient backend endpoint that interfaces with the Kafka Admin Client to fetch these metrics without overwhelming the cluster.
- Provide a responsive UI integrated into the existing Flutter/Dart frontend.

**Non-Goals:**
- Alerting or automated scaling based on consumer lag (this is just a monitoring view).
- Modifying consumer group states (e.g., resetting offsets or deleting groups) from the UI.

## Decisions

- **Kafka Client Strategy**: The Rust backend will use the `rdkafka` crate's AdminClient and Consumer capabilities to fetch group offsets and watermarks (log end offsets).
  *Rationale*: Direct integration with the existing Rust backend avoids adding new external dependencies like Prometheus or Burrow, keeping the deployment self-contained.
- **Frontend Integration**: A new Flutter page `ConsumerLagView` will be added to the navigation sidebar.
  *Rationale*: Fits naturally into the existing viewer application's architecture.
- **UI/UX Consistency**: The new screen must strictly adhere to the current UI design language of the application.
  *Rationale*: Ensures a seamless user experience. All components, typography, colors, and layout structures will reuse the existing design system and components.

## Risks / Trade-offs

- [Performance Impact on Kafka] Fetching watermarks for all partitions across many consumer groups can be expensive. → Mitigation: Cache the results in the backend for a short duration (e.g., 10-30 seconds) and limit the frequency of frontend polling or fetching.
- [Missing Inactive Consumers] Some clients might not show up if they have expired. → Mitigation: Clearly distinguish between active, empty, and dead consumer groups based on Kafka's group state.
