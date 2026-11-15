# Design: structured-message-filter

## Context

See proposal.md (Why). Current state, verified against the working tree:

- `kafkalyzer-kafka::kafka_consumer::consume_with_filter` takes `filter_terms`, `filter_field`, `filter_type`,
  `search_scope`; `run_poll_loop` compiles regexes once (`compile_filter_patterns`) before the loop — the roadmap's
  hot-path concern for the legacy filter is already met.
- `process_and_send_message` decodes **key and value before filtering**, for every message, even for `SearchScope::Key`
  (`decode_message_component` → Schema Registry decode via `block_on` + `to_string_pretty`). With `filter_field`,
  `matches_filter` re-parses that pretty text per message (`json_path::resolve(content, field)`).
- `decode_message_to_value` (JSON value) and `decode_message_component` (text) duplicate the Schema Registry decode
  branch.
- Headers are converted only after a match (UTF-8 text, else `0x<hex>`; a null value becomes `""`). The broker scan
  cannot filter by header (roadmap §2.2 confirmed). The message timestamp is `to_millis().unwrap_or(0)`.
- `kafkalyzer_core::json_path` has `FieldPath::parse/lookup` (pre-tokenized paths), `render_value` semantics
  (strings unquoted, null → none) and `build_canonical_path`. `kafkalyzer-core` already depends on `regex`;
  `chrono` is used by `kafkalyzer-kafka` only.
- Bridge `consume_with_filter` (`rust/src/api/kafka_consumer.rs`): `Option<T>` parameters become optional named Dart
  parameters, so adding `Option` parameters keeps the three Dart call sites (`message_stream_controller.dart`,
  `multi_search_controller.dart`, `topic_partition_table.dart`) compiling. Sync bridge functions exist
  (`#[frb(sync)]` in `profile_tools.rs`).
- Dart: `TopicSearchBar` (topic view; legacy field/type/scope in an advanced panel, regex validation via
  `validateFilterPatterns`, field `Autocomplete` from `SchemaController.fetchSchemaFields`), `SearchStreamConfiguration`
  (used only by the script step editor; owns the saved-preset selector), `TopicSearchPreset` (hand-written JSON, no
  `filterField`), `ScriptStep` (freezed; `filterTemplate`, `filterType`, `scope`; no field), `ScriptRunner`
  (`{{var}}` templating; multi-values split on `,` and expanded into OR-ed terms; an unknown variable is left as the
  literal `{{name}}` — silent).
- `fetchSchemaFields` swallows errors and returns `[]` (5.35 changes that; it keeps the signature).
- `test/l10n/hardcoded_strings_guard_test.dart` and `arb_consistency_test.dart` exist (5.32 in progress).

## Goals / Non-Goals

**Goals:** one grammar, parser, formatter and evaluator in `kafkalyzer-core` usable later by MCP (5.17/
`mcp-extended-tools`) and cross-topic trace (5.14); no per-message parsing; no payload decoding for messages an
expression can reject from metadata, key or headers; lossless builder/text editing; additive persistence.

**Non-Goals (design level):** reordering of conditions by cost (evaluation is left-to-right with short-circuit; users
control order); making the legacy filter lazy; changing the emitted `KafkaMessage` text; an expression cache across
scans.

## Decisions

### D1 Layering

| Piece | Layer | Why |
|---|---|---|
| Lexer, parser, AST, canonical formatter, compiler (regex, ISO timestamp, placeholders, limits), evaluator over a `MessageView` trait | `kafkalyzer-core::filter_expr` | Pure computation, unit-testable, second callers (MCP, 5.14) exist (§6.3 rule 3) |
| `json_path::collect_paths(value, limit)` for suggestions | `kafkalyzer-core::json_path` | Paths must be built by the one path module (L7) |
| Lazy `MessageView` impl over an rdkafka message, decode refactor, evaluation in `run_poll_loop` | `kafkalyzer-kafka` | Needs rdkafka message and Schema Registry decoders |
| DTOs (`FilterNode`, `FilterCondition`, `FilterLiteral`, `FilterParseResult`, `FilterExpressionError`, `FilterVariable`), `parse_filter_expression`, `format_filter_expression`, `collect_field_paths`, new params on `consume_with_filter` | bridge `rust/src/api/filter_expr.rs`, `kafka_consumer.rs`, `json_path.rs` | Orphan rule / L3 |
| Editor state (builder tree, mode), suggestion source precedence, placeholder value splitting, persistence fields | Dart | View state; persistence lives in Dart models |

### D2 Grammar (hand-written recursive descent, no new crate)

```text
expr       := or
or         := and ( OR and )*
and        := unary ( AND unary )*
unary      := NOT unary | primary
primary    := '(' expr ')' | condition
condition  := field ( 'exists' | op literal )
field      := 'key' [ '.' path ] | 'value' [ '.' path ] | 'header' '.' name
            | 'partition' | 'offset' | 'timestamp'
path       := bare-path | string            bare-path: [A-Za-z0-9_$\-.\[\]]+ , not starting with '/'
name       := bare-name | string            bare-name: [A-Za-z0-9_\-.]+
op         := '==' | '!=' | '<' | '<=' | '>' | '>=' | 'contains' | 'matches'
literal    := string | number | 'true' | 'false' | placeholder
string     := '"' ( char | escape )* '"'    escapes: \" \\ \/ \b \f \n \r \t \uXXXX
number     := JSON number grammar (optional '-')
placeholder:= '{{' name '}}'                (numeric placeholder; inside strings "{{name}}" is text interpolation)
```

- Keywords (`AND OR NOT exists contains matches true false` and source names) are case-insensitive. Paths are
  validated with `FieldPath::parse` at parse time (wildcards `*`, `..` are rejected there because they are not path
  characters).
- Alternatives: `nom`/`pest` are in `Cargo.lock` transitively but would be new direct dependencies and give worse
  error positions for this tiny grammar; a Pratt parser is unnecessary with three precedence levels. Hand-written
  recursive descent (~400 lines incl. lexer) with an explicit depth counter (limit 64) avoids stack overflow.
- Errors: `FilterError { kind, byte_offset, len, detail }` with `kind` in {UnexpectedToken, UnexpectedEnd,
  UnterminatedString, InvalidEscape, InvalidNumber, UnknownSource, InvalidPath, OperatorNotAllowed,
  LiteralTypeMismatch, InvalidRegex, InvalidTimestamp, UnknownVariable, NonNumericVariable, TooComplex}. The bridge
  converts `byte_offset` to a UTF-16 offset (Dart `TextField` selection) and Dart shows `column = offset + 1` with a
  localized message per `kind`; `detail` carries the token/variable name only (no payload data).

### D3 AST, canonical text and round trip

`enum Node { And(Vec<Node>), Or(Vec<Node>), Not(Box<Node>), Cond(Condition) }`; the parser flattens nested
same-operator groups and drops redundant parentheses, so every parsed tree is normalized. Number literals keep their
validated lexeme (no float re-printing), paths and header names keep the entered text; quoting is decided by the
bare-path/bare-name character sets. The formatter emits the canonical text from the spec. Core tests assert
`parse(format(t)) == t` for a corpus plus generated trees (simple deterministic generator in the test, no `proptest`
dependency), and `format(parse(s))` for a table of non-canonical inputs. The builder (D9) produces only normalized trees
(it flattens on edit), so builder → text → builder is identity.

### D4 Typing and evaluation

- Compile step produces `CompiledExpr` with: compiled `Regex` per `matches`, timestamp literals as `i64` (chrono
  `DateTime::parse_from_rfc3339`; strings without offset rejected), number literals as `Num::Int(i128)` or
  `Num::Float(f64)`, pre-tokenized `FieldPath`s, and a `needs` set {key, value, headers}.
- Value model per condition: JSON value from the path (or the whole text for `key`/`value` without path). Rules from
  the spec: number literal → numeric (JSON number, or text that parses fully as a JSON number); integers compare as
  `i128` exactly, otherwise `f64`; string literal → compare with `json_path` rendering (strings unquoted, numbers and
  booleans as JSON, containers as compact JSON); boolean literal → JSON bool or text `true`/`false`. `null`/missing →
  unresolved → false for every operator (`!=` included). `!=` = resolved and not `==`.
- `contains`/`matches` on rendered text (containers as compact JSON). `matches` = `Regex::is_match` (unanchored), same
  regex engine as the legacy filter and as `validate_filter_patterns`.
- `MessageView` trait: `partition()`, `offset()`, `timestamp() -> Option<i64>`, `key_text()`, `key_json()`,
  `value_text()`, `value_json()`, `headers(name) -> iterator of Option<&str>`; all `Option`. Evaluation short-circuits.
- Alternative considered: evaluate on the already decoded strings (as `matches_filter` does). Rejected: forces decoding
  of key and value for every message and re-parses pretty JSON for each path.

### D5 Lazy decoding in `kafkalyzer-kafka`

- Refactor the duplicated Schema Registry branch into one `decode_component(...) -> Decoded` (`Json(Value)` from the
  registry, or `Raw(&[u8])`). `decode_message_component` keeps its exact output by rendering `Decoded` (pretty JSON,
  UTF-8 text or `<placeholder>:hex`); a regression test pins the text for Avro/JSON/Protobuf-less JSON, UTF-8 and
  binary inputs so the table output does not change.
- `LazyMessage<'m>` implements `MessageView` with `std::cell::OnceCell` per component: `value_text` = rendered text,
  `value_json` = registry JSON, else `serde_json::from_slice` of the raw bytes (non-JSON → `None`). Headers are read
  from the rdkafka header list on demand (UTF-8 or `0x<hex>`, `None` for null values). `timestamp()` uses
  `to_millis()` without the `0` fallback.
- `process_and_send_message`: if an expression is set, evaluate it first on `LazyMessage`; on false return
  `NotMatched` before any decode not already forced. Then, if legacy terms are set, run `matches_filter` unchanged on
  `key_text`/`value_text` (taken from the same cells — no second decode). Emission reuses the cells.
- Diagnostics: legacy match keeps `term='…'`; expression-only match logs `expression` (spec); the canonical expression
  is logged once at scan start (it contains only user input, no payload).
- Compile happens in `consume_with_filter` before `create_consumer`, so an invalid expression fails before any broker
  connection (cheaper and clearer than inside `run_poll_loop`).

### D6 Script placeholders and limits in core

`compile(expr, bindings: &[(name, Vec<String>)])`. String literal with `{{name}}` parts → set of texts (cartesian
product over multi-value variables); bare placeholder → numbers (each value must parse, else `NonNumericVariable`).
A condition with several literal alternatives is true if any alternative satisfies it; `!=` is the exception and means
"resolved and equal to none of the alternatives" (otherwise `x != {{ids}}` with two values would always be true). More than 10,000 alternatives in total → `TooComplex`. Unknown name →
`UnknownVariable`. In the editor (no bindings) placeholders are syntax-checked only (`parse_filter_expression`
validates structure, regexes without placeholders and timestamps). Splitting values on `,` with trimming stays in Dart
(`ScriptRunner`, same rule as `_expandMultiValueFilter`) and is passed as `Vec<String>`.
Alternative: textual substitution in Dart before parsing — rejected, values containing `"` or `)` would change syntax.

### D7 Bridge API (additive)

- `consume_with_filter(…, filter_expression: Option<String>, filter_variables: Option<Vec<FilterVariable>>, sink)`.
  Dart call sites compile unchanged; the stream factory typedefs in `MessageStreamController` and
  `MultiSearchController` gain the two named parameters.
- `#[frb(sync)] parse_filter_expression(text) -> FilterParseResult { expression: Option<FilterNode>, error:
  Option<FilterExpressionError { kind, utf16_offset, utf16_len, detail }> }` — never throws for user input.
- `#[frb(sync)] format_filter_expression(expression: FilterNode) -> String`.
- `collect_field_paths(payloads: Vec<String>, max_paths: u32) -> Vec<String>` (async, one call per suggestion refresh,
  sample capped at the last 200 loaded messages in Dart).
- `FilterNode` flat-node fallback active (Spike S1 result): `flutter_rust_bridge_codegen` rejected the recursive data enum with `InvalidDep: Please update version of freezed in your dev_dependencies. (version >=1.0.0)` (due to `freezed: 4.0.0-dev.3` in `pubspec.yaml`). D7 therefore uses the flat-node representation (`Vec<FilterNodeDto { kind: FilterNodeKind, children: Vec<u32>, condition: Option<FilterConditionDto> }>`), converted to/from the Dart AST. JSON strings over the bridge are not used.

### D8 Persistence

- `TopicSearchPreset.filterExpression` (`String`, default `''`) and `ScriptStep.filterExpression` (`String?`), storing
  canonical text. Additive JSON keys, no version bump: absent key = no expression, which is exactly the old behaviour.
  Stored text is not re-validated on load (unreadable-preset rules stay as they are); invalid text is shown in the
  editor with its error and blocks the scan (spec).
- `SearchTarget.filterExpression` + `filterVariables`; `SearchJsonSerializer.serializeTarget` writes
  `filterExpression` so result files record it.

### D9 Editor UI

- New `FilterExpressionEditor` (search/presentation/widgets) used in `TopicSearchBar` advanced panel,
  `SearchStreamConfiguration` and through it the script step editor. State: `FilterExpressionEditingController`
  (ChangeNotifier) holding mode, text, builder tree (Dart mirror of `FilterNode`), last error. Text edits validate via
  the sync bridge with 300 ms debounce (same as regex validation). Switching text → builder parses; on error stays in
  text. Builder edits produce canonical text via `format_filter_expression` on mode switch, save and start (not per
  keystroke in a list/table — no per-row bridge calls).
- Builder: a group widget (AND/OR segmented button, negate toggle, add condition, add group, remove) rendering
  conditions as `InputChip`s; a chip opens a small editor (source dropdown, path/header field with suggestions,
  operator dropdown filtered by source, literal input with a type selector text/number/boolean/date-time). All from
  `package:material_ui`; labels from ARB; tooltips + semantics on icon buttons; invalid state as icon + text.
- Suggestions (`FieldSuggestionSource` enum schema/analysis/loadedMessages/none): schema via
  `SchemaController.fetchSchemaFields` (non-empty result), else `TopicAnalysisController.report?.fieldFrequencies`
  for the same topic, else `collect_field_paths` over loaded messages (topic view: `MessageStreamController`
  messages; script editor: none → free input). Header names from loaded messages' headers in Dart.
- Start gating: `TopicSearchBar._onStart` and the script runner call `parse_filter_expression` first; the runner
  passes variables to the bridge and a compile error from the stream fails the step (existing error path, B4).

## Risks / Trade-offs

- [FRB recursive enum codegen may fail] → Spike S1 first; flat-node fallback (D7).
- [Evaluation cost on value paths: JSON parse per message] → equal to today's `filter_field` cost minus the pretty
  print/re-parse; Spike S2 measures key-only, metadata-only and value-path expressions against the legacy Contains
  filter over 100k synthetic messages (1 KB and 50 KB JSON). Target: ≥ 50k msg/s evaluation for a value-path condition
  on 1 KB payloads in release mode on the dev machine, and key-only expressions not slower than legacy Contains with
  scope Key. **Measured (real `filter_expr` evaluator, 2.6):** 1 KB (100k msgs): `filter_expr` = 3,218,531 msg/s (0.031s) vs `legacy_pretty_contains` = 1,179,150 msg/s (0.085s) — exceeds 50k msg/s target; 50 KB (100k msgs): `filter_expr` = 158,253 msg/s (0.632s) vs `legacy_pretty_contains` = 33,972 msg/s (2.944s).
- [Schema field paths may not resolve in decoded JSON (e.g. Avro unions rendered differently)] → suggestions are hints;
  free input stays; 5.35 aligns schema paths.
- [Downgrade: an older app version ignores `filterExpression` and would run a broader search] → documented in the
  release notes; cannot be fixed in old binaries.
- [Placeholder `!=` semantics with multi-values may surprise] → editor hint and spec scenario; same "any" rule
  everywhere.
- [Compacted/transactional topics, offset gaps, empty topics, very large topics] → unaffected: the expression is a
  per-message predicate inside the existing loop; completion still uses `PartitionEOF`; empty topics still take the
  fast path (the expression is compiled before, so an invalid one still errors).
- [Missing ACLs / unreachable broker or registry] → unchanged error paths; a registry decode failure leaves `value_json`
  unresolved (condition false) exactly like a non-JSON payload, while `value_text` shows the existing binary/text form.
- [Large payloads] → lazy cells mean at most one decode per component per message; header-only expressions never
  touch a 10 MB payload of non-matching messages.

## Migration Plan

Additive only: no data migration. Rollback = revert; stored presets/scripts with `filterExpression` keep loading in
the reverted version (key ignored). README line on header filtering is updated in the same change.

## Open Questions

- Should a later change add a `null` literal (`value.x == null`) to distinguish JSON `null` from a missing field?
  Deferred; `exists` treats both as absent, consistent with `json_path`.
- Should Fast Trace take its key from a top-level `key == "…"` condition? Deferred to 5.14 usage feedback.
