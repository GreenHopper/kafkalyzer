# Design

## Context

The numbers in `proposal.md - Why` hold at the current `main`. The constraints that shape the approach:

- The four destinations are built by a `switch` (`lib/src/ui/main_layout.dart:306-311`), so the destination subtree is disposed on every tab change. Anything the user must find again lives outside the subtree — today that means a `registerLazySingleton` in `lib/src/dependency_injection.dart`. The specs `topic-search-tabs` ("preserving the state of all background tabs"), `consumer-lag-trend`, `window-state-persistence` and `headless-script-execution` already make that retention observable, so the change may not narrow it.
- `watch_it` 2.5 (pinned) resolves against the root locator instance. Four widgets use `WatchingStatefulWidget`: `explorer_view.dart`, `settings_view.dart`, `settings_cluster_section.dart`, `consumer_lag_view.dart`. Anything those widgets pull through `watch_it` must stay resolvable from the root container for the whole session, or those files have to be rewritten.
- `provider` 6.1.5+1 is a direct dependency in `pubspec.yaml` and imported nowhere in `lib/`. The backlog's "the project already depends on provider" is a declaration, not an existing pattern.
- `get_it` 9.3.0 supports scopes (`GetItScope`), which are zone-based.
- The suite: 51 test files touch the locator, 46 call `getIt.reset()` themselves (67 occurrences, mostly in `setUp`), 50 call `getIt.register…` with their own fakes behind `isRegistered` guards. Isolation is therefore solved per file today, not once for the suite — which is why a new test file inherits state by accident. `test/flutter_test_config.dart` registers a `FakeClusterProfileTools` and never resets.
- A stateless, subtree-owned controller already exists as the working pattern: `SettingsImportExportController` (from `split-god-widgets`) is constructed by `settings_view.dart:24-25` and handed to child widgets as a constructor parameter. `TopicListRefreshTicker` is the pattern for injectable timers.
- `scripts/quality_gates.sh` already implements a merge-base-scoped guard (`check_file_size`, line 40) and the same script is what CI runs, so a second scoped check is cheap.

## Goals / Non-Goals

**Goals:**

- One file states the whole set of session-wide state; everything else is owned by a widget subtree.
- No production source outside that file resolves session-wide state through the locator except the composition root and the entry points that wire it.
- A widget test can drive a screen with a failing, slow or fake dependency without touching production sources.
- `flutter test` stays green in default order, in reversed order, and file-by-file, with the container reset in the shared setup.

**Non-Goals:**

- No new state-management package, no `provider` adoption, no `watch_it` migration or removal.
- No change to service registrations (`ClusterService`, `KafkaMetadataService`, `SettingsService`, `SecureStorageService`, …) — services stay locatable and their lifetimes are already correct.
- No change to the throttling, buffering or bounded-memory behaviour inside controllers; the requirements in `topic-consumption` for 50-100 ms batching stay untouched.
- No source-file splits beyond what the constructor-parameter work forces, and no growth of a file already at or above the 800-line gate limit (`consumer_lag_view.dart` is 1 287 lines: exempt as of the merge base, but this change must not make it bigger).
- The 21 locator lookups under `lib/src/ui/`. They move with `relocate-messages-feature` (Q-7), which relocates the largest of those files anyway; converting them here reworks the same lines twice.
- No Rust, bridge or stored-format change at all — the whole change is Dart-side lifetime management.

## Decisions

### D1 — Two lifetime classes, and the session set is enumerated in one file

The 11 controller registrations split as follows. `controller-state-lifetime` requirements are the reason for each classification, not convenience.

| Controller | Lifetime | Reason |
|---|---|---|
| `ActiveConnectionController` | session | active cluster is shown in several destinations |
| `ClusterListController` | session | cluster list and health survive destination changes; `cluster-profile-persistence` |
| `TlsTransitionController` | session | holds the in-flight TLS-restore prompt while its screen is not shown |
| `MainNavigationController` | session | the selected destination outlives every destination subtree |
| `MultiSearchController` | session | `topic-search-tabs` requires all background tab sessions to keep state |
| `TopicController` | session | topic list and tab context are read from Explorer, schema and consumer views |
| `SchemaController` | session | `integrated-schema-inspector` / `schema-subject-browser` state spans destinations |
| `ScriptController` | session | script selection and editor state return after a visit to Explorer |
| `ScriptRunner` | session | a running script must finish while its view is disposed; also used by the headless entry point |
| `ConsumerGroupDirectory` | session | documented session-only cache, `null` means "never loaded this session" |
| `TopicAnalysisController` | **removed registration** | already created per analysis key at `active_connection_controller.dart:434`; `getIt<TopicAnalysisController>` has zero call sites — dead registration |

Subtree-owned by the view that introduces it (no registration at all): `SettingsImportExportController` (already), `TopicListRefreshTicker` (already), and per-dialog state such as the filter/draft state in `filter_expression_editor.dart`, `parameter_values_dialog.dart` and the analysis-scope dialogs.

The enumerated session set lives in the composition-root file as a named constant list of types, so the gate check and the reviewers read the same list. Alternative considered: a doc comment listing them — rejected, a comment cannot be read by the guard and drifts.

### D2 — Subtree-scoped state is created and passed, never looked up

An owner (the introducing widget's `State`, or the nearest common ancestor) constructs the object in `initState` and passes it down as a constructor parameter. Disposal of subscriptions and timers happens in `dispose`, with `TopicListRefreshTicker`'s injectable timer factory as the template.

Alternative considered: `registerFactory` plus `GetItScope`. Rejected for three reasons. (a) A factory lookup silently creates a fresh, empty instance, so a lookup from the wrong scope would render "no messages", "no clusters" or "lag 0" — exactly the silent-empty-result failure mode the project rules forbid; an explicit parameter makes the same mistake a compile error. (b) `GetItScope` is zone-based: a locator lookup performed later, across an `async` gap or from a callback the widget stored, resolves in the creating zone and is fragile exactly where this code is most concurrent (stream listeners, timers). (c) `watch_it` resolves against the root container, so scoped registrations would be invisible to the four existing `WatchingStatefulWidget` screens.

### D3 — Session-scoped access becomes a constructor parameter that defaults to the locator

`FooView({ActiveConnectionController? active}) : _active = active ?? getIt<ActiveConnectionController>()`. Call sites do not change; a test passes its own instance. Applied to the 58 field-level `final x = getIt<X>()` occurrences and to lookups inside widget methods, file by file, starting with `consumer_lag_view.dart` (its Kafka calls at lines 264 and 388 sit directly in the widget).

Alternatives considered: a `getIt`-free widget layer that takes every dependency explicitly — rejected, it rewrites 30 widget files' call sites in the same change for no extra safety; `provider`/`ChangeNotifierProvider` — rejected as a second state system next to `watch_it`, and it would need every existing `AnimatedBuilder` in those files rewritten. Since `provider` has no import anywhere in `lib/`, keeping it declared only invites that second system back: this change deletes it from `pubspec.yaml` (task 3.4).

### D4 — Gate check reads the session set, not a list of file names

Extend `scripts/quality_gates.sh` with a second merge-base-scoped check: for hand-written Dart sources under `lib/src/features/*/presentation/` that the change touches, fail when a locator lookup of a type from the enumerated session set appears where it did not appear at the merge base. Composition-root and `test/` sources are exempt because that is where the state is legitimately provided. Alternative considered: a numeric threshold (the backlog's "below 20 lookups") — rejected, a threshold freezes a specific count, needs a ratchet file to stay honest, and the project's gate rules forbid committed baselines.

### D5 — Test isolation lands before any lifetime change, in one shared setup

`test/flutter_test_config.dart` gets a container reset in `setUp` and `tearDown` and registers the baseline fakes a screen needs; a shared helper under `test/helpers/` lets a test layer one substitute on top and read the instance back. The `isRegistered` guards in the ~40 self-registering test files become unnecessary once the container starts empty, and the 10 hand-rolled resets are deleted.

Order matters: the reset lands alone, its fallout is fixed, and only then do the registrations change. That fallout list is the actual inventory of hidden global state and it is the reason the backlog calls step 1 a discovery step.

### D6 — Entry points wire their own minimum set

`lib/main.dart` and the headless path (`headless_script_runner.dart:59,331,372`) keep explicit registration of what they use, so `test/main_headless_test.dart` does not depend on the GUI registration list. `lib/src/app.dart`'s top-level `final _router = GoRouter(...)` stays as it is; making the router session-owned is not needed for this capability.

### D7 — Verification order

Rust and bridge steps are skipped: `rust/src/api/` is untouched, so no `flutter_rust_bridge_codegen generate` and no mock regeneration. The Dart sequence from `openspec/config.yaml` applies: `dart format`, `flutter analyze`, `flutter test`, `scripts/check_read_only.sh`, `scripts/quality_gates.sh`. `flutter test` runs in default order, reversed order, and for the touched files individually — that is how the `test-execution-isolation` scenarios get demonstrated.

## Risks / Trade-offs

- The container reset breaks an unknown number of self-registering test files, and 46 files already reset on their own → reset lands as phase 1 alone; the fallout is the work, not a surprise. Budget one day of it, cap per-file fixes at one commit each.
- A controller moved to subtree scope loses state the user expects after a tab switch → the session set is derived from named specs (`topic-search-tabs`, `consumer-lag-trend`, `window-state-persistence`, `headless-script-execution`), and each item carries the user-visible fact that requires it; anything not covered by such a fact is what gets scoped down.
- Silent empty state from a fresh instance → prevented structurally by D2 (no locator path for subtree state).
- `watch_it` screens break after a reset → those four files keep resolving session-wide types from the root container; the change does not migrate them.
- Constructor parameters with locator defaults keep the locator reachable, so the count of lookups drops more slowly than the backlog's 160 suggests → the phase-1 metric is the count inside `presentation/widgets` (73 today), the gate check blocks regressions, and the remaining lookups are the defaults in the widget constructors, which the capability does not forbid.
- Diff size across ~90 files → one commit per file group, each green on `flutter test`, so any single regression is one commit to revert.
- Suite wall time: a reset plus re-registration per test adds per-test setup cost → measure the suite time after phase 1; if it grows beyond roughly double the current ~60 s, register lazily in the shared helper instead of eagerly.

## Migration Plan

1. **Phase 1 — isolation only.** Shared reset + baseline fakes in `test/flutter_test_config.dart`, delete the 10 hand-rolled resets, fix the fallout. Rollback: revert one commit; production sources are untouched.
2. **Phase 2 — session set.** Add the enumerated session set, remove the dead `TopicAnalysisController` registration, drop the unused `provider` dependency, keep every other registration working. Rollback: revert.
3. **Phase 3 — gate check.** Add the merge-base-scoped check to `scripts/quality_gates.sh`, prove it fails on a deliberately added lookup and passes on the current tree.
4. **Phase 4 — presentation sources, feature by feature.** Constructor parameters with locator defaults, subtree state moved to owners with `dispose`, in the order consumer → scripting → search → topic → settings → cluster → explorer. `lib/src/ui` is left to Q-7. Each feature commit is green on its own tests.
5. **Phase 5 — docs and planning config.** Update `openspec/config.yaml` (second planning source: `design/code-quality-refactoring-backlog.md` with its §8 change-id table; split the global-state guideline into session-scoped vs subtree-scoped) and the README quality-gate section for the new check.

Rollback at any phase: revert the phase's commits. No stored data, no bridge signature and no generated artifact is affected, so no migration or down-migration exists.

## Resolved Questions

- `provider` is dropped from `pubspec.yaml` by this change (user decision, 2026-11-21) rather than left for backlog Tier 3 item 5.
- `lib/src/ui` (21 lookups) is left to `relocate-messages-feature` (Q-7); phase 4 ends with `features/explorer`.
