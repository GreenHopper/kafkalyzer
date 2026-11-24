# Design

## Context

See proposal.md (Why) for the motivation and the two measurements: 23 direct
one-direction feature pairs with 0 cycles, and 10 mutually reachable pairs once
paths through shared sources are counted.

Shared sources that import a feature module today (`lib/src/dependency_injection.dart`
excluded):

| Shared source | Imports | Why |
|---|---|---|
| `services/message_export_service.dart` | `messages` domain + table model | exports message rows |
| `services/saved_searches_service.dart` | `search` preset model | persists presets |
| `services/topic_analysis_export_service.dart` | `topic/data` report file | writes reports |
| `services/topic_analysis_history_service.dart` | `topic/data` report file | stores reports |
| `services/topic_list_preferences_service.dart` | `topic/domain` list query | stores sidebar query |
| `services/settings_service.dart` | `cluster` + `scripting` controllers | `importConfiguration` calls `getIt<ClusterListController>().loadClusters()` and `getIt<ScriptController>().loadScripts()` (lines 603–604) |
| `ui/storage_notice_banner.dart` | `cluster` + `scripting` controllers | renders store-health warnings; only `main_layout` shows it |
| `ui/smart_tree/smart_virtual_json_tree.dart` | `schema/utils/schema_path_utils.dart` (66 L) | only importer of the util |
| `ui/script_progress_widget.dart` | `scripting` script + runner | only `scripting/.../script_run_view.dart` uses it |
| `ui/topic_progress_tile.dart` | `search` controller | needs only `SearchProgress`, a 20-line value type with no dependencies |
| `ui/main_layout.dart` | 9 feature sources | the app shell; `app.dart` is its only importer |

Constraints: the cycle, locator and size guards in `scripts/quality_gates.sh`
must stay green and unweakened. The size guard follows renames (since Q-7), so
moving `settings_service`-sized files is not reported as growth. Stored-data
keys must stay byte-identical so that saved data stays loadable.

## Goals / Non-Goals

**Goals:**
- No hand-written source under `lib/src/{ui,services,utils}/` imports a feature
  module, and a guard keeps it that way.
- Each of the seven relocated services lives in its owner's `data/` folder.
- The direct feature graph is the whole graph: hidden pairs 10 → 0, direct
  cycles stay 0.

**Non-Goals:**
- No new ports or interfaces when a move does the job. The only behavioural
  seam that changes is who triggers the post-import reload.
- No transitive cycle guard (see D7).

## Decisions

### D1 — Ownership rule: who writes the stored data owns the service

A service moves into a feature when exactly one feature defines its stored
model and writes it. Readers in other features import it in one direction.

| Service | Owner | Other importers | New direct edge |
|---|---|---|---|
| `topic_analysis_history_service` | `topic` | `settings` (delete saved reports) | `settings → topic` |
| `topic_analysis_export_service` | `topic` | — | — |
| `topic_list_preferences_service` | `topic` | — | — |
| `saved_searches_service` | `search` | — | — |
| `message_export_service` | `messages` | `search` (JSON serializer) | exists |
| `local_schema_assignment_service` | `schema` (assignment dialog writes) | `topic`, `consumer`, `search` read | `consumer → schema`, `search → schema` |
| `recent_topics_service` | `cluster` (connection controller writes) | `explorer` reads | exists |

Alternative: keep every service used by more than one feature shared, as the
merged *Item Shared By Two Features* wording says. Rejected:
`topic_analysis_history_service` and `message_export_service` would then need
their feature-owned models moved into `services/`, which would undo Q-7's
messages domain. Q-7 already applied the owner rule, and the spec delta writes
it down.

`schema` imports no feature and nothing imports `settings`, so the new edges
cannot close a cycle. Task 1.2 re-measures this before any move.

### D2 — `diff_ignore_list_service` stays shared

Its consumers are the shared diff kit (`lib/src/ui/diff/`) and `messages`. A
shared module may not import a feature (the new requirement), so it stays in
`services/`. The backlog row is corrected.

### D3 — Post-import reload moves to the caller

`SettingsService.importConfiguration` stops reloading the two controllers. The
caller in `settings/presentation/widgets/settings_config_section.dart`, which
already holds `clusterController`, reloads `ClusterListController` and
`ScriptController` after the call returns successfully. The reload happens
before the existing success feedback, so the user sees the same thing as
before. The service keeps reloading what it owns (buffer limits, appearance).

Alternative: an `onImported` callback parameter on the service. Rejected: one
more parameter for one caller, and the caller already knows when the import
finished. Tests in `test/src/services/settings_service_test.dart` and
`passphrase_redaction_test.dart` stop registering stub controllers. The
settings widget test gains one assertion that both reloads run after an import.

Failure case: if the import throws, nothing reloads, as today, because the
reload sat after the merge inside the same `try`.

### D4 — `storage_notice_banner` → `settings/presentation/widgets/`

It renders keyring, unreadable-store and duplicate-name warnings for cluster
profiles and scripts. These are storage and settings concerns, and only the app
shell shows it. This adds `settings → scripting` (`settings → cluster` exists).
Its `?? getIt` defaults are already the house pattern, and the locator guard
counts per feature subtree, so the `settings` count has to be checked in 5.x.

Alternative: treat it as app shell and move it beside `main_layout`. Rejected:
the top level of `lib/src/` would start collecting widgets, and the
composition root is meant to stay small.

### D5 — Single-consumer moves

- `schema/utils/schema_path_utils.dart` → `lib/src/ui/smart_tree/schema_path_utils.dart`
  (+ test → `test/src/ui/smart_tree/`).
- `ui/script_progress_widget.dart` → `scripting/presentation/widgets/`
  (+ test).
- `SearchProgress` → `lib/src/ui/topic_progress_tile.dart`, next to
  `StepStatus`, which Q-6 put there for the same reason. `multi_search_controller`,
  `script_runner` and `topic_detail_progress_tile` import it from there. This
  is feature → shared, which is allowed.

### D6 — Composition root becomes structural: `main_layout` → `lib/src/`

The guard needs a rule that names no files. "Shared" = `lib/src/ui/`,
`lib/src/services/`, `lib/src/utils/`. The hand-written top level of `lib/src/`
(`app.dart`, `dependency_injection.dart`, `main_layout.dart`, theme files) and
`lib/main.dart` are the composition root. Moving `main_layout.dart` there makes
the rule a folder rule with no exception list. Only `app.dart` and one test
import it.

### D7 — Guard design: absolute, worktree-based, no base ref

`check_shared_imports` lists hand-written `*.dart` under the three shared
folders, using the same generated-file exemption as the size guard. It resolves
`import`/`export` targets, both `package:kafkalyzer/src/features/…` and
relative paths that resolve under `lib/src/features/`, and fails per offending
line with `file → feature`. An unreadable listed file is a named tooling error.
Entrypoint: `bash scripts/quality_gates.sh shared-guard`. It also runs in the
full gate, after the cycle guard.

It is absolute rather than base-relative because no violation remains after
this change, so there is nothing to tolerate. That makes it simpler and
stricter than the cycle guard.

Alternative: make the cycle guard follow imports through shared files.
Rejected: `dependency_injection.dart` is imported by most features and imports
all of them, so the guard would need a composition exemption anyway. With D7 in
place, the direct graph already equals the full graph.

### D8 — Order of work: fix shared → feature first, guard last

1. Single-consumer moves and value-type move (D5): small and independent.
2. Service moves (D1), one owner per commit-sized group.
3. Reload (D3) and banner (D4).
4. `main_layout` (D6).
5. Guard + fixtures (D7), only after the tree is clean, so it lands green.

## Risks / Trade-offs

- [Stored-data keys accidentally changed during a move] → moves are `git mv`
  plus import rewrites only. Each service test runs unchanged apart from its
  import line, and the diff of each moved file is checked to be import-only
  (`git diff -M --stat` similarity ≥ 95 %).
- [Mocks generated with the old path (`*.mocks.dart`) break] → run
  `dart run build_runner build` after the moves. The generated mocks are
  checked in and regenerated, not hand-edited.
- [Import reload order changes visible feedback] → widget test asserts both
  reloads happen before the success SnackBar.
- [Locator count in `settings` rises with the banner] → the guard compares
  per-subtree counts with the merge base, and moving a file with its lookups
  raises the `settings` count. If the guard flags it, fix by having
  `main_layout` pass both controllers in (they are composition-owned) rather
  than weakening the guard.
- [Relative imports missed by the guard] → fixture tests cover the relative
  case explicitly.

## Migration Plan

Pure source re-organisation and no data migration. Roll back by reverting the
commits; stored data is untouched either way.

## Open Questions

None.
