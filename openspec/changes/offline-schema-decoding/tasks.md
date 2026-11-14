# Tasks

Prerequisite: 5.35 `schema-type-awareness-and-subject-browser` is implemented (`kafkalyzer_core::schema_model`,
`protofish` in core, field-model display). Preferred order: 5.37 and 5.9 tasks 3.1–3.3 land first (see proposal).

## 1. Spikes

- [ ] 1.1 Spike S1 (design D2): in a `#[test]` in `kafkalyzer-kafka`, encode prefixed Protobuf payloads with index
      lists `[0]` (single `0x00`), `[1]`, `[1, 0]`, `[0, 2, 1]` against a proto3 file with nested messages and an enum
      between them. Resolve each index path with the planned rule (top-level scan from 5.35 + `inner_types` filtered
      to messages) and compare it with `schema_registry_converter::proto_resolver::MessageResolver::find_name`.
      Feed truncated and over-long varint lists to confirm the planned parser never panics. Record the result here.
      Verify: both resolvers agree for every path, and the test is kept as a regression test in task 2.4.
- [ ] 1.2 Spike S2 (design D3): produce `protoc --include_imports --descriptor_set_out` files for (a) two proto3 files
      where one imports the other, with `map<string,int64>`, `oneof`, a nested message and an enum, and (b) one proto2
      file with `required` and a default value. Check these in as test fixtures under
      `rust/kafkalyzer-core/tests/fixtures/`. Try option (a): decode them with `protofish` and an embedded proto3
      subset of `descriptor.proto`, synthesize proto3 text per file, and `Context::parse` all files together. Confirm
      that cross-file type references resolve without `import` lines and that map entries come out as `map<K,V>`.
      Record option (a) or the fallback `prost-types` here. Verify: the decision and the fixture list are written
      under 1.2, and no throwaway code is left outside the kept test.

## 2. Core: local schema decoding (`kafkalyzer-core`)

- [ ] 2.1 Move `convert_protofish_message` / `convert_protofish_value` from `kafkalyzer-kafka/src/kafka_consumer.rs` to
      `kafkalyzer-core` (module `local_schema` or a shared `proto_json` module) unchanged, and call it from the registry
      path. Verify: a new core test pins the JSON for scalars, repeated, packed, nested, enum and unknown fields, and
      `cargo test -p kafkalyzer-kafka` stays green.
- [ ] 2.2 Create `local_schema.rs` (exported in `lib.rs`) with `LocalSchemaFormat`, `Framing`, `LoadedLocalSchema`,
      `LocalDecodeError(Kind)`, `load_local_schema` and `guess_format`. Avro: `Schema::parse_str`. JSON Schema: JSON
      parse plus a field model through `schema_model`. Proto source: `Context::parse`, top-level scan (5.35), message
      list, `UnsupportedProto2` / `UnresolvedImport` / `MessageTypeNotFound`. Verify: unit tests for a valid and an
      invalid file of each format, a proto2 source, a source with `import`, an unknown message type, and
      `guess_format` for `.json` Avro vs JSON Schema.
- [ ] 2.3 Implement `decode_with_local` for Avro and JSON (design D2): prefix detection, Avro `Auto` with the
      prefixed-then-raw fallback, `Prefixed` / `Raw`, the strict end-of-buffer check (`TrailingBytes`), `NotJson`,
      and `wire_schema_id` / `framing_used` in the result. Verify: unit tests for a prefixed Avro record (id 42), a raw
      record, a raw record starting with `0x00`, forced `Prefixed` without prefix, trailing bytes, a prefixed JSON
      document, and non-JSON bytes.
- [ ] 2.4 Implement Protobuf decoding: a non-panicking message-index parser (count cap 32, negative index rejected),
      index-path resolution, raw payloads with the selected type, `garbage` → `PayloadMismatch`, unknown fields kept.
      Keep the S1 test as a regression test. Verify: unit tests for `[0]`, `[1,0]`, an index not in the schema, a
      malformed list, a raw payload, a mismatching payload, and a payload with an unknown field number.
- [ ] 2.5 Implement the descriptor-set path (design D3, per the S2 decision): descriptor bytes → proto3 text per file →
      the same `Context` as `.proto` sources. Groups and extensions give `SchemaInvalid` naming the element. Verify:
      tests with the S2 fixtures decode a message whose field type is defined in the imported file, a `map`, a
      `oneof` and the proto2 message. If the fallback is used, `cargo tree -p kafkalyzer-core` shows only
      `prost`/`prost-types` added, and the crate still has no rdkafka, reqwest or flutter_rust_bridge.
- [ ] 2.6 Extend 5.35's Protobuf field walker with an optional message name (default: first top-level message), and add
      `LocalSchemaAssignment`, `TopicLocalSchemas`, `LocalSchemaUse` to `kafka_types.rs`, plus the additive
      `KafkaMessage.key_local_schema` / `value_local_schema` and `TopicAnalysisOptions.local_schemas`
      (`#[serde(default)]`). Verify: a field-model test for a second message type, and a serde test that an options
      JSON without `local_schemas` still deserialises.

## 3. Kafka crate: loading and decode integration (`kafkalyzer-kafka`)

- [ ] 3.1 Add `local_schema_loader.rs`: regular-file check, 10 MiB cap, a single `std::fs::read`, SHA-256, file name
      only in errors and provenance, and I/O errors mapped to `FileNotFound` / `FileUnreadable` / `FileTooLarge`.
      Verify: tests with a temp dir cover a missing file, a directory, an over-size file (sparse file), and a valid
      `.avsc`, and no log line contains the file contents.
- [ ] 3.2 On top of 5.9's `decode_component` (or doing that merge first as specified in 5.9 design D5, if 5.9 has not
      landed), add `decode_side` with the precedence of design D4 (`Fallback` / `Always`, `registry_has_subject`,
      prefix, resolvable id). The raw rendering is kept on failure and `LocalSchemaUse` is filled. Verify: unit tests
      with a mock message and `decoders = None`: no registry + local Avro → decoded; local failure → the same raw text
      as before plus an error; no assignment → output byte-identical to the 5.9 regression fixtures. A stub-registry
      test shows that `Fallback` uses the registry when the subject exists and the id resolves, and `Always` uses the
      local schema.
- [ ] 3.3 `consume_with_filter`: new `local_schemas: Option<TopicLocalSchemas>` parameter. Load each side once before
      `create_consumer`, log a load error once via `log_to_dart`, and pass the sides to `process_and_send_message`
      (or the `LazyMessage` cells of 5.9). Verify: a test counts loader calls (one per side per scan, not per
      message), and a scan whose file is missing still emits every message with a `FileNotFound` provenance error.
- [ ] 3.4 `analyze_topic_content`: read `options.local_schemas`, load once, share the loaded schemas via `Arc` across
      workers, switch the three decode call sites to `decode_side`, decode keys locally when assigned, and add the
      content types `"<Kind> (local schema)"` and `"Local schema decode failed"`. Verify: accumulator tests show field
      statistics from locally decoded Avro values, the failure content type count, and an unchanged report for
      options without `local_schemas`.
- [ ] 3.5 Run `scripts/check_read_only.sh` and `scripts/test_check_read_only.sh`. Verify: both exit 0, and
      `git diff rust/` adds no `reqwest` call, no `.post(`/`.put(`/`.delete(` and no new
      `allow_read_only_exception`.

## 4. Bridge

- [ ] 4.1 Add `rust/src/api/local_schema.rs` with DTOs (`LocalSchemaFormatDto`, `FramingDto`, `LocalSchemaModeDto`,
      `LocalSchemaAssignmentDto`, `TopicLocalSchemasDto`, `LocalSchemaUseDto`, `LocalSchemaErrorDto` with kind and
      detail, `LocalSchemaInfo` reusing 5.35's `SchemaFieldModelDto` / `SchemaKindDto`) and `From` mappings. Add
      `inspect_local_schema(path, format, message_type)`, which returns errors in `error` and never throws for file or
      schema problems. Add `local_schemas` to bridge `consume_with_filter`, the local fields to `KafkaMessage`, and the
      field to `TopicAnalysisOptions` in `kafka_types.rs`. Verify: `cargo build` and `cargo test` in `rust/` pass, and a
      unit test maps every error kind.
- [ ] 4.2 Run `flutter_rust_bridge_codegen generate` and `dart run build_runner build`. Verify: `lib/src/rust/**` and
      `test/src/rust/api/rust_mocks.mocks.dart` are regenerated, existing `KafkaMessage(...)` constructions compile
      unchanged, and `flutter analyze` shows no new errors.

## 5. Dart: persistence and scan wiring

- [ ] 5.1 Add `LocalSchemaAssignmentService` (design D6): key `local_schema_assignments_<cluster>_<topic>`, get, save
      and remove per side, unreadable data kept and reported, `scanOptionsFor`, `stateFor` via `inspect_local_schema`
      (cached until refresh or dialog save), and confirm-changed (update sha256). Register it in
      `dependency_injection.dart`. Verify: `test/src/services/local_schema_assignment_service_test.dart` covers the
      round trip, cluster isolation (same topic on two clusters), the restart (new instance on the same prefs),
      unreadable data kept after an unrelated save, and every state, using a mocked bridge.
- [ ] 5.2 Pass `localSchemas: service.scanOptionsFor(...)` at all four call sites: `message_stream_controller.dart`,
      `multi_search_controller.dart` (and its `MessageConsumeStreamFactory` typedef; coordinate with 5.9),
      `topic_partition_table.dart` and `topic_analysis_controller.dart` (`TopicAnalysisOptions.localSchemas`). Verify:
      controller tests with a fake factory assert the forwarded assignment for a topic with and without one, and a
      `ScriptRunner` test (headless setup as in `test/main_headless_test.dart`) shows a script step forwarding it.
- [ ] 5.3 Provenance in exports and results: add `localSchemaUseToMap` / `FromMap` and the keys
      `keyLocalSchema` / `valueLocalSchema` in `message_export_service.dart` and `search_json_serializer.dart`. Verify:
      `message_export_service_test.dart` and a serializer test cover the round trip and loading an old file without
      the keys.
- [ ] 5.4 `SchemaController.fetchSchemaFields`: use the local field model per the precedence in design D6, keeping its
      signature. Verify: `schema_controller_test.dart` covers no registry + local Protobuf → fields of the selected
      message, `Always` → local fields, and `Fallback` with registry fields → registry fields.

## 6. Dart: UI

- [ ] 6.1 `LocalSchemaAssignmentDialog` (design D6): file picker with allowed extensions, format selector defaulted
      from the extension or `guess_format`, message type dropdown, framing (Avro only), mode, preview or error, Save
      disabled while invalid, and Remove. Verify: widget tests cover an Avro preview, Protobuf with two message types
      (Save disabled until one is chosen), a proto2 source (error plus descriptor-set hint), a picker cancel (nothing
      changes), and Remove.
- [ ] 6.2 `TopicSchemaInspectorView`: a local-schema card per side with state, actions and the field structure through
      5.35's display path, also in the "registry not configured" and "no schema registered" states. Topic header
      `TopicTag` "Local: <type>" with an error icon for non-usable states, opening the dialog. Verify: widget tests cover
      the no-registry state offering "Assign local schema", a usable Avro card showing fields, `fileNotFound` showing the
      reason with no field tree, `changed` with Confirm, and the header tag.
- [ ] 6.3 Message inspector provenance line and message card indicator for local schemas, with
      `describeLocalDecodeError(l10n, kind, detail)` covering every error kind. Analysis view notice for local
      decoding. Verify: widget tests in `message_inspector_panel` / `message_metadata_card` tests cover a decoded
      value (file name, type, id), a failed decode (raw content plus reason, no "no registry schema" text), and a
      card with `V: local` and no key placeholder; a unit test covers every error kind in en and de.
- [ ] 6.4 Add all new en + de ARB keys (dialog, states, modes, framing, provenance, error kinds, analysis notice).
      Verify: `flutter test test/l10n/` passes (`arb_consistency_test.dart`, `hardcoded_strings_guard_test.dart`) with
      no new allowlist entries other than file extensions.
- [ ] 6.5 README: describe local schema files (formats, descriptor-set command line, precedence, machine-local paths
      for headless runs). Verify: the README section exists, and the `protoc` command in it produces a file that
      `inspect_local_schema` accepts (checked once by hand with an S2 fixture).

## 7. Final verification

- [ ] 7.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets` (no new warnings),
      `cargo test --workspace`. Verify: all three exit 0.
- [ ] 7.2 `flutter_rust_bridge_codegen generate` and `dart run build_runner build` leave no diff. Then `dart format .`,
      `flutter analyze` and `flutter test`. Verify: no diff after regeneration, analyzer clean, all tests pass.
- [ ] 7.3 `scripts/check_read_only.sh` and `scripts/test_check_read_only.sh`. Verify: both exit 0 with no new
      exception.
- [ ] 7.4 Manual check against `docker-compose.yaml`. With no registry in the profile: produce (outside the app) a
      Confluent-framed Avro topic, a raw Avro topic, a framed Protobuf topic with index `[1]`, and a framed JSON topic.
      Assign `.avsc`, `.desc` and JSON Schema files. Check decoding, provenance, analysis fields, a script step (GUI and
      `--script`), a deleted file (raw + reason, scan completes), an edited file (changed state), and with the registry
      re-enabled the `Fallback` vs `Always` behaviour. Verify: the results are noted in the PR description.
