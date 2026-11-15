# Proposal: offline-schema-decoding

Roadmap: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.36 (size M–L, Phase 2b), gap list §2.4 C ("keine
Offline-Schemas"), `design/feature-gap-analysis.md` §5.2 C4, dependency §6.2 (`5.35 ──► 5.36`, shared type model),
guardrails L1–L7, non-goals §7.

## Why

Structured decoding only works through a reachable Schema Registry. Teams that have the `.avsc` / `.proto` files but
no registry access (air-gapped clusters, registry ACLs, raw producers without the Confluent serializer) see Avro and
Protobuf payloads as hex and cannot filter, analyse or script on fields. Checked against the current code:

- `kafka_consumer.rs::consume_with_filter` builds decoders only from `create_sr_settings(profile)`.
  `setup_schema_registry` decodes a side only when `<topic>-key` / `<topic>-value` is in the subject list. When the
  subject list cannot be fetched it logs a warning and decodes nothing, even for payloads with a Confluent prefix.
- Without a registry, `decode_message_component` returns the bytes as UTF-8 text when they happen to be valid UTF-8
  (including a Confluent-framed JSON payload with its control bytes), else `<Binary Data>:<hex>` /
  `<Binary Key>:<hex>`. The roadmap's "only hex" is therefore right for binary Avro/Protobuf, not for every payload.
- A registry decode that fails is silent: the message falls back to text or hex with no reason shown.
- `kafka_analyzer.rs::analyze_topic_content` (lines 1082–1089, the roadmap cites ~1058–1065) builds the same decoders
  only with a registry. Without one, framed payloads are counted as "Schema Registry (Avro/Proto)" and contribute no
  field statistics.
- There is no local schema anywhere in the code. `kafkalyzer-core` already has `apache-avro` 0.17 and
  `avro_utils::convert_avro_value`, and `schema_wire::wire_schema_id` reads the 5-byte prefix. The Protobuf-to-JSON
  conversion (`convert_protofish_message`) lives in `kafkalyzer-kafka`. The Confluent message-index parser of
  `schema_registry_converter` (`proto_resolver::to_index_and_data`) panics on malformed input, so it is not reused.

## What Changes

- **Local schema assignment** per topic, separately for key and value: an Avro schema (`.avsc`), Protobuf source
  (`.proto`, proto3) or a Protobuf descriptor set (`.desc` / `.pb`, from `protoc --include_imports
  --descriptor_set_out`), or a JSON Schema. Protobuf requires choosing the message type. The assignment dialog checks
  the file and shows its type, message types and field count, or the reason it cannot be used.
- **Stored per cluster and topic** on this machine. It is used by the topic message view, the consumer-lag message
  view, the topic analysis and script steps, in the GUI and in headless `--script` runs.
- **Precedence**: by default a local schema is used only when the registry cannot decode that side (no registry
  configured, registry unreachable, no subject for the side, schema id not resolvable, or a payload without the
  Confluent prefix). The user can set an assignment to "always use the local schema".
- **Framing**: payloads with the Confluent prefix (magic byte + schema id, plus the message-index array for Protobuf)
  and raw payloads without a prefix both decode. Avro, where a raw payload can start with `0x00`, gets an explicit
  framing choice (auto / Confluent / raw).
- **Failures are visible**: if decoding fails, the message keeps its raw text or hex form and carries the reason
  (file missing, schema invalid, message type not found, payload does not match the schema). It is never shown as
  empty and never hidden. The topic analysis counts such messages under their own content type.
- **File handling**: the file is read and parsed once per scan, never per message. A missing, unreadable or changed
  file is shown as a state of the assignment, and a missing file never stops a scan.
- **Provenance**: the message inspector, message cards, exports and script results state "local file `<name>`" with
  type, message type and the wire schema id when present.
- **JSON Schema scope (honest)**: decoding a JSON-Schema-framed message is plain JSON after the 5-byte prefix. The
  local JSON Schema adds the prefix stripping, the field model for suggestions and the schema view. It does **not**
  validate payloads against the schema.

## Capabilities

### New Capabilities

- `offline-schema-decoding`: assigning a local schema file to the key or value of a topic, storing it per cluster and
  topic, precedence against the registry, loading once per scan, file error states, applying it in search, analysis
  and scripts, showing it in the topic schema view and field suggestions, and staying offline and read-only.

### Modified Capabilities

- `extended-serialization-formats`: added decoding of Avro, Protobuf and JSON Schema payloads with a given schema
  instead of a registry lookup: Confluent prefix and raw payloads, Protobuf message indexes, the strict-match rule
  (no unread bytes) and visible decode errors.
- `message-schema-provenance`: "Schema Identity Per Message Side" now names local-schema decoding for plain payloads
  (its scenario "decoded as before" no longer holds when a local schema is assigned). Added: local file provenance in
  the inspector, on message cards, in exports and in script results.

Not changed (checked): `integrated-schema-inspector` (5.35 has open MODIFIED deltas on it; the local section is
specified in the new capability instead), `topic-content-analysis` (already requires decoded Avro objects to be
analysed as structured payloads), `topic-consumption`, `headless-script-execution`, `saved-topic-searches`.

## Impact

- **Read-only impact: no new Kafka or Schema Registry calls.** The only new I/O is reading a local file chosen by the
  user. No URL fetching, no registry writes. `scripts/check_read_only.sh` must pass unchanged.
- **Rust**: `kafkalyzer-core` new `local_schema.rs` (framing parser, Avro/Protobuf/JSON decode from schema text,
  descriptor-set conversion) and the Protobuf-to-JSON conversion moved from `kafkalyzer-kafka`; `kafkalyzer-kafka`
  new `local_schema_loader.rs` (file read with size cap), `kafka_consumer.rs` (one decode entry point with the local
  source, `consume_with_filter` parameter), `kafka_analyzer.rs` (same decode entry point, content-type labels);
  `kafkalyzer_core::kafka_types` (`LocalSchemaUse` on `KafkaMessage`, assignment types, `TopicAnalysisOptions`
  field). Bridge: `rust/src/api/local_schema.rs` (new), `kafka_consumer.rs`, `kafka_types.rs` (additive).
- **Dart**: new `LocalSchemaAssignmentService` (shared_preferences, per cluster and topic), assignment dialog under
  `lib/src/features/schema/presentation/widgets/`, `topic_schema_inspector_view.dart`, `topic_detail_view.dart`,
  `message_stream_controller.dart`, `multi_search_controller.dart`, `topic_partition_table.dart`,
  `topic_analysis_controller.dart`, `message_inspector_panel.dart`, `message_metadata_card.dart`,
  `message_export_service.dart`, `search_json_serializer.dart`, `schema_controller.dart` (field suggestions),
  `dependency_injection.dart`, en + de ARB, regenerated `lib/src/rust/**` and `test/src/rust/api/rust_mocks.mocks.dart`.
- **Dependencies**: no new crate is planned. `protofish` reaches `kafkalyzer-core` through 5.35. Spike S2 decides
  whether descriptor sets can be read with `protofish` alone; its fallback adds `prost-types` (pure Rust).
- **Prerequisites**:
  - **Hard: 5.35 `schema-type-awareness-and-subject-browser`** — `kafkalyzer_core::schema_model` (schema type,
    field model, Protobuf top-level scan), `protofish` in core, the field-model display in the schema view, and its
    edits to `create_sr_settings`. This change adds a message-type parameter to the Protobuf field walker.
  - **Ordering with 5.9 `structured-message-filter`**: both edit the decode path in `kafka_consumer.rs` and the
    `consume_with_filter` signature and Dart stream-factory typedefs. 5.9 task 3.1 merges the duplicated registry
    decode branch into one `decode_component`. Land 5.9 tasks 3.1–3.3 first and add the local source to that function.
    If this change lands first, it does exactly that merge as specified in 5.9 design D5, and 5.9 rebases.
  - **Ordering with 5.37 `analysis-scope-and-history`**: both edit `analyze_topic_content` and add a field to
    `TopicAnalysisOptions`. 5.37 changes the setup (watermarks, scan plan) and the accumulator; this change changes
    the decoder setup and the three decode call sites. The hunks are disjoint; land 5.37 first (Phase 2a).
  - Soft: `accessibility-and-l10n-sweep` owns the l10n guard tests; new strings must pass them.

## Non-goals

- Editing, creating or registering schemas; fetching schemas from URLs; any registry write (L1).
- Validating JSON payloads against a JSON Schema; Avro writer/reader schema resolution beyond decoding with the one
  given schema; Avro single-object encoding (`C3 01` header); Avro schemas spread over several files.
- Protobuf source files with `import`s of other files (use a descriptor set), proto2 source files (use a descriptor
  set), proto2 groups and extensions.
- Sharing assignments between machines, including them in profile or script exports, or migrating them when a
  profile is renamed (same scope rule as saved searches).
- Recording the applied local schema inside the topic analysis report file.
- A fifth navigation destination (L6) or a second field-path syntax (L7).
