<!-- markdownlint-disable MD041 -->
## Context

See `proposal.md` for motivation and background.

Kafkalyzer currently reads messages through a reactive `Stream<KafkaMessage>` consumer (`consume_with_filter`), where each message is transformed into a full `KafkaMessage` struct and transferred across the Flutter Rust Bridge (FRB) to Dart for display in `MessagesView`.

While this model is suitable for paginating or filtering small-to-moderate streams of messages, computing comprehensive aggregate metrics across thousands or millions of messages requires a dedicated high-throughput scanning and aggregation pipeline executed natively in Rust. This avoids unnecessary per-message serialization, memory overhead, and GC pressure in Dart while allowing the UI to receive live progress updates and final aggregated reports.

## Goals / Non-Goals

**Goals:**

- Provide a high-performance native scanning and aggregation engine in Rust (`rust/kafkalyzer-kafka`) with streaming progress updates.
- Compute all core analytical dimensions requested: total message volume, hourly peak production histogram (00:00–23:00), partition utilization and balance, tombstone counts and compaction insights, key frequencies, and structured field distributions.
- Integrate the analysis interface smoothly into `TopicDetailView` with an intuitive view switcher ("Messages" vs "Analysis").
- Render responsive, beautiful Material 3 analytical dashboard components (summary metric cards, partition balance bars, 24-hour peak production histogram, key/field tables).
- Provide responsive start, cancel, and scan progress controls.
- Support full localization across all new UI elements (`app_en.arb`, `app_de.arb`).

**Non-Goals:**

- Modifying or writing data back to Kafka topics (read-only analysis).
- Persistent historical time-series storage (metrics reflect current scanned topic state in the active session).
- Arbitrary map-reduce or streaming SQL query engine.

## Decisions

### 1. In-Engine Aggregation in Rust vs Client-Side Dart Processing

- **Decision**: Perform parsing, tallying, timestamp extraction, key indexing, and JSON field frequency analysis entirely in Rust within `rust/kafkalyzer-kafka`, exposing summary models across the FRB boundary.
- **Rationale**: Scanning millions of Kafka messages in native Rust runs orders of magnitude faster and consumes significantly less RAM than streaming raw strings/byte buffers over FRB to Dart. Dart receives only periodic progress snapshots (`TopicAnalysisProgress`) and the final `TopicAnalysisReport`.
- **Alternatives Considered**:
  - *Streaming all messages to Dart*: Rejected due to high memory footprint, UI thread stutter, and GC pauses on large topics.

### 2. Bounded In-Memory Aggregations & Top-K Tracking

- **Decision**: Use bounded data structures (e.g., top-K key frequency tracking with capped hash maps and reservoir/frequency truncation) in Rust during the scan.
- **Rationale**: Prevents unbounded memory growth when scanning topics with millions of unique high-cardinality keys or deep JSON structures.
- **Alternatives Considered**:
  - *Unbounded HashMap for all unique keys*: Could lead to OOM errors on very large topics with millions of distinct keys.

### 3. Dedicated FRB Data Models in `rust/src/api/`

- **Decision**: Define clean domain types (`TopicAnalysisReport`, `PartitionAnalysis`, `HourlyCount`, `KeyOccurrence`, `FieldOccurrence`, `TopicAnalysisProgress`) in `rust/src/api/` conforming to the orphan rule and export them cleanly to Dart.
- **Rationale**: Adheres to the established architecture where types passed directly between Rust and Dart are isolated in the bridge crate.

### 4. Integration into TopicDetailView

- **Decision**: Add a segmented view switcher or tab control in `TopicDetailView` allowing users to switch seamlessly between the "Messages" table/JSON stream and the "Analysis" dashboard.
- **Rationale**: Keeps all topic inspection workflows cohesive within the existing multi-tab topic explorer without requiring navigation away from the active topic context.

### 5. Native Flutter Visualizations (Custom Bar Visualizers / Canvas Painters)

- **Decision**: Build responsive, theme-aware Flutter custom painter and bar visualizers matching Kafkalyzer's Material 3 styling for the 24-hour production histogram and partition balance graphs.
- **Rationale**: Avoids heavy third-party charting dependencies, guarantees seamless dark/light theme transitions with FlexColorScheme, and provides exact layout control.

## Risks / Trade-offs

- **[Risk] High topic volume causing long scan times** → **Mitigation**: Allow configurable scan limits (e.g., full scan, sample last N messages, or time-bounded), display live throughput (messages/sec) and progress bar, and support immediate scan cancellation without losing partial aggregates.
- **[Risk] Non-JSON or binary payloads degrading field analysis** → **Mitigation**: Implement robust content-type detection (JSON, Avro/Protobuf, UTF-8 text, binary) and gracefully bypass JSON field parsing for raw binary or unstructured messages while still reporting size, timestamp, key, and partition stats.
- **[Risk] Heavy schema decoding overhead during analysis** → **Mitigation**: Lightweight payload sniffing in Rust for fast structural analysis, parsing JSON only when structured data is detected.

## Migration Plan

- Non-breaking addition. No existing database or config schemas are altered.
- Re-run `flutter_rust_bridge` code generation to regenerate bridge bindings after introducing Rust analysis functions and structs.
