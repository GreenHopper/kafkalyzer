# Baseline feature graph — relocate-feature-services (Q-8)

Measured with the embedded script below (same package-import walk as
`scripts/quality_gates.sh` `feature_edges` for direct edges; shared files under
`lib/src/{ui,services,utils}/` are intermediate nodes for the hidden-path
matrix). Generated sources are exempt.

Merge base used for guards: `origin/main` (via `KAFKALYZER_BASE_REF`).

## After group 1 — current worktree (before any move)

### Direct feature matrix (package imports only)

```text
consumer → cluster 2     consumer → messages 1      consumer → navigation 1
explorer → cluster 5     explorer → navigation 1    explorer → schema 4
explorer → topic 5       navigation → cluster 1     navigation → messages 2
navigation → topic 1     scripting → cluster 4      scripting → messages 5
scripting → navigation 1 scripting → schema 2       scripting → search 3
scripting → topic 2      search → messages 1        settings → cluster 5
settings → search 1      topic → cluster 4          topic → messages 2
topic → schema 4         topic → search 2
```

- **TOTAL EDGE ROWS:** 59
- **ONE-DIRECTIONAL PAIRS:** 23
- **CYCLES / MUTUALLY REACHABLE PAIRS (direct):** none

### Shared → feature sources (11)

| Shared source | Imports |
|---|---|
| `services/message_export_service.dart` | `messages` |
| `services/saved_searches_service.dart` | `search` |
| `services/settings_service.dart` | `cluster`, `scripting` |
| `services/topic_analysis_export_service.dart` | `topic` |
| `services/topic_analysis_history_service.dart` | `topic` |
| `services/topic_list_preferences_service.dart` | `topic` |
| `ui/main_layout.dart` | `cluster`, `consumer`, `explorer`, `navigation`, `scripting`, `settings` |
| `ui/script_progress_widget.dart` | `scripting` |
| `ui/smart_tree/smart_virtual_json_tree.dart` | `schema` |
| `ui/storage_notice_banner.dart` | `cluster`, `scripting` |
| `ui/topic_progress_tile.dart` | `search` |

(`dependency_injection.dart` is composition-root and excluded from this table.)

### Hidden-path matrix (direct + paths through shared files)

One-hop new feature→feature edges that are not already direct (feature imports
shared S, S imports feature T):

```text
consumer → scripting  via services/settings_service.dart
search → cluster      via services/settings_service.dart
search → scripting    via services/settings_service.dart
settings → scripting  via services/settings_service.dart
settings → topic      via services/topic_analysis_history_service.dart
topic → scripting     via services/settings_service.dart
```

- **NEW HIDDEN ONE-HOP PAIRS:** 6
- **MUTUALLY REACHABLE FEATURE PAIRS (full graph with shared nodes):** 6
  - `navigation` ↔ `scripting`
  - `navigation` ↔ `search`
  - `navigation` ↔ `topic`
  - `scripting` ↔ `search`
  - `scripting` ↔ `topic`
  - `search` ↔ `topic`

(The proposal’s “10 pairs / 7 edges” counted relative cross-feature imports
inside `navigation/command_palette/` as direct edges. Those relative imports
are invisible to the package-only cycle guard; see note below. Live measure
with the gate’s package rule is **6** mutual pairs.)

### Note: relative cross-feature imports (cycle-guard blind spot)

These six relative imports create edges the cycle guard does not see:

- `navigation/command_palette/command_palette_dialog.dart` → `cluster`, `consumer`, `scripting`, `topic`
- `navigation/command_palette/palette_sources.dart` → `scripting`

If counted as direct, mutual pairs rise to 10 (matches the proposal). Q-8 does
not convert them: turning them into package imports would make the cycle guard
report new pairs. Out of scope; left as a follow-up.

### Measurement script

```bash
python3 openspec/changes/relocate-feature-services/measure_feature_graph.py
```

Sibling file: `measure_feature_graph.py` in this change directory.

## Task 1.2 — projected end state (D1–D6 on paper)

Same script’s edge rules, with moves applied on paper:

| Change | Effect on graph |
|---|---|
| D1 service moves | Importers of a moved service gain a direct edge to its owner (if not already) |
| D3 settings reload | `settings_service` drops `cluster`/`scripting` imports |
| D4 banner → `settings` | Adds `settings → scripting` (banner’s imports); `settings → cluster` already exists |
| D5 path utils / SearchProgress / script progress | `smart_tree` no longer imports `schema`; tile no longer imports `search`; script progress leaves shared |
| D6 `main_layout` → `lib/src/` | Leaves the shared folders |

### Projected direct pairs (27)

Current 23, plus:

- `settings → topic` (history service)
- `settings → scripting` (banner)
- `consumer → schema` (local schema assignment)
- `search → schema` (local schema assignment)

- **DIRECT CYCLES:** none
- **SHARED → FEATURE remaining:** none
- **HIDDEN / FULL-GRAPH MUTUAL PAIRS:** none (full graph equals direct)

**Go/no-go: proceed.** No projected cycle.

## Task 1.3 — stored-data keys (byte-identical after moves)

| Service | Storage | Keys / paths |
|---|---|---|
| `topic_analysis_history_service` | app support dir | folder `analysis_history/`; per-topic subdir via `directoryKeyFor(cluster, topic)` (FNV-1a hex) |
| `topic_analysis_export_service` | user-picked file | no prefs key (FilePicker JSON) |
| `topic_list_preferences_service` | SharedPreferences | `keyForCluster(clusterName)` → `topic_list_prefs_<cluster>` (see service) |
| `saved_searches_service` | SharedPreferences | prefix `search_presets_`; key `search_presets_<cluster>_<topic>` |
| `message_export_service` | user-picked file | no prefs key (FilePicker) |
| `local_schema_assignment_service` | SharedPreferences | prefix `local_schema_assignments_`; key `local_schema_assignments_<clusterId>_<topic>` |
| `recent_topics_service` | SharedPreferences | `recent_topics_history` |

## After group 5 — composition root moved

`main_layout.dart` lives at `lib/src/main_layout.dart`. Re-ran
`measure_feature_graph.py`:

- **ONE-DIRECTIONAL PAIRS:** 27 (includes `settings → topic`, `settings → scripting`,
  `consumer → schema`, `search → schema`)
- **DIRECT CYCLES:** none
- **SHARED → FEATURE:** none
- **FULL-GRAPH MUTUAL PAIRS:** none

Direct and hidden matrices are identical.
