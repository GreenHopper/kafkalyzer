# Design: schema-type-awareness-and-subject-browser

## Context

See `proposal.md` (Why) for the defects found in the code. These existing pieces shape the design:

- `kafkalyzer-kafka/src/schema_registry.rs` has `schema_registry_client_builder(profile)` (from
  `restore-tls-verification` D3, shared with the decoder through `kafka_consumer.rs::create_sr_settings`). The
  registry functions build a client per call, run `Runtime::new()` per call, format URLs with raw subjects and parse
  JSON without checking the status.
- `kafka_consumer.rs::shared_runtime()` is the shared tokio runtime. `kafkalyzer_core::connection_diagnostics` has
  `REGISTRY_TIMEOUT = 10 s`. `kafkalyzer-kafka/src/connection_diagnostics.rs` already maps 401/403, timeouts and TLS
  rejections (`classify_registry_reqwest_error`, `classify_tls_failure`) for its probe. Its URL handling stays as it
  is: `connection-diagnostics` requires the profile "exactly as entered".
- Decoding is already type-aware (`decode_message_to_value` switches on `SchemaType`). Protobuf decoding uses
  `protofish` 0.5.3 through `schema_registry_converter`, and decoded field names are the `.proto` field names
  (`convert_protofish_message`). Field paths for Protobuf are therefore the field names.
- `kafkalyzer_core::json_path::build_canonical_path(segments)` is the canonical way to turn segments into a path (L7).
- Dart: `SchemaController` caches subject lists per cluster name and field lists per topic. `SchemaViewerDialog`
  (only used in tests) wraps `TopicSchemaInspectorView`, which already supports `initialSubject`/`initialVersion`
  with a version selector. `SchemaDiffDialog` has an unused `onNavigateToTopic` callback.
- The bridge has no custom error types yet. Dart parses `AnyhowException(...)` strings
  (`cluster/domain/connection_error.dart`). flutter_rust_bridge is pinned at 2.11.1.
- Error text from `reqwest::Error` includes the request URL, and the URL can contain userinfo.

## Goals / Non-Goals

**Goals:** one GET-only request path for every registry read. A pure, unit-tested schema model in
`kafkalyzer-core` that 5.36 can reuse. Type-correct inspector, labels and field suggestions. A subject list in the
Explorer sidebar without one request per row.

**Non-Goals (design level):** no change to the decoder's request path, except that `create_sr_settings` uses the
shared URL normaliser and the shared timeout constant. No Rust-side cache for schema text. Dart keeps its existing
caches. No new persistence: the sidebar mode is not saved.

## Decisions

### D1 — Layering

| Logic | Layer | Why |
|---|---|---|
| Registry answer parsing (`schemaType`, id, version, references), schema type enum, field model for Avro / JSON Schema / Protobuf, compatibility body parsing, subject → topic batch association | `kafkalyzer-core::schema_model` | Pure computation on strings and JSON. 5.36 parses local schema text with the same code and needs no network. |
| URL normalisation, request helper, timeout, status/error mapping, reference fetching, `/config` reads | `kafkalyzer-kafka::schema_registry` | Needs `reqwest`. URL building uses `reqwest::Url` (already a dependency), so it stays in the I/O crate. Its unit tests need no network. |
| DTOs and thin wrappers | `rust/src/api/schema_registry.rs` | Orphan rule, L3. |
| Display tree for JSON Schema / Protobuf, sidebar switch, list filtering, labels, copy and save | Dart | View state and presentation. Avro keeps the existing `simplifyAvroSchema` display so existing tests and behaviour hold. |

`resolve_associated_topics_for_subject` moves its logic into core (pure string matching) and keeps its bridge
signature. A batch variant is added so the subject list resolves all rows in one call.

### D2 — One GET-only request helper

```text
struct RegistryEndpoint { base: reqwest::Url, auth: Option<(String, Option<String>)>, client: reqwest::Client }
RegistryEndpoint::from_profile(&ClusterProfile) -> Result<Self, SchemaRegistryError>   // NotConfigured / InvalidUrl
RegistryEndpoint::get_json(&self, segments: &[&str], query: &[(&str, &str)]) -> Result<Value, SchemaRegistryError>
RegistryEndpoint::url(&self, segments) -> reqwest::Url                                 // shared with the POST
```

- Normalisation (`normalize_registry_base_url(&str) -> Result<Url, _>`): trim, drop trailing `/`, add `http://` when
  there is no `://`, then parse with `reqwest::Url`. The base path stays. `SchemaProvenance::from_profile` and
  `create_sr_settings` call the same function. Today each of them adds `http://` on its own.
- Segments are pushed with `Url::path_segments_mut().push(segment)`, which percent-encodes `/`, `?`, `#`, `%` and
  spaces. That is the subject-encoding requirement, with no hand-written encoder.
- The client is `schema_registry_client_builder(profile).timeout(REGISTRY_TIMEOUT).build()`, so the timeout covers
  connect and read. Requests run on `shared_runtime().block_on(...)`. `Runtime::new()` per call is removed.
- Basic auth when the username is non-empty (same rule as the diagnostics probe; today both fields had to be `Some`).
- `get_json` is the only place with `client.get(...)` and `.send()`, with one `allow_read_only_exception` marker.
  There is no method parameter, so the helper cannot send anything but GET. The `/compatibility` POST keeps its own
  marked `.post(` line but uses `url()`, the same client (timeout) and the same status mapping. A non-2xx answer
  then becomes an error, not `is_compatible=false`. The spec scenario "Compatibility check times out" requires this.
- Alternative considered: a generic `request(method, ...)` helper. Rejected: the read-only gate could no longer see
  from the call site that a request is a GET.

### D3 — Typed registry error

```text
enum SchemaRegistryErrorKind { NotConfigured, InvalidUrl, Unauthorized, Forbidden, NotFound, Timeout, Unreachable,
                               CertificateRejected, HttpStatus, InvalidResponse }
struct SchemaRegistryError { kind, status: Option<u16>, registry_error_code: Option<i64>, detail: String }
```

- Status mapping: 401 → Unauthorized, 403 → Forbidden, 404 → NotFound, other non-2xx → HttpStatus. `detail` is the
  registry's `message` field (Confluent body `{"error_code":40401,"message":"..."}`), else the first 300 chars of the
  body. `reqwest` errors: `is_timeout()` → Timeout. A TLS rejection, found with the existing `classify_tls_failure`
  over the error chain, → CertificateRejected. Everything else → Unreachable. Before formatting, `err.without_url()`
  removes the URL, and so any userinfo, from the text. `detail` is capped at 500 chars.
- Bridge: the functions return `Result<T, SchemaRegistryErrorDto>`, which FRB turns into a thrown Dart exception
  object. Dart maps `kind` to ARB text plus status and detail in a single helper
  (`describeSchemaRegistryError(l10n, e)`).
- **Spike S1**: check that FRB 2.11.1 generates a usable thrown type for a custom struct error and for the mocks.
  Fallback if it does not: keep `anyhow::Result` and encode the error as `SchemaRegistryError[kind=...;status=...]
  detail`. A single Dart parser reads it, in the same way as `connection_error.dart`. Either way the existing
  functions keep their names and parameters. Only the thrown type changes, and every Dart caller already catches
  generically and shows `e.toString()`.

### D4 — Schema identity: `fetch_subject_schema`

New `fetch_subject_schema(profile, subject, version: Option<i32>) -> SubjectSchema { subject, version, id,
schema_type, schema, references: Vec<SchemaReference{name, subject, version}> }`, parsed in core
(`parse_subject_schema(&Value)`). A missing `schemaType` means Avro. An unknown value becomes `Other(name)`.
`fetch_schema` stays and returns `fetch_subject_schema(..).schema`. The diff dialog and the scripts view keep using
it.

### D5 — Field model (core) and reference resolution (kafka)

```text
schema_fields(kind, schema_text, refs: &[ResolvedReference{name, kind, schema}]) -> SchemaFieldModel
SchemaFieldModel { kind, root_name: Option<String>, messages: Vec<String>, fields: Vec<SchemaFieldEntry>,
                   truncated: bool, unavailable_reason: Option<String> }
SchemaFieldEntry { path, name, depth, type_label, doc: Option<String>, optional, repeated,
                   note: Option<Recursive | UnresolvedReference(String)> }
```

- The model is a flat list in pre-order with `depth`, not a recursive struct. The bridge stays simple and Dart
  rebuilds the tree in one pass.
- Avro: a walk over the JSON with a named-type table built from the main schema and all reference texts (full name
  and short name). This is a port of the Dart `parseSchemaFields` logic, which this replaces, with tests carried
  over. Unions show the non-null branch as `optional`. Arrays and maps continue into their item or value type
  without an index (as today).
- JSON Schema: `properties` recursively, `items` for arrays (`repeated`), `allOf/anyOf/oneOf` merged, `$ref` to
  `#/definitions/..` / `#/$defs/..` locally and to reference names (Confluent resolves `$ref: "customer.json"` by
  the reference `name`). An unknown `$ref` gives `UnresolvedReference`.
- Protobuf: `protofish::context::Context::parse([main, refs...])`. protofish has no public way to list top-level
  messages, so a small scanner (comments stripped, brace depth 0) reads `package` and the top-level `message` names,
  and `get_message("pkg.Name")` resolves them. Fields of the **first** top-level message become the paths. That is
  message index `[0]`, the default of the Confluent serializer. All top-level messages are listed in `messages` and
  shown in the inspector. `repeated` comes from `Multiplicity`. Nested messages are expanded and enums are leaf
  types. A parse failure (proto2, syntax error) gives `unavailable_reason`.
- Paths are built with `json_path::build_canonical_path`, so names that are not safe segments become JSON Pointers.
- Limits: depth 32 and 5 000 entries. Beyond that, `truncated = true`. Cycles are detected per path by type name
  and marked `Recursive`.
- Reference resolution (kafka): breadth-first over `references`, deduplicated by `(subject, version)`, at most 50
  fetches. A failed fetch becomes a missing reference, so its fields carry `UnresolvedReference(name)`. The bridge
  function `fetch_subject_schema_view(profile, subject, version) -> SubjectSchemaView { schema: SubjectSchema,
  fields: SchemaFieldModel }` does details, references and model in one call. The inspector needs all three, so
  there is no second round trip.
- Dependency: `protofish = "0.5.3"` is added to `kafkalyzer-core`. It is pure Rust (pest parser, no I/O, no C
  build), it is already in the lock file, and it already builds on Linux, macOS and Windows CI through
  `kafkalyzer-kafka`. Hand-parsing `.proto` text is the alternative and was rejected: a second Protobuf parser would
  drift from the one the decoder uses.
- **Spike S2**: protofish 0.5.3 with a Confluent proto3 schema that has an `import` reference, a `map<>` field and a
  `oneof`. Confirm the top-level scan and `get_message`, how map fields come out (map entries expected as a
  repeated message), and that proto2 fails cleanly. If imports of well-known types (`google/protobuf/timestamp.proto`)
  cannot be resolved, mark the field as unresolved rather than failing the whole model.

### D6 — Compatibility levels

`fetch_global_compatibility(profile) -> String` (`GET /config`) and
`fetch_subject_compatibility(profile, subject) -> Option<String>` (`GET /config/{subject}`). Any 404 (40408 "no
subject-level config" or 40401) → `None` = inherits global. Other errors are raised with D3 kinds. The body field is
`compatibilityLevel`, with `compatibility` accepted as an alias. `?defaultToGlobal=true` is not used because older
registries ignore it. Dart computes the effective value and whether it is inherited. When the subject value is
`None` and the global read failed, it shows unknown (spec "Neither level readable").

### D7 — Dart state flow

- `SchemaRegistryService` gets the new methods. `SchemaController` gets:
  - `fetchSubjectSchemaView(cluster, subject, {version})`, cached per `(cluster, subject, version)` for concrete
    versions; "latest" is cached per session until refresh. The topic header and the sidebar tooltip read the type
    from this cache (`schemaTypeFor(cluster, subject)` → known / not loaded / failed).
  - `fetchGlobalCompatibility` (cached per cluster until refresh) and `fetchSubjectCompatibility` (not cached).
  - `associatedTopics(cluster)`: memoised batch result, recomputed when the subject list or the topic list changes.
  - `fetchSchemaFields(cluster, topic)` keeps its signature (5.9 depends on it). It now uses
    `fetchSubjectSchemaView("$topic-value").fields`, logs failures with `Logger` instead of `debugPrint`, and does not
    cache failures. `parseSchemaFields` and its private helpers are removed after their tests move to Rust.
- `TopicSchemaInspectorView`: per side it holds a `SubjectSchemaView` plus the compatibility state. Avro display =
  `simplifyAvroSchema(jsonDecode(schema))`. JSON Schema and Protobuf display = a map built from `fields` with the
  same key format (`name : Type` for complex, `name` → type label for leaves). The existing `normalizeSchemaFieldPath`
  and the pin/filter actions keep working unchanged. A failed simplify or an `unavailable_reason` shows the raw text
  and a notice. The section header shows type · version · id, compatibility, reference chips, copy and save.
  Reference chips and subject-browser entries open `SchemaViewerDialog` with a new `subject`/`version` parameter.
  Inside that dialog, a reference replaces the shown subject and a back action returns.
- `SchemaViewerDialog`: `topicName` becomes optional, and `initialSubject`/`initialVersion` are added. The dialog
  passes `onNavigateToTopic` to the diff dialog and shows associated topics (D9).
- Save uses `FilePicker.saveFile` and the existing completion affordance (`export_notification_helper.dart`), same as
  the message export. Cancel shows nothing.

### D8 — Subject browser placement (E16)

A `SegmentedButton` "Topics | Subjects" under the cluster list in the Explorer sidebar replaces the topic list area.
The Explorer's state holds it (not persisted). A new `SubjectBrowserList` widget gets the filter field, counter,
global compatibility, refresh, `ListView.builder` and the error/empty states. Filtering is computed once per change
of input (filter text, subject list), never per row. Alternatives: a fifth rail destination (forbidden, E16/L6). A
pseudo-tab in the topic tab bar: tabs are `OpenTopicRecord`s that are persisted per cluster session, so a non-topic
tab would change the session format. A section in the cluster overview: not reachable while topic tabs are open.

### D9 — Associated topics

Core `associate_subjects(subjects, topics) -> Vec<SubjectAssociation{subject, topic: Option<String>, side:
Key|Value|None, on_cluster: bool}>` uses the existing suffix rule. `on_cluster` is false when the derived topic is
not in the given list. In Dart, an empty or failed topic list means "not verified", not "missing". Opening a topic
uses `ActiveConnectionController.openTopic` with the loaded `TopicMetadata`. If the topic is not in the list, the
entry has no open action. If 5.33 has landed, its open-by-name path is used for unverified topics. There is never a
placeholder `TopicMetadata` (B7). `SchemaDiffDialog._loadAssociatedTopics` shows an error with retry on failure.

## Risks / Trade-offs

- [Typed error changes the thrown Dart type of existing functions] → All callers catch generically; S1 fallback keeps
  `AnyhowException`. Tests asserting exact error strings are updated in the same task.
- [10 s timeout is shorter than before (none)] → The registry is only used for metadata. A slow registry now fails
  visibly with a timeout instead of hanging the inspector.
- [protofish is proto3-only and has no top-level listing] → S2. Proto2 shows the text and a notice. First-message
  paths may not match a topic that uses another message index → listed `messages` makes this visible (open question).
- [Display-key path reconstruction breaks for field names containing `.` or ` : `] → Existing limitation of
  `normalizeSchemaFieldPath`. Suggestions use the canonical `path` from core, so only the tree actions are affected.
  A test covers that a JSON Schema property `a.b` gives a JSON Pointer suggestion.
- [Reference fan-out] → Capped at 50 fetches with dedupe. Each fetch is bounded by the timeout, so the worst case is
  long but bounded. The inspector shows a loading state and stays non-blocking.
- [Sidebar conflicts with 5.33 and accessibility-and-l10n-sweep] → The switch sits above the list area. Rebase onto
  whichever lands first. The subject list is a separate widget so the topic list code is not touched.
- [Missing ACLs] → `/config` may be denied while `/subjects` works (Confluent RBAC). Each value fails on its own and
  shows unknown with an "access denied" hint.
- [Large registries] → 10 000+ subject names are a few hundred KB in memory. The list is virtualised. One batch
  association call per list change.

## Migration Plan

No stored data changes. The sidebar mode is not persisted, and the ARB key `noAvroSchemaFound` is replaced by a
type-neutral key. Rollback means reverting the change. The bridge additions are additive, and the changed error
type is the only signature-visible difference (D3).

## Open Questions

- Should the Protobuf message used for field paths be selectable when a `.proto` has several top-level messages?
  (Default: first message, all messages listed. A selector would be added in the inspector only, without changing
  the model.)
- Should `GET /schemas?latestOnly=true` be used later to show types in the subject list where the registry supports
  it? Deferred, non-goal here.
