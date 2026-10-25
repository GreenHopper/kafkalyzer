# Design

## Context

kafkalyzer provides fast real-time Kafka message streaming, topic inspection, and consumer lag monitoring. While it includes Avro/JSON Schema inspection in `TopicSchemaInspectorView`, developers currently lack tools to test schema compatibility before rollout, compare historical schema versions, or identify topic-to-schema bindings. Furthermore, handling dead-letter queues (DLQs) and sharing specific message diagnostic states during incidents requires manual correlation and communication across team channels.

See `proposal.md` for background and motivation.

## Goals / Non-Goals

**Goals:**
- Provide read-only schema compatibility checking via Schema Registry's `/compatibility` REST endpoint without mutating registry state.
- Provide a responsive side-by-side or unified diff comparison between any two schema versions.
- Automatically identify and badge retry and DLQ topics using standard naming patterns and Spring Kafka/Quarkus failure headers.
- Render an incident diagnostics card in `MessageInspectorPanel` for DLQ messages with one-click navigation to the original message and external CLI replay command generation (`kcat`).
- Implement standardized `kafkalyzer://` deep links and a Quick-Jump dialog (`Ctrl+G` / `Cmd+G`) for instant message seeking.

**Non-Goals:**
- In-app publishing, message mutation, or automated broker-side message re-injection (all mutations remain strictly excluded by design).
- Modifying broker ACLs, schema registry compatibility rules, or cluster configurations.

## Decisions

### 1. Schema Registry Compatibility via Native Reqwest Call

- **Choice**: Implement `check_schema_compatibility` in `rust/kafkalyzer-kafka/src/schema_registry.rs` calling Confluent Schema Registry's `POST /compatibility/subjects/{subject}/versions/{version}`.
- **Rationale**: Schema Registry compatibility validation is a strictly read-only check (`POST` is used by the Confluent REST API specification for query payloads, but creates no resources or mutations). Reuses existing HTTP client with SASL/mTLS credentials and caching.
- **Alternatives Considered**: Evaluating Avro compatibility entirely client-side in Dart. Rejected because Schema Registry subjects define server-side compatibility policies (e.g. `BACKWARD`, `FORWARD`, `FULL_TRANSITIVE`) and rulesets that must be authoritative.

### 2. Side-by-Side and Unified Schema Diffing

- **Choice**: Construct formatted JSON AST string representations and use a line-level diff comparator with syntax-highlighted additions and deletions.
- **Rationale**: Avro schemas are JSON documents. Line-level diffing with color coding (green for added fields/types, red for removed) matches user mental models and reuses existing theme colors from the diff viewer.
- **Alternatives Considered**: Graphical tree comparison with draggable split pane. Rejected as overly complex and less legible for standard Avro schema definitions.

### 3. Regex Pattern and Header Heuristics for DLQ Detection

- **Choice**: Categorize topics into base, retry, and dead-letter queues via configurable regex patterns:
  - DLQ: `[-_.](?:dlq|dl[tT]|dead[-_.]?letter)$`
  - Retry: `[-_.](?:retry(?:-\d+)?)$`
  Extract standard failure headers:
  - `x-original-topic`, `kafka_dlt-original-topic`, `original_topic`
  - `x-original-partition`, `kafka_dlt-original-partition`
  - `x-original-offset`, `kafka_dlt-original-offset`
  - `x-exception-message`, `kafka_dlt-exception-message`
  - `x-exception-stacktrace`, `kafka_dlt-exception-stacktrace`
- **Rationale**: These conventions cover over 90% of enterprise Spring Kafka, Quarkus, Micronaut, and custom Kafka consumer pipelines without requiring broker-side metadata.

### 4. Standardized Deep-Link URI Scheme

- **Choice**: Standard URI syntax `kafkalyzer://open?cluster=<cluster>&topic=<topic>&partition=<p>&offset=<o>&filter=<f>`.
- **Rationale**: Human-readable, transparent, easily shareable in Slack, Jira, or email, and trivial to parse using Dart's standard `Uri.parse`.

### 5. UI Components & Material 3 Alignment

- **Choice**: All new modals and widgets (`QuickJumpDialog`, `SchemaDiffViewer`, `DlqFailureDiagnosticsCard`) use `package:material_ui/material_ui.dart` and respect light/dark themes.
- **Rationale**: Ensures strict visual consistency and adherence to project-wide UI guidelines.

## Risks / Trade-offs

- **[Risk] Schema Registry compatibility endpoints differing across vendors (e.g. Confluent vs AWS Glue vs Karapace)** → **Mitigation**: Handle HTTP 404 or unsupported endpoint errors gracefully and fall back to displaying the local schema version diff without blocking the user.
- **[Risk] Non-standard DLQ topic naming or missing failure headers** → **Mitigation**: Allow users to manually link a topic to a base topic or manually trigger DLQ diagnostics from arbitrary headers.
- **[Risk] Large schema diffs causing UI stutter** → **Mitigation**: Format JSON schemas asynchronously in Dart isolates or background tasks prior to diff computation.
