# Proposal: schema-type-awareness-and-subject-browser

Roadmap: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.35 (size L, Phase 2a), finding B10, gap list §2.4 C
("kein Subject-Browser, kein Kompatibilitäts-Level, Registry-Aufrufe ohne Timeout"), decision E16 (subject browser
inside the Explorer, no fifth navigation destination), guardrails L1–L7, non-goals §7.

## Why

The schema features assume Avro and the `<topic>-key`/`<topic>-value` naming everywhere. Protobuf and JSON Schema
subjects are labelled "Avro" and give no field paths, and subjects with other names cannot be reached at all. The
registry client has no timeout, and an HTTP error shows up as a JSON parse error. Checked against the current code:

- `schema_registry.rs::fetch_schema` returns only the `schema` string. `schemaType`, `id`, `version` and `references`
  of the registry answer are dropped (B10 confirmed).
- `topic_detail_view.dart:516` always renders `TopicTag("Avro")` when a key or value subject exists, and
  `topic_list_item.dart:408,431` writes `Schema: Avro` into the sidebar tooltip (B10 confirmed).
- `TopicSchemaInspectorView` passes every schema through `simplifyAvroSchema(jsonDecode(...))` inside
  `try { } catch (_) {}` (lines 125-128, 212-221). A JSON Schema renders as the single word `object` (the simplifier
  returns `type`), a Protobuf schema silently falls back to raw text, and the empty state says "No Avro schema found".
- `SchemaController.parseSchemaFields` only knows Avro records with top-level `fields`; `fetchSchemaFields` logs
  failures with `debugPrint` and returns `[]`. Search-bar and script field suggestions are therefore empty for
  Protobuf and JSON Schema topics.
- `fetch_subjects`, `fetch_schema`, `fetch_schema_versions` and `check_schema_compatibility`: no timeout,
  `Runtime::new()` per call, subject names put raw into URL paths, no check of the HTTP status. A 401 or 404 shows up
  as "error decoding response body", not as an HTTP error. The URL is not normalised: no `http://` default, and a
  trailing `/` gives `//subjects`. `SchemaProvenance` and `create_sr_settings` add `http://` themselves.
- The registry client builder from `restore-tls-verification` is already shared (`schema_registry_client_builder`),
  and `connection-diagnostics` already sets a 10 s timeout and maps 401/403 for its probe. Both are reused here.
- There is no subject list in the UI. `SchemaViewerDialog` exists but is used only by tests. `SchemaDiffDialog` lists
  associated topics, but no caller passes `onNavigateToTopic`, so the "open topic" action that
  `schema-evolution-workflows` requires is never offered. A failed association lookup shows as "No associated
  topics found".
- No compatibility level is shown anywhere. Schema text can only be copied through the generic viewer, not saved.

## What Changes

- **One read-only registry request helper** in `kafkalyzer-kafka`: GET only, one normalised base URL (trimmed, trailing
  `/` removed, `http://` added when no scheme is given), percent-encoded path segments, a timeout on every request,
  the shared runtime, basic auth, and a typed error (unauthorized, forbidden, not found, timeout, unreachable,
  certificate rejected, other HTTP status, invalid response). Error details contain no credentials and no URL. Existing
  registry functions use it. The `/compatibility` POST keeps its marked exception and gets the same URL, timeout and
  error handling.
- **Schema identity and type**: fetching a subject version returns subject, version, id, type (Avro, Protobuf,
  JSON Schema; a missing `schemaType` means Avro) and references (name, subject, version).
- **Type-correct field model** in a new pure module `kafkalyzer_core::schema_model`. It lists the fields of Avro,
  JSON Schema and proto3 Protobuf (parsed with `protofish`, which the decoder already uses) as canonical
  `json_path` paths. References are resolved within a fixed limit. Recursion, unresolved references and truncation
  are marked. If a schema cannot be parsed into fields, the reason is shown, never an empty list. This is the shared
  type model for 5.36 `offline-schema-decoding` and the field source for 5.9 `structured-message-filter` suggestions.
- **Inspector**: shows type, version, id, references (each opens the referenced subject at that version) and
  compatibility level per key/value schema. Field tree and pin/filter actions work for all three types. Copy and
  "Save as" (`.avsc` / `.proto` / `.json`) for the schema text. Empty state is "No schema registered", not "No Avro
  schema".
- **Labels**: topic header tag and sidebar tooltip show the real type, a neutral "Schema" while it is not loaded, and
  "unknown" when the registry failed.
- **Compatibility level** (read-only): global via `GET /config`, per subject via `GET /config/{subject}`. A 404 for the
  subject means "inherits global". A denied or failed read shows as unknown.
- **Subject browser in the Explorer sidebar** (E16): a Topics/Subjects switch, a searchable and virtualised subject
  list built from the cached `fetch_subjects`, the associated topic of each subject (one batch call, not one per row),
  global compatibility, loading, error and retry states. Selecting a subject opens the existing inspector in
  `SchemaViewerDialog`, with the version selector, compare action and associated topics that can be opened.
- **Fixes without spec delta**: wire `onNavigateToTopic` into `SchemaDiffDialog`
  (`schema-evolution-workflows` already requires the open action). Show association lookup failures as errors.

## Capabilities

### New Capabilities

- `schema-subject-browser`: searchable subject list inside the Explorer, associated topics, global compatibility,
  opening a subject in the inspector, and error and unknown states.

### Modified Capabilities

- `integrated-schema-inspector`: "Key and Value Avro Schema Display and Search" and "Graceful Schema Empty and Error
  States" become type-neutral. Added: schema identity, type and clickable references; type-correct field paths for
  all three types; type-correct labels in topic header and sidebar tooltip; copy and save of schema text.
- `schema-evolution-workflows`: added read-only compatibility level display (global and per subject, inherited
  state), and the availability of associated topics on the connected cluster.
- `schema-registry-auth`: added requirement for registry request handling (GET-only helper, timeout,
  understandable HTTP errors, subject encoding, URL normalisation, no secrets in errors).

Not changed: `message-schema-provenance`, `extended-serialization-formats` (decoding is already type-aware in
`kafka_consumer.rs::decode_message_to_value`), `compact-topic-sidebar`. Its tooltip scenario only demands
`Schema: Avro` for Avro topics and still holds. 5.33 modifies the same requirement, so this change adds its label
rule to `integrated-schema-inspector` instead of creating a second delta on it.

## Impact

- **Read-only impact**: the Schema Registry stays read-only and `scripts/check_read_only.sh` must pass unchanged. New
  requests, all `GET`:
  - `GET /config` (global compatibility) and `GET /config/{subject}` (subject compatibility),
  - `GET /subjects/{subject}/versions/{version}` for referenced subjects (same endpoint as today, now also for
    references, deduplicated and bounded).
  Existing `GET /subjects`, `GET /subjects/{s}/versions`, `GET /subjects/{s}/versions/{v|latest}` and
  `GET /schemas/ids/{id}/versions` now go through the helper. The only POST stays `/compatibility/...` (existing,
  marked exception). No Kafka calls are added.
- **Rust**: new `kafkalyzer-core/src/schema_model.rs` (+ `protofish` dependency in core);
  `kafkalyzer-kafka/src/schema_registry.rs` (helper, typed error, `fetch_subject_schema`, compatibility reads, batch
  association, provenance and `create_sr_settings` on the shared URL normaliser); `rust/src/api/schema_registry.rs`
  (additive DTOs and functions; existing functions keep their names and parameters; their errors become the typed
  registry error, see design D3).
- **Dart**: `schema_registry_service.dart`, `schema_controller.dart`, `topic_schema_inspector_view.dart`,
  `schema_viewer_dialog.dart`, `schema_diff_dialog.dart`, new subject browser widget under
  `lib/src/features/schema/presentation/widgets/`, `explorer_view.dart` (sidebar switch), `topic_detail_view.dart`,
  `topic_list_item.dart`, en + de ARB, regenerated `lib/src/rust/**` and `test/src/rust/api/rust_mocks.mocks.dart`.
- **Dependencies**: `protofish = "0.5.3"` added to `kafkalyzer-core`, the same version `kafkalyzer-kafka` already uses.
  No new Dart package.
- **Prerequisites**: none hard. Soft: `accessibility-and-l10n-sweep` (in progress) edits `explorer_view.dart`,
  `topic_schema_inspector_view.dart` and `schema_diff_dialog.dart` and owns the l10n guard
  (`test/l10n/hardcoded_strings_guard_test.dart`), so land it first or rebase. `topic-list-scale-and-organisation`
  (5.33) reworks the same sidebar and adds opening a topic by name. If it lands first, associated topics that are
  missing from the loaded list use its by-name opening; otherwise they are shown as "not in the topic list" and are
  not openable (design D9).
- **Consumers of this change**: 5.36 `offline-schema-decoding` reuses `kafkalyzer_core::schema_model` (type enum,
  references, field model). 5.9 `structured-message-filter` reuses `SchemaController.fetchSchemaFields` and the
  shared GET helper.

## Non-goals

- Any registry write: register, delete, change compatibility or mode (L1). No new POST.
- Offline or local schema files (5.36). Changes to message decoding or provenance.
- Schema type per row in the subject list (would need one request per subject, or `GET /schemas`, which not every
  registry implements). Soft-deleted subjects or versions, schema contexts as a separate UI, exporters, `/mode`.
- Topic association beyond the `<topic>-key`/`<topic>-value` naming (RecordNameStrategy has no topic in the name).
- proto2 field listing (`protofish` parses proto3 only; proto2 shows the text and a notice). Serialized descriptor
  format.
- Type-aware field flattening in the Scripts schema view (`script_schemas_view.dart` stays Avro-only; follow-up).
- A fifth navigation destination (E16, L6). A second path grammar (L7).
