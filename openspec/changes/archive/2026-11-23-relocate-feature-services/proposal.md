# Proposal: relocate-feature-services (Q-8)

## Why

`break-feature-cycles` (Q-6) and `relocate-messages-feature` (Q-7) left zero
cycles between feature modules — but only counted direct feature-to-feature
imports. Five shared sources under `lib/src/services/` and `lib/src/ui/` import
feature modules, so a feature reaches another feature *through* them. Counting
those paths, 7 hidden edges close **10 mutually reachable pairs** today, for
example `topic → settings_service → scripting → topic`. The cycle guard cannot
see them, because it only follows imports between feature folders.

At the same time, `lib/src/services/` still holds services whose stored data
one feature owns. Backlog §3 (Q-8) lists them, but the list is stale:

- `diff_ignore_list_service` is used by the shared diff kit (`lib/src/ui/diff/`,
  moved there by Q-7), so it must stay shared.
- `recent_topics_service` cannot go to `topic`: `topic → cluster` exists, and the
  service is written by the cluster connection controller → it belongs to
  `cluster`.
- `message_export_service` was handed over from Q-7 (it imports the messages
  domain and table model).

## What Changes

1. **Move seven feature-owned services** into the owning feature's `data/`
   folder (with their tests):
   - `topic`: `topic_analysis_history_service`, `topic_analysis_export_service`,
     `topic_list_preferences_service`
   - `search`: `saved_searches_service`
   - `messages`: `message_export_service`
   - `schema`: `local_schema_assignment_service`
   - `cluster`: `recent_topics_service`
   Stored keys and file formats are unchanged.
2. **Remove the remaining shared → feature imports**:
   - `settings_service` stops reloading the cluster and script lists after an
     import; the settings screen that started the import reloads them.
   - `storage_notice_banner` moves to the `settings` feature (only the app
     layout shows it).
   - `schema_path_utils` moves next to its only user, the smart JSON tree
     (`lib/src/ui/smart_tree/`).
   - `script_progress_widget` moves to `scripting` (its only user).
   - `SearchProgress` (a value type with no other dependencies) moves next to
     `StepStatus` in the shared progress tile, so the tile no longer imports
     the search controller.
3. **Make the composition root structural**: `main_layout.dart` moves from
   `lib/src/ui/` to `lib/src/` beside `app.dart` and `dependency_injection.dart`.
   After that, the hand-written files at the top level of `lib/src/` are the only
   non-feature sources that import features.
4. **Add a shared-module import guard** to `scripts/quality_gates.sh`: no
   hand-written source under `lib/src/ui/`, `lib/src/services/` or
   `lib/src/utils/` may import or export a feature module. No exception list.
5. **Update `openspec/config.yaml`** (source layout, the Code Quality boundary
   rule, the design "Module boundaries" rule, verification step 6) and the
   backlog (Q-8 row, §5 graph, §8 status).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `feature-module-boundaries`:
  - MODIFIED *Item Shared By Two Features Has One Definition*: the merged text
    says an item used by two features must live in a shared module, but Q-7 put
    the messages surface and its domain types (used by four features) into a
    feature module, and `openspec/config.yaml` allows that. The delta writes the
    actual rule down: one definition, either in the owning feature module
    (imported in one direction) or in a shared module, never a copy.
  - ADDED *Shared Modules Import No Feature Module*.
  - ADDED *Stored Data Service Lives With Its Owning Feature*.
- `static-analysis-gates`: ADDED *Shared Module Import Guard*.

## Impact

- **Code**: about 13 `git mv` (7 services, banner, path utils, progress widget,
  main layout, plus tests), import rewrites in roughly 40 files, one value type
  moved, the import-reload moved into the settings screen. No logic change
  besides who triggers the reload.
- **Feature graph** (projected, re-measured in task 1.2): new one-direction
  edges `settings → topic`, `settings → scripting`, `consumer → schema`,
  `search → schema`. These replace hidden paths that exist today. Direct cycles
  stay 0, and hidden pairs go from 10 to 0.
- **Guards**: new `shared-guard` entrypoint, also part of the full gate. Fixture
  tests go in `scripts/test_quality_gates.sh`.
- **Read-only**: no new Kafka or Schema Registry calls; `check_read_only.sh`
  must pass unchanged.
- **Stored data**: unchanged keys, so saved searches, recent topics, analysis
  history, topic-list preferences and local-schema assignments survive the
  update.

## Non-goals

- Splitting the three oversized message files (`split-messages-surface`).
- Moving services that several features use without one owner:
  `settings_service`, `diff_ignore_list_service`, `cluster_service`, the
  diagnostics and window-state services stay in `lib/src/services/`.
- Following imports transitively in the cycle guard. Once shared modules import
  no feature, the direct graph is the whole graph.
- Any change to what the user sees.

## Prerequisites

- `break-feature-cycles` (Q-6, archived) and `relocate-messages-feature` (Q-7,
  archived) — both merged on `quality-improvements`.
