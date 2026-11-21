# kafkalyzer — Code-Quality & Refactoring Backlog

**Scope:** Maintainability, testability, architecture boundaries, CI quality gates.
**Out of scope (already documented elsewhere — do not duplicate):**
runtime performance → [`rust-performance-improvements.md`](rust-performance-improvements.md),
features/gaps → [`feature-gap-analysis.md`](feature-gap-analysis.md),
UI/UX → [`ui_ux_audit_und_onboarding_konzept.md`](ui_ux_audit_und_onboarding_konzept.md) and
[`kafka_message_ui_optimierungskonzept.md`](kafka_message_ui_optimierungskonzept.md),
MCP → [`mcp-server-feasibility.md`](mcp-server-feasibility.md).
**Code written in English; sibling docs are German.**

Baseline commit: `e786fd7`. Measured with the commands in §1 — re-run them before starting any task.

---

## 0. Read this first

| | |
|---|---|
| Overall state | Healthy. `flutter analyze` = 7 issues, `cargo clippy` = 16 warnings, `dart format` = clean, 0 `TODO`/`FIXME`, 315 Rust tests, 207 Dart test files, Rust layering (core/kafka/api) is correct. |
| Biggest structural risk | The `features/` split is cosmetic: 21 cross-feature import edges, 3 bidirectional cycles. |
| Biggest daily friction | God widgets (1 200-line `State` classes) + global service locator: every change touches 1 500-line files and every test inherits global state. |
| Cheapest big win | CI quality gates (30 min) — the repo already passes, so gating is free today and stops the baseline from rotting. The whole Dart suite is 1 298 tests in ~60 s, so gates cost almost nothing. |
| Coverage is better than expected | 82.8 % line coverage on hand-written `lib/` (measured 2026-11-20). Coverage debt is 8 files, not whole features — see Q-5. |
| Start here | §2 task **Q-1** (`flutter analyze` + `cargo clippy` + `dart format` in `build.yml`). 30 minutes, unblocks everything else. |

---

## 1. How to reproduce the numbers

```bash
# Dart
flutter analyze                                   # 7 issues (5 errors, 2 warnings)
dart format --output=none --set-exit-if-changed lib test   # clean
find lib -name '*.dart' ! -path 'lib/src/rust/*' ! -path 'lib/l10n/*' ! -name '*.g.dart' ! -name '*.freezed.dart' \
  -exec wc -l {} + | sort -rn | head -20

# Rust (verified 2026-11-20: 308 passing, 8 ignored, workspace total ~3 s)
cargo clippy --manifest-path rust/Cargo.toml --all-targets   # 16 warnings (12 kafka + 4 lib)
cargo test --manifest-path rust/Cargo.toml --workspace       # core 167, kafka 105 (+7 ignored), frb lib 35
grep -rn "#\[test\]\|#\[tokio::test\]" rust/*/src rust/src --include=*.rs | wc -l   # 315 annotated

# Dart tests + coverage (measured 2026-11-20: 1 298 tests, all pass, ~60 s wall time)
flutter test --coverage
awk -F: '/^LF:/{l+=$2}/^LH:/{h+=$2}END{printf "all files: %d/%d = %.1f%%\n",h,l,100*h/l}' coverage/lcov.info
#   all files ................................ 27760/40011 = 69.4 %
awk -F: '/^SF:/{f=$2}/^LF:/{lf=$2}/^LH:/{lh=$2}/^end_of_record/{if(f!~/lib\/src\/rust|l10n|\.freezed|\.g\.dart/){l+=lf;h+=lh}}END{printf "hand-written: %d/%d = %.1f%%\n",h,l,100*h/l}' coverage/lcov.info
#   hand-written lib/ (excl. frb bindings, l10n, codegen)  25408/30681 = 82.8 %
```

> Correction history: the committed `coverage/lcov.info` was from 2025-10-02 and reported 49.8 % with
> whole features at zero coverage. A fresh `flutter test --coverage` disproves that — Q-5 below uses the
> fresh numbers.

---

## 2. Tier 1 — do these next (5 tasks)

### Q-1 · Add lint/clippy/format gates to CI
**Status:** implemented in `openspec/changes/ci-quality-gates` (2026-11-20). `scripts/quality_gates.sh` + a `quality-gates` job in `build.yml` (`build-*` now wait for it), `flutter analyze` down to 0 issues. The clippy check is deliberately not enabled yet — 30 findings, see Q-4 — and joins through the follow-up change `enable-rust-lint-gate`. Two steps remain outside the repo: mark `quality-gates` as a required status check, and verify the job end to end on a pushed branch.
**Evidence:** `.github/workflows/build.yml` runs only `flutter test` and `cargo test`. No static-analysis step anywhere in CI.
**Why it matters:** the current baseline is clean enough to gate today; without a gate, `deprecated_member_use: error` (already set in `analysis_options.yaml:22`) and clippy warnings silently grow.
**Task:**
1. Add a `Quality` job to `build.yml`: `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`.
2. Add `cargo clippy --manifest-path rust/Cargo.toml --all-targets -- -D warnings` (after fixing Q-4, otherwise start with `-- -D warnings` on `kafkalyzer-core` only).
3. Fix the 5 existing analyzer errors: `lib/l10n/app_localizations.dart:90-91` and `test/src/flex_theme_bridge_test.dart:2` are generated/deprecation noise → add `// ignore_for_file: deprecated_member_use` to the generated l10n header via the l10n template, and fix the two `flutter/material.dart` imports in `lib/src/flex_theme_bridge.dart:8` / `lib/src/theme.dart:7` by importing the already-aliased `modern`/`legacy` symbols.
4. Remove the 2 unused imports in `test/src/features/search/filter_expression_models_test.dart:10` and `test/src/features/search/search_stream_configuration_preset_test.dart:8`.

**Done when:** the new CI job is green on `main`.
**Effort:** 30 min (gates) + 30 min (existing errors).

---

### Q-2 · Break up the four god widgets
**Evidence:**
| File | Size | Worst offender |
|---|---|---|
| `lib/src/features/settings/presentation/settings_view.dart` | 1 905 L | `_SettingsViewState` = lines **49–1267** (1 218 L), 39 imports |
| `lib/src/features/topic/topic_detail_view.dart` | 1 769 L | single method spans 286 L |
| `lib/src/features/explorer/presentation/explorer_view.dart` | 1 721 L | `Timer.periodic` (line 1692) + list + dialogs + onboarding in one `State` |
| `lib/src/ui/messages/views/messages_table_view.dart` | 1 598 L | table + sorting + formatting + selection in one `State` |

**Why it matters:** these four files absorb most feature work; review diffs of 300+ lines and merge conflicts come from here.
**Task:** split one file per PR, no behaviour change, existing widget tests must stay green.

**Result (change `split-god-widgets`, three of four files):**

| File | Before | After |
|---|---|---|
| `settings_view.dart` | 1 905 L | **76 L** — six section widgets + `SettingsImportExportController` |
| `topic_detail_view.dart` | 1 769 L | **655 L** — progress tile, fact strip/tags, header |
| `explorer_view.dart` | 1 721 L | **608 L** — sidebar, cluster list, topic panel |
| `messages_table_view.dart` | 1 598 L | untouched — moved to `relocate-messages-feature` (Q-7) |

Largest new file: 620 L (`explorer_sidebar_topics.dart`). The `Timer.periodic`
in the topic-list age label is now `TopicListRefreshTicker` with an injectable
timer factory and two fake-clock tests. The size guard in
`scripts/quality_gates.sh` fails any touched file that crosses 800 lines.
1. `settings_view.dart` → one file per section: diagnostics, appearance, about/updates, cluster import/export (`_buildClusterListContent` 903–1173 and `_runWithProgressDialog`/`_askExportCredentials`/`_handleExportConfiguration` 1188–1265 move into `widgets/cluster_config_io.dart`), plus `_GeneralSettingsSection`, `_IntSettingField`, `_MessageBufferLimitField` into `widgets/`.
2. Move the cluster import/export orchestration out of `State` into a `SettingsImportExportController` (watch_it `StateNotifier`), matching the pattern already used by `ClusterListController`.
3. Repeat for `topic_detail_view.dart` (tabs → one widget per tab) and `explorer_view.dart` (extract the 30 s refresh timer into a controller so it is testable).
4. `messages_table_view.dart`: extract sort/format helpers to `lib/src/ui/messages/message_sort_utils.dart` (already exists — extend it, do not add a new util file).

**Done when:** no hand-written widget file in `lib/src` exceeds 800 L; `flutter test` green.
**Effort:** ~2 h per file → 8 h total. Start with `settings_view.dart` (highest churn).

---

### Q-3 · Kill the service locator inside features
**Evidence:** `getIt<...>()` appears **160×** inside `lib/src/features`, 21× in `lib/src/ui`; `lib/src/dependency_injection.dart:65-95` registers **11 controllers as `registerLazySingleton`**. `test/flutter_test_config.dart` never calls `getIt.reset()`.
**Why it matters:** controllers are process-global mutable singletons, so widget tests inherit each other's state — the last commit (`e786fd7` "Fix timing-sensitive Flutter tests") is a symptom, not a fix. Widgets also cannot be given a failing or fake controller.
**Measurement correction:** step 1 was bigger than assumed — 46 test files (67 call sites, 31 of them in `setUp`) already called `getIt.reset()`, not 10.
**Task:**
1. Add `tearDown(() => getIt.reset())` to `test/flutter_test_config.dart` and fix what breaks (that is the real inventory of hidden global state).
2. Convert the 11 singleton controller registrations to `registerFactory` + `ChangeNotifierProvider`/`ValueNotifier` scoping (the project already depends on `provider`) so controller lifetime follows the widget subtree.
3. Replace field-level `final x = getIt<X>()` in widget classes with constructor parameters that default to `getIt<X>()` — this keeps call sites unchanged and makes fakes possible. Do it file by file; `lib/src/features/consumer/presentation/consumer_lag_view.dart:264,388` (async Kafka calls inside a widget) first.

**Done when:** no hand-written source under `lib/src/features/*/presentation/` resolves session-wide state from the container outside a constructor-parameter default — `bash scripts/quality_gates.sh locator-guard` enforces this on the files a change touches — and the suite passes with the shared `getIt.reset()`. (Replaces the earlier "count below 20", which measured the wrong thing: the number of lookups is fine, a lookup in the wrong place is not.)
**Effort:** 1 h for step 1 (discovery), then 1–2 days for 2+3. Biggest item in this list.

**Result (change `remove-global-controller-state`, implemented):**

Step 1 landed first: `getIt.reset()` now lives in `test/flutter_test_config.dart`, the per-file resets are deleted, and the suite is order-independent (reversed order and per-file runs pass).

Step 2 was dropped: `provider` was declared but imported nowhere and has been removed from `pubspec.yaml`. Lifetime instead follows the widget through constructor parameters that default to the container (`this.x ?? getIt<T>()`), so existing call sites stay unchanged and tests pass their own instance.

Step 3 landed with a named session set — the 11 types in `sessionWideState` (`lib/src/dependency_injection.dart`): `ActiveConnectionController`, `ClusterListController`, `TlsTransitionController`, `MultiSearchController`, `TopicController`, `ClusterOverviewController`, `SchemaController`, `MainNavigationController`, `ScriptController`, `ScriptRunner`, `ConsumerGroupDirectory`. The dead `TopicAnalysisController` registration is gone, `setupDependencyInjection` is split into `setupCoreServices` / `registerSessionWideState` / `registerScriptExecutionState`, and the headless runner registers only what it executes.

---

### Q-4 · Fix the 30 clippy warnings and make `clippy -D warnings` stick
**Note:** the earlier count of 16 was measured without `--workspace`; `cargo clippy --workspace --all-targets` at `e786fd7` reports 30 (9 in `kafkalyzer-core` incl. `tests/spike_s2_descriptor_set.rs`, 12 lib / 16 with tests in `kafkalyzer-kafka`, 4 / 5 in the bridge crate). Revised effort: 4–6 h.
**Evidence:** `cargo clippy --manifest-path rust/Cargo.toml --all-targets` → 12 warnings in `kafkalyzer-kafka`, 4 in `rust_lib_kafkalyzer`.
| Warning | Where | Fix |
|---|---|---|
| `too_many_arguments` × 5 (worst: **19 args**) | `rust/src/api/kafka_consumer.rs:74` `consume_with_filter`; also 18/14/11/9-arg fns | introduce one `ConsumeParams` struct (`#[derive(Serialize, Deserialize)]`) and pass it; regenerate frb bindings |
| `wrong_self_convention` × 3 | `rust/src/api/kafka_types.rs:102,119,396` `to_domain(&self)` | rename to `as_domain(&self)` (Copy types) |
| `type_complexity` × 3 | `kafkalyzer-kafka` | add `type` aliases |
| `useless_conversion` | `kafkalyzer-core`→api at `rust/src/api/kafka_types.rs:1193` | drop `ConsumerGroupLag::from(group)` |
| `single_match_else`, `redundant_guards`, `needless_borrow`, `no_effect_reference` | `kafkalyzer-kafka` | mechanical |

**Why it matters:** the 19-argument FFI function is the signature of the app's hottest path — every new filter option adds another positional argument that Dart, Rust and frb bindings must each track.
**Task:** apply `cargo clippy --fix` for the mechanical ones, hand-fix the argument structs and renames, then run `flutter_rust_bridge_codegen generate` and commit regenerated bindings (see Q-9 for the drift guard).
**Done when:** `cargo clippy --all-targets -- -D warnings` exits 0 and `flutter test` still passes.
**Effort:** 3 h (≈1 h of it is waiting for codegen + build).

---

### Q-5 · Cover the 8 files that actually have test gaps
**Measured 2026-11-20 (`flutter test --coverage`, 1 298 tests, all pass):** 69.4 % overall, **82.8 % on hand-written `lib/`** (excluding frb bindings, l10n, freezed/json codegen). Coverage debt is concentrated, not systemic:

| Coverage | Uncovered lines | File |
|---|---|---|
| **0 %** | 114 | `lib/src/features/search/presentation/widgets/topic_selection_dialog.dart` |
| **0 %** | 74 | `lib/src/features/scripting/presentation/widgets/parameter_values_dialog.dart` |
| 10 % | 185 | `lib/src/features/scripting/presentation/widgets/script_history/script_history_list.dart` |
| 29 % | 215 | `lib/src/features/search/presentation/widgets/filter_expression_editor.dart` |
| 33 % | 195 | `lib/src/features/scripting/presentation/widgets/script_schemas_view.dart` |
| 41 % | 92 | `lib/src/features/scripting/presentation/widgets/script_history/script_run_sidebar.dart` |
| 28 % | 61 | `lib/src/features/schema/utils/schema_simplifier.dart` (pure logic — cheapest win) |
| 52 % | 149 | `lib/src/features/settings/presentation/widgets/update_dialog.dart` |

Next tier by absolute gaps: `settings_view.dart` 228 uncovered (74 %), `script_runner.dart` 188 (65 %), `topic_detail_view.dart` 184 (77 %), `explorer_view.dart` 175 (77 %). Weakest directories: `features/schema/utils` 49 %, `features/scripting/presentation` 64 %, `features/scripting/application` 67 %, `features/search/presentation` 67 %, `features/settings/presentation` 69 %.

**Task, in this order (one commit each):**
1. Unit-test `schema_simplifier.dart` — pure function, no widget, 30 min, moves a whole util off the low list.
2. Widget-test `topic_selection_dialog.dart` and `parameter_values_dialog.dart` — both at 0 %, both are user-facing entry points.
3. Widget-test the `script_history/` trio (`script_history_list`, `script_run_sidebar`, `script_run_details_view`) — 462 uncovered lines in one directory.
4. Widget-test `filter_expression_editor.dart` and `script_schemas_view.dart` — the two biggest single-file gaps.
5. Unit-test `headless_script_runner.dart` (67 %) — it is the code path the MCP server proposal would reuse, so it needs to be trustworthy before that work starts.

**Done when:** `flutter test --coverage` reports ≥ 86 % on hand-written `lib/`, no file under 40 % except `lib/main.dart` (17 %, bootstrap), and the `script_history/` directory is above 70 %.
**Effort:** 30 min + 3 × 1.5 h + 1 h ≈ **5 h** total.

---

## 3. Tier 2 — schedule after Tier 1

| ID | Task | Evidence | Effort |
|---|---|---|---|
| Q-6 | Make the feature boundaries real, or admit they are not features. Delete the 3 cycles first: `cluster↔topic` (6/8 imports), `topic↔schema` (2/7), `topic↔search` (2/6). Break a cycle by moving the shared type into the lower feature or into `lib/src/services`. Full edge matrix in §5. | 21 cross-feature import edges | 1–2 days |
| Q-7 | Move `lib/src/ui/messages/` (3 files, 4 311 L: `messages_view.dart`, `messages_table_view.dart`, `message_inspector_panel.dart`) into `lib/src/features/messages/` — it is a feature, and today the app has two homes for UI (`features/*/presentation` and `ui/`). Update imports only, no logic change. | `lib/src/ui` = 14 146 L | 3 h (mostly `git mv` + import rewrite) |
| Q-8 | Move the 7 feature-owned services out of the flat `lib/src/services` (5 707 L): `topic_analysis_history_service.dart`, `topic_analysis_export_service.dart`, `topic_list_preferences_service.dart`, `local_schema_assignment_service.dart`, `saved_searches_service.dart`, `diff_ignore_list_service.dart`, `recent_topics_service.dart` → into their feature's `data/` or `domain/`. | `lib/src/services/*.dart` | 3 h |
| Q-9 | Guard generated-code drift: `lib/src/rust/frb_generated.dart`, `lib/src/rust/**/api/*.dart`, `rust/src/frb_generated.rs` are committed but never verified against `rust/`. Add a CI step: run `flutter_rust_bridge_codegen generate` then `git diff --exit-code`. | `flutter_rust_bridge.yaml` | 30 min |
| Q-10 | Silence the `flutter/material` → `material_ui` deprecation properly. `lib/src/flex_theme_bridge.dart` (1 291 L) is generated by `scripts/gen_flex_theme_bridge.py` to bridge the two Theme APIs because `flex_color_scheme` has not migrated (upstream issue #310). Track upstream, and pin the Flutter version in CI so a Flutter bump does not silently invalidate the bridge. **Confirmed hazard (found during Q-1):** regenerating the bridge with the current SDK produces a file 210 lines shorter and breaks `test/src/flex_theme_bridge_test.dart` (`flexThemeToModern maps core theme values`) — the checked-in artifact no longer matches what the generator emits against this SDK. Pinning CI and re-baselining the generator are now required work, not nice-to-have. | 4 of the 7 analyzer errors come from this | 1 h + watch upstream |
| Q-11 | Run the 6 ignored Kafka integration tests in CI. They need a broker (`localhost:9094` + fixtures `lag-spike-g`, `spike-t-*`, `spike-offset-dist-60p`) that `docker-compose.yaml` already provides, so today the whole rdkafka metadata/admin path is untested on every push. Add a `services: kafka` job running `cargo test --manifest-path rust/Cargo.toml -p kafkalyzer-kafka -- --ignored`. | `kafka_metadata.rs:1756,1811,1987,2012,2031` (`#[ignore = "Requires local docker compose kafka…"]`), `duplicate_fingerprint.rs:296` | 2–3 h |

---

## 4. Tier 3 — small, opportunistic (pick up while touching the file)

1. **Listener leak** — `lib/src/features/topic/presentation/widgets/analysis/value_filter_widgets.dart:96` calls `addListener` inside a widget builder, so one listener per rebuild, never removed. Hoist to `initState` + `removeListener` in `dispose`. Same shape (lower impact): `parameter_values_dialog.dart:31`, `analysis_scope_dialog.dart`.
2. **Silent failures** — 17 empty `catch (_) {}`. Fix the three that hide user-visible loss: `services/message_export_service.dart:383` (export step fails silently), `services/window_state_service.dart:332`, `services/diagnostics/app_logging.dart:281` (the logging path swallowing its own errors). Route them through the existing `services/diagnostics/error_handlers.dart`.
3. **Duplicated helpers** — `int _resolveBufferLimit()` is byte-identical in `features/search/presentation/controllers/multi_search_controller.dart:201` and `features/topic/presentation/controllers/message_stream_controller.dart:67`; `String _formatNum(num)` in 3 consumer widgets (`topic_partition_table.dart:42`, `group_details_view.dart:43`, `consumer_lag_view.dart:138`); 4 variants of `_formatDuration`. Move to `lib/src/ui/date_format_utils.dart` / `message_sort_utils.dart`.
4. **Rust API ergonomics** — 4 hand-rolled RAII guard structs (`kafka_metadata.rs:968-1005`: `QueueGuard`, `ListGroupOffsetsReqGuard`, `AdminOptionsGuard`, `EventGuard`). Replace with one macro or `scopeguard` (already a small dep surface) if a fifth appears. Do not refactor before.
5. **Dependency hygiene** — `pubspec.yaml`: `get_it:`/`watch_it:` unpinned, `cupertino_ui: any`, `collection: any`, `listen: any`, and `freezed: ^4.0.0-dev.3` is a **pre-release** in dev_dependencies. Pin them (`pubspec.lock` already resolves the versions); a pre-release codegen dependency can change generated files without a version bump.

---

## 5. Feature dependency graph (evidence for Q-6)

Directed import count, feature → feature:

```text
cluster → topic 6      consumer → cluster 2      consumer → navigation 1
explorer → cluster 7   explorer → navigation 1   explorer → schema 3   explorer → topic 9
navigation → cluster 2 navigation → topic 1      schema → topic 2
scripting → cluster 6  scripting → navigation 1  scripting → schema 2  scripting → search 8  scripting → topic 2
search → topic 2       topic → cluster 8         topic → schema 7      topic → scripting 1   topic → search 6
settings → cluster 7   settings → search 1
```

**Cycles:** cluster↔topic, topic↔schema, topic↔search, scripting→search→topic→scripting.
Reproduce: `for a in <features>; do for b in <features>; do grep -rc "features/$b/" lib/src/features/$a; done; done`.

---

## 6. Deliberately NOT debt (do not "clean" these)

1. `lib/src/rust/frb_generated*.dart`, `lib/src/rust/api/*.dart`, `rust/src/frb_generated.rs`, `lib/l10n/*`, `*.freezed.dart`, `lib/src/flex_theme_bridge.dart` — generated. Their `ignore_for_file: invalid_use_of_internal_member, unused_import, unnecessary_import` lines are emitted by the generators; deleting them is churn.
2. Rust `unsafe` blocks in `rust/kafkalyzer-kafka/src/kafka_metadata.rs:278, 929, 968-1005` — each carries a `// SAFETY:` comment and an RAII guard; `safe_collect_members` (line 929) works around a real rdkafka 0.36.2 UB bug. This is above-average discipline, not a liability.
3. 176/159 `unwrap`/`expect` hits in the Rust crates — almost all inside `#[cfg(test)]`. Production code has 14, and 6 of those are `Regex::new(...).expect(...)` in `filter_expr.rs`. Correct as-is.
4. `catch (_) {}` in `lib/src/services/stored_list.dart:90,111,148` — intentional: they return a typed `StoredListParse` result that the UI turns into a "some entries unreadable" notice. Only the Tier 3 item 2 list is a real problem.
5. Zero `TODO`/`FIXME`/`HACK` in `lib/src` and `rust/src`.
6. Repo hygiene is fine: no committed build artifacts, logs, or coverage files (`tests.log`, `logs/`, `build/` are ignored — `.gitignore:34`).
7. Committed test count is not the problem: 1 298 Dart tests run in ~60 s with zero failures. Q-5 adds targeted tests; do not add a coverage ratchet below 82.8 %.

---

## 7. Suggested order

| Step | Task | Duration | Visible result |
|---|---|---|---|
| 1 | Q-1 CI gates | 1 h | `main` fails on new lint/clippy/format violations from now on |
| 2 | Q-4 clippy cleanup + param structs | 3 h | `clippy -D warnings` green; new filter options need one struct field, not 3 signatures |
| 3 | Q-3 step 1 (`getIt.reset()` in tests) | 1 h | the flaky-test root cause becomes visible |
| 4 | Q-5 test items 1–3 | 4.5 h | streaming/scripting dialogs and the script-history UI become regression-safe |
| 5 | Q-2 god-widget splits | 8 h | PRs shrink to one file each |
| 6 | Q-3 steps 2–3 | 1–2 days | widgets become fakeable |
| 7 | Q-6 / Q-7 / Q-8 boundaries | 2–3 days | feature folders mean something |
| 8 | Tier 3 | opportunistic | — |

Total for Tier 1: **about 2.5 working days** if done by one person, sequentially as listed.

---

## 8. OpenSpec-ready change proposals

Each Tier 1/2 ID maps to one OpenSpec change. Suggested names (use `openspec/changes/<name>/`):

`ci-quality-gates` (Q-1) · `split-god-widgets` (Q-2) · `remove-global-controller-state` (Q-3, implemented) · `rust-ffi-parameter-objects` (Q-4) · `cover-test-gaps` (Q-5) · `break-feature-cycles` (Q-6) · `relocate-messages-feature` (Q-7) · `relocate-feature-services` (Q-8) · `verify-generated-bindings` (Q-9) · `material-ui-migration-tracking` (Q-10) · `ci-kafka-integration-tests` (Q-11).
