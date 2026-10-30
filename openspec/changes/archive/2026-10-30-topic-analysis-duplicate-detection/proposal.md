# Proposal: Topic Analysis Duplicate Message Detection

## Why

In event-driven architectures with Apache Kafka, producer retries, network glitches, or missing producer idempotence frequently cause duplicate message publishing. Currently, Kafkalyzer scans all retained or sampled messages for sizes, timestamps, and keys, but users cannot easily determine whether messages were published multiple times without manually querying or exporting data.

Adding duplicate message detection directly into the topic analysis pipeline allows users to evaluate message redundancy, quantify duplicate rates, and identify the most frequently re-published messages without extra scan passes or external tools.

## What Changes

- **Configurable Duplicate Scope**: Users can choose before running a scan whether duplicates are identified by message payload (Value) only (default) or by Key + Payload combination.
- **Memory-Efficient Duplicate Tracking**: The native Rust analyzer accumulates 64-bit or 128-bit cryptographic / collision-resistant hashes of message contents across all scanned messages, bounding memory usage even for millions of records.
- **Deduplication Summary Metrics**: The analysis report surfaces total unique messages, total duplicate messages, and the duplicate rate (percentage of messages that are duplicates).
- **Top Duplicated Messages Explorer**: An interactive table or card list ranking the top duplicated messages (up to 20), displaying their key, payload preview, occurrence count, percentage share, and sample locations (partition, offset, timestamp).
- **Report Export & Import Compatibility**: Persists duplicate analysis results in exported report files and gracefully displays older imported reports without duplicate data as unavailable.
- **Localization**: Localizes all new UI labels, summary cards, tooltips, and configuration toggles in English and German.

## Capabilities

### New Capabilities

- `topic-duplicate-detection`: Scans messages for duplicates based on configurable equality criteria (Payload only vs. Key + Payload), calculates unique and duplicate metrics, and surfaces top duplicated messages with occurrence details.

### Modified Capabilities

- `topic-analysis-export-import`: Extends portable report serialization to include duplicate detection configuration and metrics, ensuring backwards compatibility when importing older report files.

## Impact

- **Rust Workspace**:
  - `rust/kafkalyzer-core`: New types (`DuplicateDetectionScope`, `DuplicateAnalysisResult`, `TopDuplicateOccurrence`) in `kafka_types.rs`.
  - `rust/kafkalyzer-kafka`: Hash-based duplicate tracking in `AnalyzerAccumulator` in `kafka_analyzer.rs`, configurable via `TopicAnalysisOptions`.
  - `rust/src/api`: Exposed via `flutter_rust_bridge` to Dart.
- **Flutter / Dart UI**:
  - `TopicAnalysisOptions` updated in UI and controller to support duplicate detection scope.
  - New summary card in `TopicAnalysisSummaryCards` showing duplicate count and rate.
  - New expandable section / card or tab `DuplicateAnalysisSection` showing top duplicated messages with payload preview and partition/offset details.
  - Report JSON serialization in `topic_analysis_report_file.dart` updated with backward compatibility.
  - Localization files `app_en.arb` and `app_de.arb` updated with localized strings.
