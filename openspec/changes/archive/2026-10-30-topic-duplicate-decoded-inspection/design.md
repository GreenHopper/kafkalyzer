# Design

## Context

See `proposal.md` for motivation. In `kafkalyzer-kafka/src/kafka_analyzer.rs`, the message poll loop resolves schema registry decoders and calls `decode_message_to_value`, passing `parsed_payload: Option<&Value>` into `AnalyzerAccumulator.record_message_with_filter`. However, the duplicate sample recording logic previously checked only `std::str::from_utf8(payload_bytes)`, ignoring `parsed_payload`. This caused all Avro, Protobuf, and non-UTF-8 binary messages to fall back to `[Binary 0x...]` hex previews.

## Goals / Non-Goals

**Goals:**
- Provide readable, decoded duplicate payload previews in both the duplicate table and detailed inspection view for Schema Registry (Avro, Protobuf) and JSON messages.
- Increase sample payload storage capacity (up to 4,000 characters) for top duplicate occurrences to allow comprehensive message inspection.
- Introduce an interactive `DuplicateDetailsDialog` in Flutter with formatted JSON viewing, copy actions, and sample coordinates.
- Enable direct navigation to the sample partition/offset in the topic's "Messages" view when the topic is active in the session.
- Maintain fallback indicators for genuine binary or undecodable payloads without failing analysis.

**Non-Goals:**
- Altering the collision-resistant 128-bit Sha256 duplicate fingerprint algorithm (raw bytes equality remains exact and performant).
- Unbounded payload memory accumulation (duplicate sample tracking remains strictly bounded to 1,000 entries, with top 20 exported).

## Decisions

### 1. Payload Resolution Cascade in `record_message_with_filter`

When recording a sample for `seen_fingerprints` or `duplicate_samples`:
```
1. If `parsed_payload` is Some(val) -> serialize to JSON string via `serde_json::to_string(val)`
2. Else if `payload_bytes` parses as JSON -> serialize `serde_json::to_string(&json_val)`
3. Else if `payload_bytes` is valid UTF-8 -> use decoded UTF-8 string
4. Else -> fallback to `[Binary 0x<hex>]`
```
*Rationale*: Reuses the already-decoded Schema Registry Value computed for field frequencies and value filtering with zero additional network or schema registry round-trips.

*Alternatives considered*:
- Re-decoding Avro on demand when viewing details: Rejected because it would require keeping raw byte buffers or refetching schemas after scan completion.

### 2. Sample Payload Capacity & Truncation

`DuplicateSample` and `TopDuplicateOccurrence` will retain:
- A compact preview string (`payload_preview`) for the summary table.
- A full/extended payload string (`payload_content` or extended `payload_preview` up to 4,000 chars) for the details dialog.
- To preserve backwards compatibility with report version 3, `TopDuplicateOccurrence` can either store up to 4,000 characters in `payload_preview` (or add an optional `full_payload` field). Using a 4,000 char capacity in `payload_preview` with lazy UI truncation in the table maintains 100% format and schema compatibility across Dart and Rust without bumping serialization versions.

### 3. Interactive Duplicate Details Dialog (`DuplicateDetailsDialog`)

In `duplicate_analysis_view.dart`:
- Making table rows clickable and providing an explicit info icon button (`Icons.info_outline`).
- Tapping opens `DuplicateDetailsDialog` displaying:
  - Header with occurrences, percentage share, rank, and duplicate scope.
  - Metadata chips: Partition, Offset, Formatted Timestamp.
  - Key section (if present) with copy button.
  - Payload preview with pretty-printed JSON formatting and copy button.
  - Action button: "Open in Messages" (`Nachrichten anzeigen`) which switches to the Messages tab and targets that partition and offset.

## Risks / Trade-offs

- **[Risk: Memory overhead from storing longer sample strings]** → *Mitigation*: Limit sample strings to 4,000 characters and keep the accumulator capped at 1,000 duplicate samples. 1,000 * 4KB = max 4MB worst-case in worker memory, reduced to top 20 items in final report.
- **[Risk: Navigation unavailable for imported or offline reports]** → *Mitigation*: The "Open in Messages" button is conditionally displayed or disabled when viewing an imported report or when disconnected from the cluster.
