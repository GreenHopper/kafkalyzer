# Design: offline-schema-decoding

## Context

See `proposal.md` (Why) for the defects found in the code. These existing or planned pieces shape the design:

- **Decode path today** (`kafkalyzer-kafka/src/kafka_consumer.rs`): `consume_with_filter` → `create_sr_settings` →
  `setup_schema_registry` returns `SrDecoders` plus `key_is_avro` / `value_is_avro`. Despite their names, these mean
  "the `<topic>-key|value` subject exists", and both are `false` when the subject list cannot be fetched.
  `process_and_send_message` decodes key and value through `decode_message_component` (text). The analyzer uses
  `decode_message_to_value` (JSON) and `decode_message_component` at three call sites (`kafka_analyzer.rs` ~1351,
  ~1459, ~1560). Both functions repeat the same registry branch, and both fall back silently to UTF-8 text or
  `<placeholder>:hex`. Dart detects the `<Binary Data>:` / `<Binary Key>:` prefix to show hex
  (`json_or_string_viewer.dart:252`).
- **Provenance**: `KafkaMessage.key_schema` / `value_schema: Option<MessageSchema { schema_id: u32, subject,
  version }>`. They are filled only when a registry is configured. Dart serialises them in exports and script
  results (`messageSchemaToMap` / `messageSchemaFromMap`). In the generated Dart `KafkaMessage`, optional fields are
  optional named constructor parameters, so adding fields does not break the 31 files that construct it.
- **Core**: `apache-avro` 0.17 (`Schema::parse_str`, `from_avro_datum`), `avro_utils::{extract_named_schemas,
  convert_avro_value}`, `schema_wire::wire_schema_id`, and `sha2`. Through 5.35, core gains `protofish` 0.5.3 and
  `schema_model` (`SchemaKind`, `SchemaFieldModel`, `schema_fields(kind, text, refs)`, and the Protobuf top-level
  message scan).
- **protofish 0.5.3** (checked in the registry sources): the grammar accepts only `syntax = "proto3"`.
  `MessageInfo::decode` never fails. Unreadable bytes end up in `MessageValue.garbage`, and unknown field numbers
  become unknown values. `MessageInfo.inner_types` is public and in declaration order. `Package.types` (top-level
  order) is private. A public modify API (`Context::new`, `insert_message`, `add_field`) exists.
- **schema_registry_converter 4.2.0**: `proto_resolver::to_index_and_data` parses the Confluent message-index list,
  but it `unwrap()`s the varint reads, so it panics on malformed input. `MessageResolver::find_name(index)` maps an
  index path to a full name from `.proto` text. It lives in `kafkalyzer-kafka` only.
- **Planned edits to the same code**: 5.9 D5 merges the two registry branches into one
  `decode_component(...) -> Decoded` and adds the `LazyMessage` view and new `consume_with_filter` parameters. 5.37
  rewrites the analyzer setup (scan plan, time filter, bounded fingerprints) and adds `TopicAnalysisOptions.scope`.
- **Dart persistence pattern**: `SavedSearchesService` stores data under the key
  `search_presets_<cluster>_<topic>`, parses per entry and keeps unreadable raw entries on save (A3 rule). Headless
  `--script` runs call `setupDependencyInjection` before `HeadlessScriptRunner.runCli`, so `getIt` services and
  `SharedPreferences` are available headless (`MultiSearchController` already reads preferences there).
- **Scan call sites in Dart**: `message_stream_controller.dart` (topic view), `multi_search_controller.dart`
  (scripts, GUI and headless), `topic_partition_table.dart` (consumer-lag messages) and
  `topic_analysis_controller.dart` (`analyzeTopicContentWithOptions`).

## Goals / Non-Goals

**Goals:** pure, broker-free decoding from a schema and payload bytes in `kafkalyzer-core`. One decode entry point for
search and analysis in `kafkalyzer-kafka`, with the local source inside it. The file is read once per scan. Bridge
changes are additive. One Dart service that every scan call site asks for the assignments of a cluster and topic.

**Non-Goals (design level):** no cross-scan cache of parsed schemas (parsing takes microseconds to milliseconds and
happens once per scan). No change to the registry decode itself. No negative cache for unresolvable registry ids
(existing behaviour, see Risks). No Dart-side decoding.

## Decisions

### D1 — Layering

| Logic | Layer | Why |
|---|---|---|
| Prefix and message-index parsing, Avro decode with a given schema, Protobuf decode from a `protofish` context, JSON after the prefix, strict-match checks, the descriptor set → proto3 text conversion, `LocalDecodeError`, Protobuf message listing and index-path resolution, Protobuf → JSON (moved from kafka) | `kafkalyzer-core::local_schema` | Pure computation on bytes and text, unit-testable without a broker. A second caller exists: search, analysis and later MCP. |
| Assignment and provenance domain types (`LocalSchemaAssignment`, `TopicLocalSchemas`, `LocalSchemaUse`), additive fields on `KafkaMessage` and `TopicAnalysisOptions` | `kafkalyzer-core::kafka_types` | Domain types live next to `KafkaMessage`. |
| Reading the file (size cap 10 MiB, regular-file check, SHA-256 of the bytes), turning I/O errors into `LocalDecodeError` | `kafkalyzer-kafka::local_schema_loader` | File-system I/O belongs in the I/O crate (L2). Core stays I/O-free. |
| Choosing between registry and local per side (precedence), the shared decode entry point, analyzer content-type labels | `kafkalyzer-kafka` (`kafka_consumer.rs`, `kafka_analyzer.rs`) | Needs the registry decoders and their per-scan state. |
| DTOs, `inspect_local_schema`, new parameters | bridge `rust/src/api/local_schema.rs`, `kafka_consumer.rs`, `kafka_types.rs` | L3, orphan rule. |
| Persistence, file picker, status display, choosing which call site passes which assignment, the inspector section, suggestions | Dart | View state and machine-local settings, same as saved searches. |

### D2 — Core decoding API

```text
enum LocalSchemaFormat { AvroSchema, ProtoSource, ProtoDescriptorSet, JsonSchema }
enum Framing { Auto, Prefixed, Raw }          // Auto is the default; only Avro offers the choice in the UI
struct LoadedLocalSchema { format, kind: SchemaKind, file_name, sha256, message_types: Vec<String>,
                           selected: Option<String>, compiled: Compiled }
enum Compiled { Avro { schema, named }, Proto { context, top_level: Vec<String>, proto_text }, Json }
fn load_local_schema(format, file_name, bytes, message_type: Option<&str>) -> Result<LoadedLocalSchema, LocalDecodeError>
fn decode_with_local(schema: &LoadedLocalSchema, framing, payload: &[u8])
    -> Result<LocalDecoded { value: serde_json::Value, framing_used, wire_schema_id: Option<u32>,
                             message_type: Option<String> }, LocalDecodeError>
enum LocalDecodeErrorKind { FileNotFound, FileUnreadable, FileTooLarge, SchemaInvalid, UnsupportedProto2,
                            UnresolvedImport, MessageTypeNotFound, PrefixMissing, IndexInvalid, IndexNotFound,
                            PayloadMismatch, TrailingBytes, NotJson }
struct LocalDecodeError { kind, detail: String }   // detail: names, counts and offsets only, never payload bytes
```

- **Avro**: `Schema::parse_str` (a top-level union in the file is accepted). Decode with
  `from_avro_datum(&schema, &mut cursor, None)`, then require `cursor` at the end. Otherwise the error is
  `TrailingBytes(n)`, because Avro decoding of random bytes often "succeeds". Conversion goes through the existing
  `convert_avro_value`. Framing `Auto`: if `payload[0] == 0 && len >= 5`, try prefixed first and fall back to raw on
  any error. If both fail, report the prefixed error (and mention the raw attempt). `Prefixed` without a prefix →
  `PrefixMissing`. `Raw` decodes from byte 0.
- **Protobuf**: the prefix is unambiguous. A raw Protobuf message cannot start with `0x00` (tag 0 is invalid), so
  `Auto` = prefixed iff `payload[0] == 0 && len >= 5`. After the id comes the index list. A single `0x00` means `[0]`.
  Otherwise there is a zig-zag varint count and then zig-zag varint indexes. The count is capped at 32 and each index
  must be ≥ 0, so the parser cannot panic. The index path resolves through `top_level[i0]` and then
  `inner_types`, filtered to messages (`IndexNotFound` otherwise). Raw payloads use the selected message type. Decode
  with `MessageInfo::decode`. `garbage.is_some()` anywhere in the tree → `PayloadMismatch`. Unknown field numbers are
  kept and shown, as in the registry path (schema evolution).
- **JSON Schema**: strip the prefix when present, then `serde_json::from_slice` (`NotJson` on failure). No
  validation (proposal non-goal).
- **Null or empty payload**: not passed to the decoder (tombstone / empty, as today).
- `convert_protofish_message` / `convert_protofish_value` move from `kafkalyzer-kafka` to core unchanged, and the
  registry path calls the core function. A regression test pins the output.
- **Alternative considered**: reuse `MessageResolver` / `to_index_and_data` from `schema_registry_converter`.
  Rejected: it panics on malformed bytes in the hot path, and it would pull the registry client crate into core.
  Instead, a kafka-crate test cross-checks our index resolution against `MessageResolver::find_name` on the same
  `.proto` text (Spike S1).

### D3 — Descriptor sets: convert to proto3 text and use one parser

A `FileDescriptorSet` is turned into one synthesized proto3 text per `FileDescriptorProto`: package, messages, nested
messages, enums, fields with `repeated`, map entries as `map<K,V>`, `oneof`, and fully qualified type names. That text
is parsed with `protofish::Context::parse` like a `.proto` source. Field model, top-level order and decoding then
share one code path with `.proto` files and with 5.35's `schema_fields`. proto2 descriptors work because the wire
format is the same: `required`/`optional` labels become singular fields and defaults are dropped. Groups and
extensions give `SchemaInvalid` naming the element.

How to read the descriptor bytes is decided by **Spike S2**:

- (a, preferred, no new crate) decode the bytes with `protofish` itself, using an embedded proto3 subset of
  `google/protobuf/descriptor.proto` (FileDescriptorSet, FileDescriptorProto, DescriptorProto,
  FieldDescriptorProto, EnumDescriptorProto, OneofDescriptorProto, MessageOptions.map_entry). The wire format is
  compatible, and the field numbers are fixed by the protobuf project.
- (b, fallback) `prost-types` + `prost` (pure Rust, no build script, builds on Linux/macOS/Windows). Use it only if
  (a) cannot read a `protoc --include_imports` output correctly.
- Rejected: building the `protofish` context through its modify API (two-pass type references and no top-level order
  available), and `prost-reflect` as a second decoder (a second Protobuf → JSON mapping that would drift from the
  registry path).

### D4 — One decode entry point and precedence (kafka)

```text
struct SideDecoding<'a> { registry_has_subject: bool, local: Option<LocalSide> }
struct LocalSide { schema: Result<Arc<LoadedLocalSchema>, LocalDecodeError>, framing, mode: Fallback | Always }
fn decode_side(rt, registry: &Option<SrDecoders>, side: &SideDecoding, bytes) -> SideResult {
    json: Option<Value>, text: Option<String>, local_use: Option<LocalSchemaUse> }
```

- It builds on 5.9's `decode_component`. `Always` → local only. `Fallback` → registry first when
  `registry_has_subject` and the payload is prefixed and the id resolves. Otherwise local. When there is no local
  side, the behaviour is exactly as today, and 5.9's regression test pins the text.
- Local success → `json` = decoded value and `text` = pretty JSON (same rendering as the registry path).
  `local_use` = `{ file_name, kind, message_type, framing_used, wire_schema_id, error: None }`.
- Local failure (including a load error) → `text` = the existing raw rendering (UTF-8 or `<placeholder>:hex`),
  `json` = `None`, and `local_use.error = Some(kind, detail)`. The raw form stays unchanged, so the hex viewer keeps
  working.
- Loading: in `consume_with_filter` and `analyze_topic_content`, before the consumer is created (outside the poll
  loop), each assigned side calls `local_schema_loader::load(assignment)` once. The result (`Ok` or `Err`) is wrapped
  in an `Arc` and shared by analyzer workers. A load error is logged once through `log_to_dart` (file name and kind,
  never the path contents) and attached to every message of that side. The scan never stops.
- The analyzer content type: a locally decoded payload counts as `"<Kind> (local schema)"`, a failed one as
  `"Local schema decode failed"`. A prefixed payload with no decoder keeps `"Schema Registry (Avro/Proto)"`. The
  locally decoded key feeds key analysis instead of `[Binary 0x…]`.
- With 5.9's `LazyMessage`, the value and key cells call `decode_side`, so filter expressions see locally decoded
  fields with no extra work.
- **Alternative considered**: "local always wins when assigned". Rejected: when the registry is reachable, it knows
  the writer schema of each record, and a stale local file would silently mis-decode. The default therefore prefers
  the registry, and `Always` covers the user who knows better (for example a registry holding the wrong subject).

### D5 — Bridge API (additive)

- `KafkaMessage` (core and bridge) gets `key_local_schema` / `value_local_schema: Option<LocalSchemaUse>`, and
  `TopicAnalysisOptions` gets `#[serde(default)] local_schemas: Option<TopicLocalSchemas>`.
- `consume_with_filter(…, local_schemas: Option<TopicLocalSchemas>, sink)` is appended after 5.9's parameters,
  whichever change lands second. It is an optional named parameter in Dart, so existing calls compile.
- `inspect_local_schema(path, format, message_type: Option<String>) -> LocalSchemaInfo { format, kind, file_name,
  sha256, message_types, selected_message_type, fields: SchemaFieldModelDto (5.35), error: Option<LocalSchemaErrorDto> }`.
  It is async, never throws for file or schema problems (they are returned in `error`), and is used by the dialog, the
  state check and suggestions.
- 5.35's Protobuf field walker gets an optional message name (default: first top-level message), so the field model
  matches the selected type. This is additive to `schema_fields`.
- The format default comes from the file extension in Dart: `.avsc` → Avro, `.proto` → ProtoSource, `.desc` / `.pb` /
  `.binpb` → descriptor set, `.json` → JSON Schema. A `.json` file containing `"type": "record"` is proposed as Avro by
  a core helper `guess_format(bytes)`. The user can always override.

### D6 — Dart: assignment service and state flow

- `LocalSchemaAssignmentService` (ChangeNotifier, registered in `dependency_injection.dart`) uses the key
  `local_schema_assignments_<cluster>_<topic>`. It stores one JSON object
  `{ "key": {...}?, "value": {...}? }` with
  `{ path, format, messageType?, framing, mode, sha256, assignedAt }`. An unreadable value is kept as raw and the
  topic reports `unreadable` (spec). Saving over it only happens when the user saves or removes explicitly.
- `scanOptionsFor(clusterName, topic) -> TopicLocalSchemas?` is the one lookup used by all four call sites. The
  stream-factory typedefs in `MessageStreamController` and `MultiSearchController` gain the named `localSchemas`
  parameter (coordinate with 5.9's typedef change). `ScriptRunner` needs no change: it goes through
  `MultiSearchController`, which looks up by `target.profile.name` and `target.topic.name`, for GUI and headless runs.
- `stateFor(cluster, topic, side)` → `usable | changed | fileNotFound | unreadable | invalid | messageTypeMissing |
  unknown | checking`. It is computed by `inspect_local_schema` when the topic view or the dialog opens, and on demand
  (refresh). It is not computed per scan and not per row. `changed` = sha256 differs from the stored one, and
  "Confirm" stores the new hash.
- **UI** (all `package:material_ui`, ARB strings, tooltips and semantics on icon buttons, state as icon + text):
  - `LocalSchemaAssignmentDialog`: per side, a `FilePicker.pickFiles` (allowed extensions), a format selector, a
    message type dropdown (Protobuf), framing (Avro only), mode, a preview (type, number of fields, message types or
    the error), Remove, and Save (disabled while invalid or while no message type is chosen).
  - `TopicSchemaInspectorView`: a "Local schema" card per side with state and actions. It is also present in the
    "Schema Registry not configured" and "no schema registered" states. A usable schema shows the field model through
    5.35's display path. Avro uses `simplifyAvroSchema` on the file text, the same as registry Avro.
  - Topic header: a `TopicTag` "Local: <type>" when an assignment exists, with an error icon for non-usable states. A
    tap opens the dialog.
  - Message inspector: the provenance line per side, "Local file <name> · <type> [· <message>] [· id <n>]", or the
    error text from `describeLocalDecodeError(l10n, kind, detail)`. Message card: compact `K:`/`V: local`.
  - Analysis view: a notice line "Value decoded with local file <name>", taken from the options passed at scan start.
- `SchemaController.fetchSchemaFields(cluster, topic)` keeps its signature (5.9 depends on it). With `Always`, the
  local fields are used. With `Fallback`, the registry fields are used, and the local fields when the registry is not
  configured, failed or has no value subject.
- Exports and script results: `messageSchemaToMap` gets a sibling `localSchemaUseToMap` / `FromMap` under the
  additive keys `keyLocalSchema` / `valueLocalSchema`. Old files without these keys load with `null`.

## Risks / Trade-offs

- [Avro auto framing can mis-decode a raw payload as prefixed when both parse fully] → Prefixed is tried first only
  for `0x00` with ≥ 5 bytes, and the strict end-of-buffer check rejects almost every false match. Users with raw Avro
  can pin `Raw`. The framing used is shown per message.
- [protofish never fails and skips into `garbage`] → Treat `garbage` as a mismatch. Unknown fields are allowed (schema
  evolution), so a wrong message type with compatible wire types can still "decode". The message type used is shown
  in provenance.
- [Descriptor-set reading without a new crate may not work] → Spike S2, with fallback `prost-types`.
- [Index-path order differs from `schema_registry_converter`] → Spike S1 cross-check test.
- [Unresolvable registry ids are retried per message (`get_cached_schema` caches only successes); with Fallback the
  local decode then runs after a failed registry request] → Existing behaviour. 5.35 adds a timeout to `SrSettings`.
  For offline environments the registry is unreachable at scan start, so `registry_has_subject` is false and no
  per-message request happens. Documented: use `Always` for registries with stale or wrong subjects.
- [Large topics and payloads] → The schema is parsed once per scan and decoding is O(payload). There is no `block_on`
  and no regex in the loop (L4). Payloads are not copied beyond today's rendering. The 10 MiB file cap bounds memory
  per scan side.
- [Compacted or transactional topics, offset gaps, empty topics, missing ACLs, unreachable broker] → Unaffected.
  Decoding is a per-message step inside the existing loops, and the completion logic (`PartitionEOF`), empty-topic
  fast path and error paths do not change. A missing file or a denied file read becomes a per-side error, never a scan
  failure.
- [Paths are machine-local; headless runs on CI need the file at the same path] → The state is shown, and a missing
  file in a headless run yields messages with `fileNotFound` provenance. It is documented in the README scripting
  section.
- [Profile rename orphans assignments] → Same scope rule as saved searches (non-goal). The orphaned key is harmless.
- [Concurrent edits with 5.9 and 5.37 in the same functions] → Ordering in the proposal. Every hunk here is in
  decoder setup or decode call sites.

## Migration Plan

Additive only. No stored data changes. A new preferences key is used only when the user assigns a schema. The bridge
and export formats gain optional fields. Rollback = revert: stored assignments are then ignored, and exports with the
new keys still load in the old version (unknown keys are ignored by `messageSchemaFromMap`).

## Open Questions

- Should the applied local schemas be recorded in the topic analysis report file (format version after 5.37's v4)?
  Deferred (non-goal here); the dashboard notice covers the live session.
- Should a later change accept several `.avsc` files (named types across files) through `Schema::parse_list`?
  Deferred until requested.
