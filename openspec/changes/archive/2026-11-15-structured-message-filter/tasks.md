# Tasks

## 1. Spikes

- [x] 1.1 Spike S1 (design D7): in a throw-away branch add a recursive `FilterNode` enum (`And(Vec<FilterNode>)`,
      `Or(Vec<FilterNode>)`, `Not(Box<FilterNode>)`, `Cond(FilterCondition)`) and a `#[frb(sync)]` echo function to
      `rust/src/api/`, run `flutter_rust_bridge_codegen generate` and `flutter analyze`. Verify: codegen succeeds and a
      Dart test round-trips a 3-level tree; otherwise record the failure in design.md and switch D7 to the flat-node
      fallback. Revert the spike code.
- [x] 1.2 Spike S2 (design Risks): add an `#[ignore]` benchmark test in `rust/kafkalyzer-core` that evaluates 100k
      synthetic messages (1 KB and 50 KB JSON) with legacy-style Contains on pretty text vs a hand-coded prototype of
      `FieldPath` lookup on `serde_json::from_slice`. Verify: `cargo test --release -p kafkalyzer-core -- --ignored
      bench_` prints msg/s; record the numbers and the 50k msg/s target result in design.md. Keep the test; it is
      re-pointed to the real evaluator in 2.6.

## 2. kafkalyzer-core: `filter_expr`

- [x] 2.1 Add `chrono = { version = "0.4", default-features = false, features = ["std"] }` to
      `rust/kafkalyzer-core/Cargo.toml` (same crate/version as `kafkalyzer-kafka`; no new crate in `Cargo.lock`) and
      create `filter_expr.rs` registered in `lib.rs`. Verify: `cargo build -p kafkalyzer-core` and
      `git diff rust/Cargo.lock` shows no new package.
- [x] 2.2 Implement lexer and recursive-descent parser per design D2 (case-insensitive keywords, bare/quoted paths
      validated with `json_path::FieldPath::parse`, bare/quoted header names, JSON string escapes and number grammar,
      placeholders, depth limit 64, length limit 65,536) producing the normalized AST of D3 and `FilterError` with
      `kind`/`byte_offset`/`len`. Verify: unit tests for every spec scenario of *Filter Expression Structure*,
      *Condition Sources*, *One Path Language In Expressions* and the error positions (e.g. unexpected end at column
      29, `*` in a path, `payload` as source, `(` of a function call, 65 nested parentheses → TooComplex, no panic).
- [x] 2.3 Implement the canonical formatter (design D3). Verify: unit tests for the *Canonical Text Form* scenarios,
      a table of non-canonical inputs, and a deterministic generated-tree test asserting `parse(format(t)) == t`.
- [x] 2.4 Implement `compile(ast, bindings)` (design D4/D6): regexes, RFC 3339 timestamps (offset required), number
      literals (`i128`/`f64`), operator/source checks (`contains`/`matches` only on key/value/header, ordering not on
      booleans), placeholders with any/none semantics and the 10,000-alternative limit, unknown/non-numeric variable
      errors. Verify: unit tests for *Comparison Operators* and *Timestamp Literals* rejection scenarios, *Script
      Variables In Expressions* (quote in value, multi-value `==`/`!=`, non-numeric, unknown) and *Expression Size
      Limits* (200×200 alternatives).
- [x] 2.5 Implement the evaluator over a `MessageView` trait with short-circuit `AND`/`OR`/`NOT` (design D4). Verify:
      unit tests with an in-memory `MessageView` for *Typed Comparison* (150 / "150" / "n/a", `"007"` vs 7,
      9007199254740993 exact, `!=` on mismatch), *Unresolvable Values Make A Condition False* (missing field, non-JSON,
      JSON null, unknown timestamp, `NOT`), *Header Conditions* (repeated, quoted name, null value), and a counting
      `MessageView` proving `partition == 3 AND value…` never reads the value for partition 0.
- [x] 2.6 Add `json_path::collect_paths(value, limit)` returning canonical paths via `build_canonical_path` (objects
      recursed, arrays as index 0 only, capped). Re-point the S2 benchmark to the real evaluator. Verify: unit tests for
      nested objects, arrays, unsafe keys (JSON Pointer form) and the cap; the benchmark result meets or is recorded
      against the target in design.md.

## 3. kafkalyzer-kafka: scan integration

- [x] 3.1 Refactor the duplicated Schema Registry branch of `decode_message_component`/`decode_message_to_value` into
      one `decode_component` (design D5) without changing output. Verify: new regression tests pin the emitted text
      for registry JSON, plain JSON, UTF-8 text and binary inputs (rendering part, no broker), and existing
      `kafka_consumer` tests pass.
- [x] 3.2 Implement `LazyMessage` (`MessageView` with `OnceCell` per component, headers on demand, timestamp without
      the `0` fallback) and evaluate the compiled expression first in `process_and_send_message`, then the unchanged
      `matches_filter` on the same cells; emission reuses the cells. Verify: unit tests with a mock `KafkaMessageTrait`
      message showing a key-only expression does not call the value decoder for non-matching messages, and that
      legacy-only scans give identical `FilterOutcome`s as before (existing `test_matches_filter_*` stay green).
- [x] 3.3 Add `filter_expression: Option<CompiledExpr>` to `consume_with_filter`/`run_poll_loop`; compile before
      `create_consumer` in the caller so an invalid expression fails without a broker connection; log the canonical text
      once at start and `expression` as the match diagnostic marker. Verify: unit test that an invalid expression
      returns `Err` with kind and offset; `cargo test -p kafkalyzer-kafka`; manual scan against `docker-compose.yaml`
      with `header.eventType == "…"` returns only matching messages.

## 4. Bridge and code generation

- [x] 4.1 Add `rust/src/api/filter_expr.rs` with the DTOs and `parse_filter_expression` / `format_filter_expression`
      (`#[frb(sync)]`, UTF-16 offsets) per design D7 (or the S1 fallback), `collect_field_paths` in
      `rust/src/api/json_path.rs`, and `filter_expression`/`filter_variables` on `consume_with_filter` (compile with
      bindings, map errors to a readable message incl. column). Verify: Rust unit tests for DTO ↔ AST mapping and UTF-16
      offset conversion with a non-ASCII literal before the error; `cargo test --workspace`.
- [x] 4.2 Run `flutter_rust_bridge_codegen generate` and `dart run build_runner build` (bridge mocks;
      run `build_runner` again in 5.1 for `ScriptStep`). Verify: `flutter analyze` is clean and the three existing
      `consumeWithFilter` call sites compile unchanged.

## 5. Dart: models, persistence, scripts

- [x] 5.1 Add `filterExpression` to `TopicSearchPreset` (JSON key, default `''`, `copyWith`) and `ScriptStep`
      (`String?`), regenerate freezed/json. Verify: tests that a preset JSON and a script JSON without the key load
      with an empty expression and all other values unchanged, and that saving then loading keeps the text.
- [x] 5.2 Add `filterExpression`/`filterVariables` to `SearchTarget` (equality/hash), pass them through
      `MultiSearchController` and `MessageStreamController` stream factories, and write `filterExpression` in
      `SearchJsonSerializer.serializeTarget`. Verify: controller tests with a fake stream factory assert the values are
      forwarded; serializer test asserts the key.
- [x] 5.3 In `ScriptRunner`, pass the step expression and the referenced variables (split on `,`, trimmed, empties
      dropped — same rule as `_expandMultiValueFilter`) to the target; an expression error fails the step with the
      error. Verify: script runner tests for an old script (unchanged behaviour), a header expression, a multi-value
      variable, and an unknown variable failing the step; `headless_script_runner_test.dart` covers `--var ids=A1,B2`.

## 6. Dart: expression editor and integration

- [x] 6.1 Add a Dart mirror of the AST plus `FilterExpressionEditingController` (mode, text, tree, error; debounced
      validation through `parseFilterExpression`; text→builder only when valid; builder→text through
      `formatFilterExpression`). Verify: unit tests for round trips of the *Builder And Text Modes* scenarios with a
      mocked bridge, including the literal type `"42"` vs `42` and the invalid-text block.
- [x] 6.2 Build `FilterExpressionEditor` (text field with inline localized error and column marker; builder with
      groups, AND/OR switch, negate toggles, condition chips and chip editor with source/path/operator/typed literal)
      using `package:material_ui`, tooltips and semantic labels. Verify: widget tests for building
      `(header.type == "A" OR header.type == "B") AND NOT offset < 100`, mode switching, error display, and semantics
      labels on icon controls.
- [x] 6.3 Add field suggestions (design D9): schema via `fetchSchemaFields`, else analysis `fieldFrequencies` of the same
      topic, else `collectFieldPaths` over at most the last 200 loaded messages; header names from loaded headers;
      source label and "no suggestions available" state. Verify: widget tests for each source and the empty state with
      fakes; no bridge call per keystroke beyond the debounced validation.
- [x] 6.4 Integrate the editor into `TopicSearchBar` (advanced panel, collapsed chip with ellipsis/tooltip/invalid icon,
      start gating next to the regex validation) and `TopicDetailView`. Verify: widget tests for the *Progressive
      Disclosure* expression chip scenario and that an invalid expression blocks `onStart`.
- [x] 6.5 Integrate the editor into `SearchStreamConfiguration` (script step editor) including save/apply of presets
      with `filterExpression` and the invalid-stored-expression case. Verify: extend
      `search_stream_configuration_preset_test.dart` for the three new *Persistent Topic Search Presets* scenarios.
- [x] 6.6 Add all new strings (editor labels, mode names, operator names, error kinds with column, suggestion sources,
      chip texts, placeholder hint) to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`. Verify:
      `test/l10n/arb_consistency_test.dart` and `test/l10n/hardcoded_strings_guard_test.dart` pass without new
      allowlist entries.
- [x] 6.7 Update `README.md` (filter section: header filtering via expressions, short grammar example; remove the
      "regex … headers" claim). Verify: the README example expression is accepted by a parser unit test (copy into the
      2.2 test table).

## 7. Final verification

- [x] 7.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets` (no warnings), `cargo test --workspace`.
- [x] 7.2 `flutter_rust_bridge_codegen generate` and `dart run build_runner build` produce no further diff; `dart
      format .` clean; `flutter analyze` clean; `flutter test` green.
- [x] 7.3 `scripts/check_read_only.sh` passes unchanged (no new exception), and a manual run against
      `docker-compose.yaml` confirms: header/metadata/value expressions, a legacy-only search identical to before, an
      invalid expression refused with column, a script using `{{var}}` in desktop and headless mode.
