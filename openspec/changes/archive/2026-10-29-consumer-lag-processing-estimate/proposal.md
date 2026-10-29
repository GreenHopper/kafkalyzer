# Proposal

## Why

When monitoring Kafka consumer groups with significant message lag, operators currently see absolute lag numbers, recent sparkline trends, and discrete offset deltas between refreshes ("Abarbeitung" / "Processed"). However, raw delta numbers alone do not tell operators when a lagging group will finish catching up, how fast it is processing messages relative to elapsed time, or whether the backlog is actively shrinking or growing under current producer throughput.

Introducing an automated processing estimate (processing throughput rate and estimated time to clear backlog / ETA) gives operators immediate operational visibility into whether a consumer group is resolving its backlog, how long recovery will take, or whether immediate scaling/intervention is necessary.

## What Changes

- **Timestamped Lag Tracking & Rate Computation**:
  - Record the timestamp of lag query snapshots alongside retained lag readings per consumer group and partition.
  - Calculate consumption and net lag drain throughput rates (messages per second) across elapsed time between refreshes.
  - Compute the estimated time to clear backlog ($\text{ETA} = \text{Current Lag} / \text{Drain Rate}$) when a consumer is actively draining lag.
  - Gracefully handle edge cases: zero lag (caught up), accumulating lag (growing backlog), zero consumption with pending lag (stalled / idle), and single-sample states (awaiting second reading).

- **Consumer Lag View UI Integration**:
  - Enhance the "Abarbeitung" / "Processed" column and badge in the main consumer group list to display processing throughput and the time estimate (e.g. `~3m 15s` or `120 msg/s • ~3m`) with clear status-based visual styling.
  - Provide an informative tooltip on the processing estimate breaking down current rate, net change, elapsed interval, and backlog recovery status.
  - Add processing rate and backlog recovery indications to topic and partition rows in `GroupDetailsView` and `TopicPartitionTable`.
  - Optionally enhance the "Total Lag" KPI card with aggregate processing throughput and overall backlog drain estimate.

- **Localization & Accessibility**:
  - Add localized strings for English and German in `.arb` files for throughput rates (e.g. `msg/s`), ETA representations (`~2m 45s`, `< 1m`, `> 24h`), and status descriptions (e.g. "Caught up", "Backlog growing", "Stalled", "Estimating...").

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- `consumer-lag-monitoring`: Add requirements for calculating and displaying consumer group processing rates and backlog completion time estimates (ETA) based on elapsed time between lag samples.

## Impact

- **Frontend (Dart/Flutter)**:
  - `consumer_lag_view.dart`: Track query completion timestamps, compute drain rates and backlog clearance estimates, update column formatting and tooltips, and update aggregate KPI card.
  - `group_details_view.dart` & `topic_partition_table.dart`: Display partition and topic-level processing rates and estimates.
  - `group_delta_badge.dart` / new estimate widget: Support displaying rate and ETA formatting with appropriate color coding.
  - `app_en.arb` and `app_de.arb`: Localized formatting templates for processing rates, duration estimates, and status labels.
  - `consumer_lag_view_test.dart` and widget tests: Add tests verifying rate calculation, ETA formatting, edge case states, and localized presentation.
- **Backend / Bridge**:
  - No changes required in Rust or flutter_rust_bridge; all required offset, lag, and timestamp data are captured and computed within the client application session.
