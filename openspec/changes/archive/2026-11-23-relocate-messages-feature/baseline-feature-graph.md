# Baseline feature graph — relocate-messages-feature (Q-7)

Measured with the same walk `scripts/quality_gates.sh` uses for
`feature_edges` / `mutually_reachable_pairs`: one edge per importing
hand-written Dart file under `lib/src/features/`, package imports of the form
`package:kafkalyzer/src/features/<module>/`, generated sources exempt.

Merge base used for guards: `origin/main` (via `KAFKALYZER_BASE_REF`).

## After group 1 — current worktree (before any move)

### Cross-feature matrix (one count per importing file)

```text
consumer → cluster 2     consumer → navigation 1    explorer → cluster 5
explorer → navigation 1  explorer → schema 4        explorer → topic 5
navigation → cluster 1   navigation → topic 1       scripting → cluster 4
scripting → navigation 1 scripting → schema 2       scripting → search 3
scripting → topic 2      settings → cluster 5       settings → search 1
topic → cluster 4        topic → schema 4           topic → search 2
```

- **TOTAL EDGE ROWS:** 48
- **ONE-DIRECTIONAL PAIRS:** 18
- **CYCLES / MUTUALLY REACHABLE PAIRS:** none

### Surface inventory (`lib/src/ui/messages/`)

| Tree | Files | Lines |
|---|---|---|
| `lib/src/ui/messages/` | 17 | 7 028 |
| `test/src/ui/messages/` | 23 (`*_test.dart`) | 6 285 |

(The proposal/tasks said “19 test files”; the live tree has 23. Numbers above are
from `find … -name '*.dart' | xargs wc -l`.)

### External importers of `ui/messages` (7)

- `lib/src/features/consumer/presentation/topic_partition_table.dart`
- `lib/src/features/scripting/presentation/widgets/script_history/script_run_details_view.dart`
- `lib/src/features/scripting/presentation/widgets/script_history/script_run_sidebar.dart`
- `lib/src/features/search/presentation/controllers/multi_search_controller.dart`
- `lib/src/features/topic/presentation/controllers/message_stream_controller.dart`
- `lib/src/features/topic/topic_detail_view.dart`
- `lib/src/services/message_export_service.dart`

### Projected plain `git mv` (treat `ui/messages` as feature `messages`, no inversions)

Outgoing from `messages`: `cluster`, `navigation`, `schema`, `scripting`, `topic`

Incoming to `messages`: `consumer`, `scripting`, `search`, `topic`

**10 mutually reachable pairs:**

- `messages` ↔ `navigation`
- `messages` ↔ `scripting`
- `messages` ↔ `search`
- `messages` ↔ `topic`
- `navigation` ↔ `scripting`
- `navigation` ↔ `search`
- `navigation` ↔ `topic`
- `scripting` ↔ `search`
- `scripting` ↔ `topic`
- `search` ↔ `topic`

Six of those pairs involve only modules that are acyclic today — the hub would
re-couple them through `messages`.

### Go/no-go: same projection after design D3–D8

Outgoing from `messages`: **empty** (surface imports no feature module)

Incoming to `messages`: `consumer`, `navigation`, `scripting`, `search`, `topic`
(existing renderers plus producers of the relocated types)

**Mutually reachable pairs: 0** — proceed.

### Locator-guard pre-check

`KAFKALYZER_BASE_REF=origin/main bash scripts/quality_gates.sh locator-guard`
→ `locator guard passed` (surface still under `lib/src/ui/`, so the three
lookups below are invisible to the presentation-subtree check).

Ambient session-wide lookups that a plain move would make visible in
`lib/src/features/messages/presentation` (baseline count 0 → would report as new):

| Line | Form |
|---|---|
| 1074–1075 | `getIt.isRegistered<ActiveConnectionController>()` / `getIt<ActiveConnectionController>()` (jump-to-original default) |
| 1378–1379 | same lookup for `activeProfile` before building `TopicSchemaInspectorView` |

Design D7 deletes both fallbacks before the move.


## After group 2 — shared message data relocated (D3–D5)

`ScriptResultMessage`, `ScriptExtraction` / `ScriptExtractionSource`,
`ExtractionUtils`, `MessageReference`, and `DlqFailureMetadata` live under
`lib/src/features/messages/domain/`. `DlqTopicDetector` stays in
`features/topic/utils/`. `script.dart` re-exports the extraction types so
existing `scripting` importers keep compiling.

### Cross-feature matrix

```text
consumer → cluster 2
consumer → navigation 1
explorer → cluster 5
explorer → navigation 1
explorer → schema 4
explorer → topic 5
navigation → cluster 1
navigation → messages 2
navigation → topic 1
scripting → cluster 4
scripting → messages 4
scripting → navigation 1
scripting → schema 2
scripting → search 3
scripting → topic 2
settings → cluster 5
settings → search 1
topic → cluster 4
topic → schema 4
topic → search 2
```

- **TOTAL EDGE ROWS:** 54
- **ONE-DIRECTIONAL PAIRS:** 20
- **CYCLES:** none
- **messages OUT:** empty · **IN:** `navigation`, `scripting`
- `lib/src/ui/messages` no longer imports `scripting/domain/`, `navigation/models/`, or `topic/utils/dlq_topic_detector.dart`.
- Remaining feature imports inside the surface (still under `ui/`): `scripting` (diff kit — group 3), `cluster`/`schema`/`topic` (inspector — group 4).

## After group 3 — diff kit in `lib/src/ui/diff/` (D6)

6 files / 1 062 lines moved from `features/scripting/presentation/widgets/diff/`
to `lib/src/ui/diff/` (tests → `test/src/ui/diff/`). `grep` for
`package:kafkalyzer/src/features/` under `lib/src/ui/diff/` is 0 for every file.
`lib/src/ui/messages/views/messages_diff_view.dart` no longer imports `scripting`.

## After group 5 — surface in `lib/src/features/messages/`

`lib/src/ui/messages/` is gone. Layout:
`features/messages/{domain,presentation/{views,widgets,models}}`.

### Cross-feature matrix

```text
consumer → cluster 2
consumer → messages 1
consumer → navigation 1
explorer → cluster 5
explorer → navigation 1
explorer → schema 4
explorer → topic 5
navigation → cluster 1
navigation → messages 2
navigation → topic 1
scripting → cluster 4
scripting → messages 5
scripting → navigation 1
scripting → schema 2
scripting → search 3
scripting → topic 2
search → messages 1
settings → cluster 5
settings → search 1
topic → cluster 4
topic → messages 2
topic → schema 4
topic → search 2
```

- **TOTAL EDGE ROWS:** 59
- **ONE-DIRECTIONAL PAIRS:** 23
- **CYCLES:** none
- **messages OUT:** empty
- **messages IN:** ['consumer', 'navigation', 'scripting', 'search', 'topic']

Size guard: follows renames (`base_path_for_size`) so a pure move of an
already-oversized file is not reported as growth. Locator + cycle guards pass
with `KAFKALYZER_BASE_REF=origin/main`.

## Group 6 — config / backlog notes

### 6.2 Boundary and locator rules in `openspec/config.yaml`

No further edit needed beyond the Tech Stack source-layout text (6.1):
- The Code Quality bullet from `break-feature-cycles` already names shared
  modules and the import-cycle guard.
- A new "shared modules must not import features" rule is deliberately **not**
  added: 11 sources under `lib/src/services/` and `lib/src/ui/` still violate
  it; that belongs to `relocate-feature-services` (Q-8).
