# Proposal: structured-message-filter

Roadmap: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.9 (size L), decision E5, guardrails L1–L7,
§2.2 ("Regex-Filter auf Keys, Values und Headern"), §2.3 item 2, §6.4 (Phase 2 acceptance).

## Why

The broker-side scan can only match text terms (Contains / Regex / Exact) against the serialized key or value, with at
most one field path. Users cannot state precise conditions such as `value.status == "FAILED" AND value.amount > 100`,
cannot filter by header, partition, offset or timestamp, and cannot combine conditions. The header gap also blocks
5.14 `cross-topic-trace` (trace IDs travel in headers) and the MCP follow-up `mcp-extended-tools`, which need the same
filter in Rust. E5 fixes the language: a small predicate tree in `kafkalyzer-core`, paths only via `json_path` (L7).

## What Changes

- New module `kafkalyzer_core::filter_expr`: hand-written lexer and recursive-descent parser, AST, canonical text
  formatter, compiler (regexes, ISO timestamps, script placeholders resolved once) and evaluator. No new third-party
  crate in the workspace; `chrono` (already used by `kafkalyzer-kafka`) is added to `kafkalyzer-core` for ISO-8601
  timestamp literals.
- Conditions `<source>[.<path>] <op> <literal>` and `<source>[.<path>] exists`, combined with `AND`, `OR`, `NOT` and
  parentheses. Sources: `key`, `value`, `header.<name>`, `partition`, `offset`, `timestamp`. Operators: `==`, `!=`,
  `<`, `<=`, `>`, `>=`, `contains`, `matches` (regex), `exists`. Typed comparison with fixed coercion rules; an
  unresolvable path or unknown value makes the condition false, never an error.
- `kafkalyzer-kafka::consume_with_filter` takes an optional compiled expression. It is parsed and compiled before the
  poll loop; an invalid expression rejects the scan before any message is read. Evaluation reads key, value and
  headers lazily, so an expression that does not reference `value` does not decode the payload of non-matching
  messages. Legacy terms (`FilterType`, `filter_field`, `SearchScope`) keep their behaviour; when both are given a
  message must satisfy both.
- Bridge (additive, L3): two optional parameters on `consume_with_filter` (`filter_expression`, `filter_variables`),
  new functions `parse_filter_expression` (sync; returns AST or a localizable error with position),
  `format_filter_expression` (sync; canonical text) and `collect_field_paths` (field suggestions from loaded messages).
- Dart: one expression editor widget with two lossless modes — condition builder (groups and chips) and text — used in
  the topic search bar, the Search Configuration panel and the script step editor. Field suggestions come from the
  topic's schema, else from a loaded topic analysis, else from loaded messages.
- Persistence (additive): `TopicSearchPreset.filterExpression` and `ScriptStep.filterExpression` store the canonical
  text. Old presets and scripts load unchanged. Script variables (`{{name}}`) can be used as literals; multi-value
  variables match if any value matches; an unknown variable fails the step instead of being sent literally.
- README: the "Regex Support … or headers" claim becomes true for expressions; the line is rewritten accordingly.

## Capabilities

### New Capabilities

- `structured-message-filter`: filter expression language (grammar, sources, operators, typing, canonical text),
  compile-once/validate-before-start contract, lazy evaluation, builder/text editor, field suggestions, persistence
  in presets and script steps, script placeholders.

### Modified Capabilities

- `topic-consumption`: *Pre-compiled Filter Evaluation* covers filter expressions; *Progressive Disclosure for
  Advanced Topic Search Filters* adds the expression editor and its collapsed chip; *Match Diagnostics Without
  Payload Echo* defines the diagnostic for an expression match.
- `saved-topic-searches`: *Persistent Topic Search Presets* also captures the filter expression; presets without it
  load unchanged.

Not modified (checked): `search-configuration-panel` — the roadmap lists it, but none of its requirements (collapse,
title, Fast Trace preview) change; the editor's UI requirements live in `structured-message-filter`.
`json-path-resolution` — *One Resolver For All Field Path Features* already demands that broker-side filtering uses
the same resolver; expressions comply without a delta. `headless-script-execution` — already requires variable
substitution in step filters; the expression-specific placeholder rules are in the new capability.

## Impact

- Rust: `rust/kafkalyzer-core/src/filter_expr.rs` (new), `json_path.rs` (`collect_paths`), `Cargo.toml` (`chrono`);
  `rust/kafkalyzer-kafka/src/kafka_consumer.rs` (lazy message view, expression in `run_poll_loop`); bridge
  `rust/src/api/kafka_consumer.rs`, new `rust/src/api/filter_expr.rs`, `rust/src/api/json_path.rs`; regenerated
  `lib/src/rust/**`, `rust/src/frb_generated.rs`, `test/src/rust/api/rust_mocks.mocks.dart`.
- Dart: `lib/src/features/search/**` (new `domain/filter_expression*.dart`, new
  `presentation/widgets/filter_expression_editor.dart`, `topic_search_bar.dart`, `search_stream_configuration.dart`,
  `multi_search_controller.dart`, `search_json_serializer.dart`, `models/topic_search_preset.dart`),
  `lib/src/features/topic/topic_detail_view.dart`, `message_stream_controller.dart`,
  `lib/src/features/scripting/domain/script.dart` (+ freezed/json regen), `script_runner.dart`,
  `script_step_editor.dart`, `lib/l10n/app_en.arb`, `app_de.arb`, `README.md`.
- **Read-only impact: no new Kafka or Schema Registry calls.** Scans use the existing `assign()` consumer. Schema
  field suggestions reuse the existing read-only GET of `SchemaController.fetchSchemaFields`
  (`/subjects/<topic>-value/versions/latest`). `scripts/check_read_only.sh` passes unchanged.
- Prerequisites: none hard. Phase 0/1 changes are archived (stream errors are surfaced — B4 — so a rejected
  expression is visible). Soft dependency: 5.35 `schema-type-awareness-and-subject-browser` makes
  `fetchSchemaFields` type-correct for Protobuf/JSON Schema; without it, suggestions fall back to analysis or loaded
  messages. Sibling 5.27 `message-selection-copy-and-display` owns the in-memory quick filter over loaded messages; this
  change is the broker-side scan filter only. New UI strings must pass `test/l10n/hardcoded_strings_guard_test.dart`.
- Unblocks: 5.14 `cross-topic-trace` (header source), `mcp-extended-tools` (expression as tool parameter).

## Non-goals

- Aggregations, joins, projections, user-defined or built-in functions (§5.9).
- CEL, JMESPath, JSONPath filter expressions, wildcards or a second path syntax (E5, L7, §7).
- Changing or removing the legacy filter (`FilterType`, `filter_field`, `SearchScope`) or its UI.
- Applying expressions to the topic analysis value filter (`topic-analysis-value-filter`) or the in-memory quick
  filter over loaded messages (5.27 / live-tail-controls).
- Fast Trace derived from an expression: Fast Trace keeps using the first quick-filter term.
- New script step kinds, conditions or scheduling (§7).
- Any write access to Kafka or the Schema Registry (L1).
