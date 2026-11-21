# Proposal

## Why

Every controller is a process-global lazy singleton, and every presentation widget reaches it through the service locator: `getIt<…>()` appears 160× under `lib/src/features` and 21× under `lib/src/ui` (73× in `features/*/presentation/widgets` across 30 files), and `lib/src/dependency_injection.dart` registers 11 controllers that way. Two consequences are already visible in the repository. First, the four destination views are built by a `switch` in `lib/src/ui/main_layout.dart:306-311`, so leaving a tab disposes its widget subtree — the only reason a user gets their search tabs, lag table and script run back is that the state sits in a global singleton. Second, no widget can be handed a failing or fake controller, so the flaky-test workarounds keep coming (last one: `e786fd7` "Fix timing-sensitive Flutter tests"), and `test/flutter_test_config.dart` never resets the container: 51 test files touch `getIt`, 46 of them call `getIt.reset()` by hand (67 occurrences, mostly in `setUp`), and the rest inherit each other's controllers.

Source: task **Q-3** in `design/code-quality-refactoring-backlog.md` (§2), change id `remove-global-controller-state` (§8).

## What Changes

- Split controller lifetime into two documented classes and make it explicit in code:
  - **Session-scoped**: state that the specified UI must show again after the user leaves and returns to a tab (active cluster/connection, cluster list, topic search tabs, topic and schema inspection state, script controller and script runner, navigation destination, consumer-group directory). These keep one instance for the app session, but the set becomes a named, reviewable list instead of "everything is a singleton".
  - **Subtree-scoped**: state that belongs to one dialog, one panel or one run and is dead when that subtree goes away. Registered per scope instead of globally.
- **BREAKING (internal only)**: the 11 controller registrations in `lib/src/dependency_injection.dart` stop being `registerLazySingleton`. Session-scoped ones move to an explicit app-scope registration performed at startup; subtree-scoped ones become factories owned by the scope that creates them. Service registrations (`ClusterService`, `KafkaMetadataService`, `SettingsService`, `SecureStorageService`, …) stay as they are — they are stateless or already self-managed.
- Replace field-level `final x = getIt<X>()` in widget classes (58 occurrences) with constructor parameters that default to the locator lookup, so existing call sites stay unchanged and tests can pass a fake. Start with `lib/src/features/consumer/presentation/consumer_lag_view.dart`, which performs Kafka calls directly inside the widget.
- Add container reset to the shared test setup (`test/flutter_test_config.dart`) plus a reusable test harness that registers the fakes a widget test needs, then fix what the reset exposes. This is the inventory of hidden global state and lands as phase 1, before any lifetime change.
- Add one check to the existing quality gate: a changed hand-written Dart source under a feature's `presentation/widgets/` MUST NOT introduce a new service-locator lookup for a controller. Scoped to the files the change touches, no allowlist, same shape as the existing source-file size guard.
- Update `openspec/config.yaml` so the documented rules cover this repository's second planning source: add `design/code-quality-refactoring-backlog.md` with its §8 change-id table next to the roadmap reference, and split the "global state is accessed through `ActiveConnectionController` or `getIt`" guideline into the session-scoped / subtree-scoped rule this change establishes.
- No behaviour change for the user: no widget output, no Kafka or Schema Registry call, no bridge signature, no stored-data format changes.

## Capabilities

### New Capabilities

- `controller-state-lifetime`: which application state is session-wide and which belongs to a widget subtree, how long each survives navigation and dialogs, and how a caller obtains it without reaching for a process-global singleton.
- `test-execution-isolation`: every automated test starts from a clean application container, so no test inherits state, registrations or timers from a test that ran before it, and a failing or fake dependency can be supplied to the unit under test.

### Modified Capabilities

- `static-analysis-gates`: the quality gate gains a controller-locator check for hand-written presentation sources, scoped to the files a change touches, with no committed baseline or exception list.

Existing capability specs are the regression contract for this change and are **not** re-specified: `topic-search-tabs` (state of background tab sessions preserved, line 54), `consumer-lag-monitoring` and `consumer-lag-trend` (retained lag history per group), `main-navigation`, `cluster-profile-persistence`, `headless-script-execution`, `window-state-persistence`, `appearance-settings`. The lifetime split must keep every scenario in those specs passing; that constraint is written down as a requirement of `controller-state-lifetime` rather than as an edit to those specs.

## Impact

- **Code**: `lib/src/dependency_injection.dart` (registration layout), `test/flutter_test_config.dart` and a new shared test harness under `test/helpers/`, and about 70 files that call the locator — 73 lookups in `features/*/presentation/widgets` (30 files) and 87 elsewhere in `features/`. Entry points that consume singletons outside widgets: `lib/main.dart`, `lib/src/app.dart` (top-level `GoRouter`), `lib/src/features/scripting/application/headless_script_runner.dart:59,331,372`. The 21 lookups under `lib/src/ui` are left to `relocate-messages-feature` (Q-7). No Rust, no bridge (`rust/src/api/` untouched), no `lib/src/rust/` regeneration.
- **Dependencies**: none added. `provider` 6.1.5+1 is declared in `pubspec.yaml:59` and imported nowhere in `lib/` or `test/`; this change removes that declaration instead of adopting it, because scoping uses get_it plus constructor injection and keeping the declaration invites a second state system next to `watch_it` (`explorer_view.dart`, `settings_view.dart`, `settings_cluster_section.dart`, `consumer_lag_view.dart` stay on `watch_it` against the session scope). See `design.md` - D3.
- **Tests**: `test/flutter_test_config.dart` gains the reset; the 46 test files that reset manually (67 occurrences) and the 50 that register their own fakes are migrated to the shared harness. Suite size and wall time stay in the same range (1 298 tests, ~60 s).
- **Tooling**: `scripts/quality_gates.sh` gains the controller-locator check; the `quality-gates` job in `.github/workflows/build.yml` is unchanged (it already calls the script with a full checkout).
- **Docs / planning config**: `openspec/config.yaml` (backlog reference, change-id table, split global-state guideline), `README.md` quality-gate section if the new check is documented there.
- **Read-only impact**: no new Kafka or Schema Registry calls. The change moves *who holds* the object that makes existing describe-only calls; `scripts/check_read_only.sh` and its regression test stay unchanged and must pass unchanged.
- **Prerequisites**: `ci-quality-gates` (merged, archived 2026-11-20) — the new check extends the gate script it introduced. `split-god-widgets` (merged, archived 2026-11-20) — it moved the settings and explorer orchestration into widgets and `SettingsImportExportController` with injected dependencies, which is the pattern this change applies to the rest.
- **Non-goals**:
  - Re-registering services (only controllers) and removing the locator entirely — services stay locatable by design.
  - Splitting `messages_table_view.dart` and the remaining >800-line files — belongs to `relocate-messages-feature` (Q-7).
  - Feature-boundary cycles and service relocation — `break-feature-cycles` (Q-6), `relocate-feature-services` (Q-8).
  - The 21 locator lookups under `lib/src/ui`, including `main_layout.dart` and the message widgets — they move with `relocate-messages-feature` (Q-7).
  - Migrating `watch_it` to another state package, adopting `provider`, or introducing a new state-management dependency.
  - Test coverage work — `cover-test-gaps` (Q-5). No coverage threshold is added here.
  - Any user-visible behaviour, layout or copy change; no new localisation keys.
