# Proposal

## Why

kafkalyzer excels at high-throughput consumption and fast offline analysis, but development and incident troubleshooting workflows often require deeper investigation across schema evolution, failure queues, and team collaboration:
1. **Schema Evolution Bottlenecks**: Developers currently cannot verify whether a modified schema is backwards-compatible against registered subjects without leaving the tool, nor can they compare diffs between historical schema versions or discover all topics bound to a given schema.
2. **Disconnected Dead-Letter Queues (DLQ)**: In distributed event systems, failures routinely redirect poison pills and unparseable payloads to `-retry` and `-dlq` topics with error metadata buried in application headers (e.g. Spring Kafka, Quarkus). Currently, users must manually search for corresponding dead-letter topics and correlate error headers to original topics by hand.
3. **Friction in Team Incident Sharing**: When diagnosing anomalies or poison pills in large topics, engineers cannot easily share a direct link or reproducible reference to a specific topic, partition, offset, and filter state with teammates, forcing manual communication of multiple coordinates.

Addressing these gaps (features C5, C6, and C7 from `design/feature-gap-analysis.md`) significantly boosts diagnostic velocity while strictly preserving kafkalyzer's read-only guarantees.

## What Changes

- **Schema Evolution Workflows (C5)**:
  - Add schema compatibility verification against Confluent Schema Registry (`/compatibility/subjects/{subject}/versions/{version}`) to test draft schema changes against current or specified subject versions.
  - Implement a side-by-side and unified textual and structural diff viewer between any two selected schema versions for a subject.
  - Provide a reverse lookup showing all topics associated with a selected schema or subject.
- **Dead-Letter Queue & Retry Topic Detection (C6)**:
  - Automatically identify associated retry and dead-letter topics using naming conventions (`*-retry*`, `*-dlq*`, `*-DLQ*`, `*.DLQ*`) and standard failure headers (`x-original-topic`, `x-exception-message`, `kafka_dlt-exception-message`, etc.).
  - Group and badge retry/DLQ topics alongside their base topics in the Explorer sidebar and Topic Detail views.
  - Surface an incident diagnostic banner in DLQ messages highlighting exception messages, stack traces, and original message coordinates, with one-click navigation back to the origin message and one-click copy of `kcat` replay commands for external remediation.
- **Shareable Message & Topic Reference Links (C7)**:
  - Define a lightweight, human-readable URI schema (`kafkalyzer://cluster/{clusterId}/topic/{topic}?partition={p}&offset={o}&filter={f}`) and compact token format for sharing exact message locations.
  - Add "Copy Shareable Link" actions to the message inspector header and table context menu.
  - Introduce a "Quick Jump / Open Reference" dialog and keyboard shortcut (`Ctrl/Cmd+G`) that parses a shared link, connects to the specified cluster profile, opens the topic tab, seeks directly to the target partition/offset, and highlights the message.

## Capabilities

### New Capabilities

- `schema-evolution-workflows`: Interactive schema compatibility checks against Schema Registry subject versions, two-version structural and textual schema diffing, and schema-to-topic association mapping.
- `dead-letter-queue-detection`: Automatic detection, visual grouping, and contextual diagnostic inspection of retry and dead-letter queue topics and error header signatures with seamless navigation to original messages.
- `shareable-message-references`: Generation, clipboard export, and deep-link resolution of shareable message references with direct seeking and filter context restoration.

### Modified Capabilities

<!-- None: Existing capabilities remain intact; new capabilities provide additive, non-breaking enhancements. -->

## Impact

- **Rust Backend (`kafkalyzer-kafka`)**:
  - Add `check_schema_compatibility(profile, subject, version, schema_json)` to query Schema Registry compatibility endpoints.
  - Add `fetch_subject_topics(profile, subject)` to discover topics bound to subjects.
- **Flutter Frontend**:
  - Enhance `TopicSchemaInspectorView` with a "Check Compatibility" tab/dialog and a "Compare Versions" diff interface using existing diff styling.
  - Update `TopicListItem` and Explorer sidebar controller with retry/DLQ grouping and badges.
  - Add DLQ error diagnostic card in `MessageInspectorPanel` when failure headers are present.
  - Add quick-jump dialog and URI parser for `kafkalyzer://` links.
- **Localization**:
  - Add English and German localization entries for compatibility results, diff controls, DLQ badges, error header labels, and link sharing.
