<!-- markdownlint-disable MD041 -->
## 1. Rust Backend & Aggregation Engine

- [x] 1.1 Define analysis domain types and aggregation statistics in `kafkalyzer-core` / `kafkalyzer-kafka` (volume, hourly buckets, partition stats, tombstones, key frequencies, field distributions)
- [x] 1.2 Implement high-throughput topic scanner and streaming aggregation pipeline in `rust/kafkalyzer-kafka/src/kafka_analyzer.rs`
- [x] 1.3 Implement JSON payload inspection, field frequency extraction, and top categorical value tracking in Rust
- [x] 1.4 Add unit tests for topic analysis metrics (hourly bucketing, tombstone counting, partition skew, top-k keys)

## 2. Bridge Layer & FRB Code Generation

- [x] 2.1 Define bridge types (`TopicAnalysisReport`, `TopicAnalysisProgress`, `PartitionAnalysis`, `HourlyCount`, `KeyOccurrence`, `FieldOccurrence`) in `rust/src/api/`
- [x] 2.2 Expose `analyze_topic_content` endpoint with stream sink for progress updates in `rust/src/api/`
- [x] 2.3 Run `flutter_rust_bridge_codegen` to update generated Dart bindings in `lib/src/rust/`

## 3. Flutter State Management

- [x] 3.1 Create `TopicAnalysisController` to manage scan configuration, live progress streaming, cancellation, and report state
- [x] 3.2 Register `TopicAnalysisController` in `lib/src/dependency_injection.dart`
- [x] 3.3 Add unit tests for `TopicAnalysisController` lifecycle, state updates, and cancellation

## 4. Flutter Presentation & Visual Dashboard

- [x] 4.1 Build metric overview cards widget for total messages, payload size stats, tombstone count & ratio, and key summaries
- [x] 4.2 Build 24-hour peak production histogram chart widget displaying hourly message distribution
- [x] 4.3 Build partition balance and utilization widget showing per-partition counts and skew indicators
- [x] 4.4 Build top keys list and structured field value frequency tables
- [x] 4.5 Assemble `TopicAnalysisView` with scan control bar (full scan vs sampling), progress indicator, and dashboard grid
- [x] 4.6 Integrate `TopicAnalysisView` into `TopicDetailView` with a view switcher between Message Stream and Content Analysis

## 5. Localization & Verification

- [x] 5.1 Add localized strings for all analysis metrics, tooltips, chart headers, and scan controls in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`
- [x] 5.2 Run `flutter gen-l10n` to update localization delegates
- [x] 5.3 Verify formatting and linting with `dart format`, `dart analyze`, `cargo fmt`, and `cargo test`
