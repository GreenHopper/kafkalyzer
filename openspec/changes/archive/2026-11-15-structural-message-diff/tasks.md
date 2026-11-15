# Tasks

## 1. Spikes and characterization (before any code change)

- [x] 1.1 Fixture capture (design Risks): write a temporary Dart test that runs `JsonConverter.fromDiff(JsonDiffer.fromJson(a, b).diff())` for ~20 cases (nested change, added/removed scalars and containers, top-level arrays, mixed top-level types, null vs missing, `1` vs `1.0`, middle insert/remove, append, truncate, in-place element change, reorder, equal top-level scalars, key order, keys with `.`/`/`, unicode) and writes `test/fixtures/json_diff/cases.json` (`old`, `new`, flattened tree rows `{key, type, depth, old, new}` with values via `toString()`, optional `deviation` note). Verify: file checked in; the three known deviations (reorder, equal top-level scalars, nested unordered lists) are marked
- [x] 1.2 Characterization widget test `test/src/features/scripting/presentation/widgets/diff/json_diff_widget_test.dart` on the current widget for 3 fixtures (row texts in order, icons per row, collapse of a nested node, "No differences found."). Verify: green on the current code; kept and later re-pointed to the new widget API in 4.3
- [x] 1.3 Spike in `rust/kafkalyzer-core` (scratch test, not committed): order-preserving `Node` visitor parse + diff of a 5 MB object payload and of two 100 000-element arrays; record timings and whether 128-level nesting is hit by any payload in `test/fixtures`. Verify: numbers noted in the PR description; if a 5 MB diff takes > 500 ms, revisit the 2000-entry GUI cap and the object index threshold (design D3) before group 2

## 2. kafkalyzer-core `json_diff`

- [x] 2.1 Add `rust/kafkalyzer-core/src/json_diff.rs` + `pub mod json_diff;` with `Node` parse/serialize (design D3) and unit tests: document key order kept, duplicate key replaced in place, compact value text, numbers `1`/`1.0` equal. Verify: `cargo test -p kafkalyzer-core json_diff`
- [x] 2.2 Implement `diff_json` object/scalar/type/null semantics and ordering (design D2, D4) with tests for every scenario of spec requirements *Flat Structural Difference List*, *Null, Missing and Type Changes Are Distinguished*, *Non-JSON Input Is Reported* and root-level entries. Verify: `cargo test -p kafkalyzer-core json_diff`
- [x] 2.3 Implement array alignment (prefix/suffix + positional middle, `shortcut:` comment for scattered inserts) with tests for middle insert/remove, in-place change, append, truncate, reorder, and a 100 000-element test asserting completion under a generous time bound. Verify: `cargo test -p kafkalyzer-core json_diff`
- [x] 2.4 Paths via `json_path::build_canonical_path`; test that every non-root entry path of the fixture cases resolves with `json_path::resolve` against the side holding the value, including `app.kubernetes.io/name`. Verify: `cargo test -p kafkalyzer-core json_diff`
- [x] 2.5 `DiffOptions` ignore (token prefix, design D5) and `max_entries` (total/truncated/hidden); tests for every scenario of *Ignored Field Paths* and *Bounded Result Size*. Verify: `cargo test -p kafkalyzer-core json_diff`
- [x] 2.6 Fixture test: load `test/fixtures/json_diff/cases.json` (`include_str!`) and assert the expected entries listed per case (add an `entries` array to each case in this task). Verify: `cargo test -p kafkalyzer-core json_diff`; `cargo clippy -p kafkalyzer-core --all-targets` clean

## 3. Bridge

- [x] 3.1 Add `rust/src/api/json_diff.rs` (+ `mod.rs`) with the DTOs and `diff_json_batch` of design D6 and a Rust test for request/result order, per-request ignore paths and the cap. Verify: `cargo test --workspace`
- [x] 3.2 Run `flutter_rust_bridge_codegen generate` and `dart run build_runner build`. Verify: `lib/src/rust/api/json_diff.dart` exists with `Future<List<JsonDiffResult>> diffJsonBatch(...)`, mocks in `test/src/rust/api/rust_mocks.mocks.dart` contain `crateApiJsonDiffDiffJsonBatch`, `flutter analyze` clean

## 4. Dart diff engine migration

- [x] 4.1 Add `widgets/diff/json_diff_batcher.dart` (design D7) and register it in `dependency_injection.dart`; unit test with the bridge mock: three requests in one turn → one call, 60 requests → two calls, a throwing call fails all its futures. Verify: `flutter test test/src/features/scripting/presentation/widgets/diff/`
- [x] 4.2 Add `DiffTreeBuilder.fromEntries` (replacing `JsonConverter.fromDiff`, `DiffViewNode.path` added); test that for every fixture case the tree built from the case's `entries` equals the captured rows (cases with `deviation` assert their new expectation). Verify: `flutter test test/src/features/scripting/presentation/widgets/diff/`
- [x] 4.3 Switch `JsonDiffWidget` to `entries` + optional `onIgnorePath`/`hiddenCount` (row context menu only with a callback) and re-point the 1.2 tests to it without changing their expectations. Verify: 1.2 tests green unchanged in expectations
- [x] 4.4 Rewrite `MessageDiff.computeDiff(older, newer, {ignorePaths})` on the batcher (`{} ` substitution kept, text diff only for non-JSON, isolate threshold kept for text); tests for JSON, non-JSON (text diff present), tombstone side compared as `{}`, error propagation. Verify: `flutter test`
- [x] 4.5 Update `messages_diff_view.dart` to the new types (no ignore UI yet) and `messages_diff_view_test.dart`, `messages_view_test.dart`, `messages_view_stepper_test.dart` to `KafkalyzerRustLib.initMock`; add a test that a non-JSON pair never shows "No differences found." and that a failing batch shows "Error computing diff". Verify: `flutter test test/src/ui/messages/`
- [x] 4.6 If `MessageCompareDialog` from `message-selection-copy-and-display` exists in `lib/` at this point, migrate it to the new `MessageDiff`/`JsonDiffWidget` API and keep its tests green; otherwise record in the PR that §5.27 must use the new API. Verify: `grep -rn "json_diff/json_diff.dart" lib test` shows only `script_schemas_view.dart`

## 5. Script schemas view

- [x] 5.1 Replace both `JsonDiffer` uses in `script_schemas_view.dart` with one `diffJsonBatch` call per field card (`FutureBuilder`, progress indicator, localized error) and make the Markdown export await the same results and print `entry.path`; leave the group-9 literals of `accessibility-and-l10n-sweep` untouched. Widget test for differences, no differences and a failing call; unit test for the Markdown lines. Verify: `flutter test` for the touched tests; `grep -rn "package:json_diff" lib test` is empty

## 6. Ignore list (service, UI, suggestions, l10n)

- [x] 6.1 Add `DiffIgnoreListService` (design D8) + DI registration; tests with mocked `SharedPreferences`: per-topic isolation, persist/reload, duplicate and empty path rejected, wrong-typed stored value reported and not overwritten, failing save reported. Verify: `flutter test test/src/services/diff_ignore_list_service_test.dart`
- [x] 6.2 Add the volatile-field suggestion function (design D8) with tests: `updatedAt`, `createdAt`, `ts`, `eventId`, `uuid` suggested; `customerName`, index-only segments, already ignored paths not suggested; at most 20. Verify: `flutter test`
- [x] 6.3 Add `DiffIgnoreListDialog` (list, add field, remove buttons with tooltip and semantic label, suggestion chips) using `package:material_ui/material_ui.dart`; widget tests: add, remove, invalid input message, accepting a suggestion, suggestions not pre-selected. Verify: `flutter test`
- [x] 6.4 Wire into `MessagesDiffView`: header with ignored-field count and dialog (topic dropdown for several topics), per-card "hidden (n)" and truncation notice, "Ignore this field" row action, per-topic cache invalidation, `max_entries` 2000, warning when a stored list is unreadable (no hidden count shown). Widget tests for every scenario of *Per-Topic Ignore List in the Diff View*, *Suggestions for Volatile Fields* and *Diff Rendering Is Preserved* ("No differences found." + hidden count). Verify: `flutter test test/src/ui/messages/`
- [x] 6.5 Add all new strings (header, dialog title/hint/add/remove/empty, suggestions title, "Ignore this field", `diffHiddenCount` "Hidden ({count})"/"Ausgeblendet ({count})", truncation notice with count, load warning, save error, invalid/duplicate path) to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, regenerate localizations. Verify: `flutter test test/l10n/` (ARB consistency and hard-coded-string guard) green without new allowlist entries; one German widget test for the hidden count

## 7. Dependency removal

- [x] 7.1 Remove `JsonConverter.fromDiff`/`json_converter.dart` leftovers and the temporary capture test of 1.1, then remove `json_diff` from `pubspec.yaml` and run `flutter pub get`. Verify: `git diff pubspec.lock` only drops `json_diff` (and transitive entries nothing else uses); `grep -rn "json_diff" pubspec.yaml lib test --include=*.dart --include=*.yaml` matches only the new `json_diff` module/fixture names, no `package:json_diff`

## 8. Final verification

- [x] 8.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets`, `cargo test --workspace`; then `flutter_rust_bridge_codegen generate` and `dart run build_runner build` produce no diff; `dart format .`, `flutter analyze`, `flutter test`, `scripts/check_read_only.sh` (unchanged gate). Verify: all exit 0
- [x] 8.2 Manual check on Linux desktop: diff view of a topic with changing `updatedAt` — suggestion offered, accepting it shows "Hidden (n)", restart keeps it, other topic unaffected; a 5 MB payload pair keeps the view scrollable; the script schemas view still shows differences. Verify: notes and screenshots in the PR description
