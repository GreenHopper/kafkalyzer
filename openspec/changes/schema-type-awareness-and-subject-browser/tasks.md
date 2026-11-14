# Tasks

## 1. Spikes

- [ ] 1.1 Spike S1 (design D3): in a throwaway branch, add a bridge function returning `Result<(), SchemaRegistryErrorDto>`
      with flutter_rust_bridge 2.11.1. Run `flutter_rust_bridge_codegen generate` and `dart run build_runner build`.
      Check that Dart receives a typed thrown object with `kind`/`status`/`detail` and that mockito mocks compile.
      Record the result (typed error or the `SchemaRegistryError[kind=..;status=..]` string fallback) in this file
      under 1.1. Verify: the decision is written down and the throwaway code is removed.
- [ ] 1.2 Spike S2 (design D5): write a `#[test]` against `protofish` 0.5.3 with a Confluent proto3 schema that
      imports a referenced `.proto`, and has a `map<string,int32>` field, a `oneof`, a nested message and an enum,
      plus one proto2 schema and one schema importing `google/protobuf/timestamp.proto`. Confirm the
      top-level message scan and `get_message("pkg.Name")`. Record how map fields come out and confirm that proto2
      and the unresolved import fail cleanly without panicking. Verify: the test is kept as a regression test in
      task 2.4.

## 2. Core schema model (`kafkalyzer-core`)

- [ ] 2.1 Add `protofish = "0.5.3"` to `rust/kafkalyzer-core/Cargo.toml` and create `schema_model.rs` (exported in
      `lib.rs`) with `SchemaKind {Avro, Protobuf, Json, Other(String)}`, `SchemaReference`, `SubjectSchema`,
      `ResolvedReference`, `SchemaFieldModel`, `SchemaFieldEntry`, `FieldNote`. Verify: `cargo build -p kafkalyzer-core`
      succeeds and `cargo tree -p kafkalyzer-core` shows no rdkafka, reqwest or flutter_rust_bridge.
- [ ] 2.2 Implement `parse_subject_schema(&Value)` (missing `schemaType` → Avro, unknown → `Other`, references parsed,
      missing `id`/`version` → error) and `parse_compatibility_level(&Value)` (`compatibilityLevel` or
      `compatibility`). Verify: unit tests with captured Confluent bodies for Avro, PROTOBUF, JSON, an unknown type,
      references, and a malformed body.
- [ ] 2.3 Implement the Avro and JSON Schema field walkers of `schema_fields` (design D5): named types across
      references, optional unions, arrays/maps, `properties`/`items`/`allOf`/`anyOf`/`oneOf`, local and reference
      `$ref`, recursion marker, depth 32 / 5 000 entry limit with `truncated`, paths via
      `json_path::build_canonical_path`. Port the cases of `test/.../schema_controller_test.dart`
      (`parseSchemaFields`) to Rust tests. Verify: `cargo test -p kafkalyzer-core schema_model` passes, including a
      recursive Avro record, a JSON Schema `$defs` cycle, an unresolved `$ref`, and a property `a.b` that yields a
      JSON Pointer path.
- [ ] 2.4 Implement the Protobuf walker (top-level scan, first message for paths, `messages` list, `repeated`, nested
      messages, enums as leaves, `unavailable_reason` on parse failure) and keep the S2 test as a regression test.
      Verify: `cargo test -p kafkalyzer-core schema_model::proto` passes, and proto2 yields `unavailable_reason`
      without a panic.
- [ ] 2.5 Move the suffix rule of `resolve_associated_topics_for_subject` into core and add
      `associate_subjects(subjects, topics) -> Vec<SubjectAssociation>` with `side` and `on_cluster`. Verify: unit
      tests for `-key`, `-value`, a name without a suffix, a derived topic missing from the list, and an empty topic
      list.

## 3. Registry I/O (`kafkalyzer-kafka`)

- [ ] 3.1 Add `normalize_registry_base_url` and `RegistryEndpoint` (design D2) with `get_json` as the only GET call
      site (one `allow_read_only_exception` marker), the `REGISTRY_TIMEOUT` client, `shared_runtime()`, and basic
      auth when the username is non-empty. Switch `SchemaProvenance::from_profile` and `create_sr_settings` to the
      normaliser, and set `SrSettingsBuilder::set_timeout(REGISTRY_TIMEOUT)` in `create_sr_settings`. Verify: unit tests
      for trailing slash, missing scheme, path prefix, invalid URL, and segment encoding of `team/orders-value` and
      `:.prod:orders-value` (asserting the built `Url` path).
- [ ] 3.2 Add `SchemaRegistryError` and the status/`reqwest` error mapping (design D3), reusing `classify_tls_failure`
      and `without_url()`, with detail capped at 500 chars. Verify: tests against a local `TcpListener` stub that
      answers 401, 403, 404 with `{"error_code":40401,...}`, 500 with a plain body, a body that never arrives
      (timeout under 11 s), and a URL with `user:secret@` whose error text contains no `secret`.
- [ ] 3.3 Port `fetch_subjects`, `fetch_schema`, `fetch_schema_versions` and `SchemaProvenance::fetch` to
      `RegistryEndpoint`, and route `check_schema_compatibility` through `url()`, the shared client and the status
      mapping (non-2xx → error). Keep its marked `.post(`. Remove every `Runtime::new()` from `schema_registry.rs`.
      Verify: existing tests in `schema_registry.rs` (provenance cache, TLS verification) still pass, a stub returning
      409 to the compatibility POST yields an error, not `is_compatible=false`, and
      `rg 'Runtime::new' rust/kafkalyzer-kafka/src/schema_registry.rs` finds nothing.
- [ ] 3.4 Add `fetch_subject_schema(profile, subject, version)` and `fetch_subject_schema_view` with breadth-first
      reference resolution (dedupe by subject and version, at most 50 fetches, failed references become unresolved) and
      `fetch_global_compatibility` / `fetch_subject_compatibility` (any 404 → `None`). Verify: stub tests for a schema
      with two references sharing a third (fetched once), a failing reference (model still returned, field marked
      unresolved), the subject compatibility 404 `40408` → `None`, and 403 → `Forbidden` error.
- [ ] 3.5 Check that `scripts/check_read_only.sh` passes unchanged and that `scripts/test_check_read_only.sh` passes.
      Verify: both scripts exit 0, and no new `.post(`, `.put(`, `.delete(` or `.patch(` appears in
      `git diff rust/`.

## 4. Bridge

- [ ] 4.1 In `rust/src/api/schema_registry.rs` add DTOs (`SubjectSchemaDto`, `SchemaReferenceDto`, `SchemaKindDto`,
      `SchemaFieldModelDto`, `SchemaFieldEntryDto`, `FieldNoteDto`, `SubjectSchemaViewDto`, `SubjectAssociationDto`,
      `SchemaRegistryErrorDto`/kind) with `From` mappings and the functions `fetch_subject_schema_view`,
      `fetch_global_compatibility`, `fetch_subject_compatibility`, `associate_subjects`. Existing functions keep names
      and parameters, with the error type per the S1 decision. Verify: `cargo build` and `cargo test` in `rust/` pass.
- [ ] 4.2 Run `flutter_rust_bridge_codegen generate` and `dart run build_runner build`. Verify: `lib/src/rust/**` and
      `test/src/rust/api/rust_mocks.mocks.dart` are regenerated, and `flutter analyze` shows no new errors.

## 5. Dart services and controller

- [ ] 5.1 Extend `SchemaRegistryService` with the new calls, and add `describeSchemaRegistryError(l10n, error)` that
      maps every error kind to ARB text plus status and detail. Add en + de ARB keys for all kinds (credentials
      rejected, access denied, not found, timeout, unreachable, certificate rejected, HTTP error, invalid response,
      invalid URL, not configured). Verify: `test/src/services/schema_registry_service_test.dart` covers the delegation, a
      new unit test covers each kind in en and de, and `test/l10n/arb_consistency_test.dart` passes.
- [ ] 5.2 Extend `SchemaController` (design D7): `fetchSubjectSchemaView` with its cache and `schemaTypeFor`
      (known / not loaded / failed), compatibility getters, the memoised `associatedTopics`, and `fetchSchemaFields`
      backed by the field model with `Logger` instead of `debugPrint` and no cached failures. Remove
      `parseSchemaFields` and its helpers. Verify: `schema_controller_test.dart` is updated and covers a Protobuf and
      a JSON Schema topic returning paths, failure → `[]` without a cache entry, the type state transitions, and
      association recomputed only when the subject or topic list changes.

## 6. Inspector, labels, copy and save

- [ ] 6.1 `TopicSchemaInspectorView`: load `SubjectSchemaView` per side. Avro → `simplifyAvroSchema`. JSON Schema and
      Protobuf → a display map built from `fields`, keeping the `name : Type` key format. Show the notice and raw text
      for `unavailable_reason`, an unsupported type or a failed simplify. Use a type-neutral empty state (replace
      `noAvroSchemaFound`) and `describeSchemaRegistryError` in the error state. Verify: widget tests in
      `topic_schema_inspector_view_test.dart` for a JSON Schema topic (shows `customer` → `name`, not `object`), a
      Protobuf topic (repeated marker), a proto2 schema (notice and raw text), a 401 error (credentials text, no
      "no schema"), and pin/filter of a nested Protobuf field yielding `customer.name`.
- [ ] 6.2 Section header: type · version · id, compatibility (effective value, "set on subject" / "inherited", unknown
      with reason), reference chips opening `SchemaViewerDialog` at the referenced subject and version, a Protobuf
      message list when there is more than one. Icon-only controls get a tooltip and a semantic label. Verify: widget
      tests for inherited, subject-set and 403-unknown compatibility, and for a reference tap opening the dialog with
      the referenced subject and version.
- [ ] 6.3 Copy and Save per schema: clipboard + SnackBar; `FilePicker.saveFile` with `<subject>-v<version>.<ext>`
      (`.avsc`/`.json`/`.proto`; unknown type → `.txt`) and the existing completion affordance; cancel shows nothing,
      a write error shows an error. Verify: widget tests for copy content, proposed file name per type, cancel, and a
      write failure.
- [ ] 6.4 Labels: replace `TopicTag("Avro")` in `topic_detail_view.dart` and the `"Avro"` literals in
      `topic_list_item.dart` with labels from `schemaTypeFor` (type per side, neutral "Schema" while not loaded,
      unknown when the subject list failed), all through ARB. Verify: `topic_detail_view_test.dart` and a
      `topic_list_item` test cover Protobuf, mixed key/value types, not loaded and failed, and
      `rg '"Avro"' lib/src/features/topic` finds nothing.

## 7. Subject browser and associations

- [ ] 7.1 `SchemaViewerDialog`: make `topicName` optional and add `initialSubject`/`initialVersion`. Show associated
      topics with `on_cluster` handling (design D9) and a back action after following a reference. Pass
      `onNavigateToTopic` into `SchemaDiffDialog` and show `_loadAssociatedTopics` failures as an error with retry.
      Verify: `schema_viewer_dialog_test.dart` and `schema_diff_dialog_test.dart` cover opening by subject, opening an
      existing associated topic (dialog closes, topic tab opened with the loaded metadata), a missing topic without
      an open action, and an association failure showing retry.
- [ ] 7.2 New `SubjectBrowserList` widget: filter (case-insensitive substring, computed once per input change),
      "n of m" counter (unknown on failure), global compatibility header, refresh keeping the old list, loading,
      error with `describeSchemaRegistryError` and retry, "no registry configured" with a settings action, "no match"
      distinct from "registry empty", `ListView.builder`, and the associated topic and side per row from the
      memoised batch. Verify: widget tests for each state, and a test with 10 000 subjects asserting one
      `associateSubjects` call and that filtering does not call the bridge.
- [ ] 7.3 `explorer_view.dart`: a keyboard-reachable "Topics | Subjects" `SegmentedButton` under the cluster list,
      with semantic labels, swapping the topic list area for `SubjectBrowserList`. The topic filter text is kept when
      switching back. Activating a subject opens `SchemaViewerDialog` with `initialSubject`. Verify: a widget test
      switches modes, opens a subject, and checks that the navigation rail still has four destinations.
- [ ] 7.4 Add all new en + de ARB keys of groups 6 and 7 (type names, labels, compatibility texts, copy/save, browser
      states, switch labels), and remove `noAvroSchemaFound` if it is unused. Verify:
      `flutter test test/l10n/` passes (`arb_consistency_test.dart`, `hardcoded_strings_guard_test.dart`) with no new
      allowlist entries other than technical identifiers (compatibility level values, file extensions).

## 8. Final verification

- [ ] 8.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets` (no new warnings),
      `cargo test --workspace`. Verify: all three exit 0.
- [ ] 8.2 `flutter_rust_bridge_codegen generate` and `dart run build_runner build` leave no diff. Then
      `dart format .`, `flutter analyze` and `flutter test`. Verify: no diff after regeneration, analyzer clean, all
      tests pass.
- [ ] 8.3 `scripts/check_read_only.sh` and `scripts/test_check_read_only.sh`. Verify: both exit 0 with no new
      exception.
- [ ] 8.4 Manual check against `docker-compose.yaml` with a Schema Registry: register (outside the app, with curl)
      one Avro, one JSON Schema and one Protobuf subject with a reference, plus one subject named `com.acme.Customer`.
      In the app, check labels, field trees, pin/filter, reference navigation, compatibility (set and inherited),
      copy and save, subject search and the associated-topic jump, and a wrong password (401 text). Verify: the
      results are noted in the PR description.
