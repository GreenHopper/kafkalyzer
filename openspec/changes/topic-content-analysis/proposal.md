<!-- markdownlint-disable MD041 -->
## Why

Kafka operators and developers often need a deep, holistic understanding of the data in a topic beyond simply paginating through individual messages. Currently, determining exact topic message volume, diagnosing partition skew, detecting production peak hours, counting tombstones on compacted topics, and analyzing key/value payload distribution requires running custom external consumer scripts or complex command-line pipelines.

Introducing a built-in Topic Content Analysis feature allows users to inspect and profile the contents of any topic directly within Kafkalyzer, providing rapid analytical insights with visual dashboards and summary metrics.

## What Changes

- **Topic Content Analysis Engine (Rust & Dart)**: Add high-throughput native partition scanning and aggregation to compute topic metrics:
  - Total message counts (actual messages present across partitions).
  - Production timeline / peak hour distribution (hourly histogram 00:00–23:00 based on message timestamps).
  - Partition utilization and balance analysis (message counts and percentages per partition, identifying hot partitions and skew).
  - Tombstone detection and counting (messages with null/empty payload, highlighted especially when topic cleanup policy includes `compact`).
  - Key frequency analysis (top message keys, unique key counts, null key ratio).
  - Value structure & field distribution (schema detection, JSON field occurrence, top values for key fields, payload size statistics: min, max, avg).
- **Topic Analysis UI in Explorer / Topic Detail**:
  - Add an "Analysis" tab/mode in `TopicDetailView` alongside the message stream view.
  - Provide configurable scan controls (full scan from earliest to latest, sampling options, time ranges).
  - Render a visual dashboard with metric summary cards, partition distribution charts/bars, hourly peak production histograms, key frequency tables, and field value breakdowns.
  - Display progress indicators and allow cancellation during long-running topic scans.
- **Localization**: Add localized strings for all analysis labels, tooltips, chart legends, and metric descriptions across supported languages (`app_en.arb`, `app_de.arb`).

## Capabilities

### New Capabilities

- `topic-content-analysis`: Provides comprehensive topic content profiling and statistical analysis including message counts, hourly peak production distribution, partition balance, tombstone counts for compacted topics, key frequencies, and structured value field distributions.

### Modified Capabilities
<!-- None -->

## Impact

- **Backend (Rust)**: New analysis scanner API and aggregation data structures in `rust/kafkalyzer-kafka` and `rust/src/api/` exposed via `flutter_rust_bridge`.
- **Frontend (Flutter)**:
  - New analysis controller (`TopicAnalysisController`) registered in DI (`get_it`).
  - New analysis presentation widgets in `lib/src/features/topic/presentation/` (summary cards, partition balance view, hourly production chart, key & field distribution tables).
  - Updated `TopicDetailView` to toggle between Message Stream and Content Analysis views.
- **Dependencies**: Potential addition of a lightweight charting package (or custom responsive painter/bar widgets) for visualizing hourly distributions and partition balances.
- **Localization**: Updates to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.
