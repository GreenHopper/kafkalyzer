# Proposal

## Why

`lib/src/ui/messages/` is 17 hand-written files and 7 028 lines of message
presentation — table, timeline, diff, inspector, cards, sort helpers — that is
part of no feature. It is the app's largest remaining second home for UI, and
because it sits outside `lib/src/features/`, the import-direction rule that the
change `break-feature-cycles` just made enforceable cannot see it: the 19
import lines by which that surface reaches into five feature modules are not
feature-to-feature edges at all. The backlog recorded this as Q-7
(`design/code-quality-refactoring-backlog.md` section 3, id fixed in section 8).

The measurement below shows why the move cannot wait: the surface imports
`scripting`, `topic`, `navigation`, `schema` and `cluster`, and is imported by
`consumer`, `scripting`, `search` and `topic`. A plain `git mv` would make it a
feature module and re-couple four of the modules that `break-feature-cycles`
just separated. Doing the move while the graph is still acyclic is cheap;
re-doing it after the graph drifts back is not.

## What Changes

- `lib/src/ui/messages/` becomes the feature module `lib/src/features/messages/`
  (`presentation/views`, `presentation/widgets`, `presentation/models`,
  `domain`), and `test/src/ui/messages/` moves with it (19 files, 6 285 lines).
- The items the surface needs from other features get one home in a shared or
  owning module, so the moved surface keeps its direction:
  - `ScriptResultMessage` (script-run message with step labels, 20 lines) and
    the extraction label type it is rendered with move to the messages module,
    which is where they are read; `scripting` then imports them.
  - `MessageReference` (105 lines) moves to the messages module; `navigation`
    keeps importing it from there.
  - The DLQ failure-metadata reader (`DlqFailureMetadata`, part of
    `lib/src/features/topic/utils/dlq_topic_detector.dart`, 256 lines) moves to
    a shared util; `topic` and `explorer` read it from there.
  - The diff widget kit (`lib/src/features/scripting/presentation/widgets/diff/`,
    6 files, 1 062 lines) moves to `lib/src/ui/diff/` — it is diff UI that both
    `scripting` and the messages surface use, and neither owns it.
- The inspector panel stops pulling the schema detail and the active connection
  out of the container: its existing `schemaViewBuilder` slot becomes the only
  way to get a schema tab, the fallback that builds `TopicSchemaInspectorView`
  itself is deleted, and the cluster profile it renders arrives as a
  constructor parameter. Three ambient lookups of session-wide state
  (`ActiveConnectionController` at `message_inspector_panel.dart:1074-1075`
  and `1378-1379`) become parameters — the deviation from the
  `controller-state-lifetime` requirement that the locator guard only reports
  once the file lives in a feature subtree.
- Callers (`topic_detail_view.dart`, consumer lag, `multi_search_controller`,
  the two script-run views, `explorer_view.dart`) change import paths only, apart
  from supplying the inspector's new parameters.
- `test/l10n/hardcoded_strings_allowlist.txt` is path-keyed and gains the new
  path for `message_inspector_panel.dart`.
- `openspec/config.yaml` source-layout text is corrected: `lib/src/ui/` holds
  app chrome and genuinely feature-neutral UI, a surface with its own views,
  widgets and models is a feature even when several features consume it. This
  is the layout text that `break-feature-cycles` deliberately left alone
  because Q-7 changes it.
- Not in this change: splitting `messages_table_view.dart` (1 598 L),
  `message_inspector_panel.dart` (1 416 L) and `messages_view.dart` (1 297 L);
  relocating `lib/src/services/message_export_service.dart`, which imports this
  presentation surface (Q-8 `relocate-feature-services`); any change to which
  read-only requests a user action issues.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None — this change adds no requirement and changes no observable behaviour, so
`.openspec.yaml` sets `skip_specs: true`:

- The guarantees this change rests on — one import direction per feature pair,
  one definition for an item two modules share, and a source move that changes
  nothing the user sees — are already required by `feature-module-boundaries`,
  introduced by `break-feature-cycles` and not yet archived.
- The inspector-panel fix closes a deviation from
  `controller-state-lifetime` (session-wide state reached through a constructor
  parameter), which the project rules say to describe as a fix without a spec
  delta.
- The quality gate gains no new check: the import-cycle and locator guards
  landed in `break-feature-cycles` and are the reason the move has to invert
  dependencies rather than carry them.

## Impact

- **Measured now, before any move:** the surface has 19 import lines into 5
  feature modules and is imported by 7 files in 4 feature modules plus
  `lib/src/services/message_export_service.dart`. Projecting a plain `git mv`
  onto the current graph (48 cross-feature import files, zero cycles) yields
  **10 mutually reachable pairs**: `messages`↔`scripting`, `messages`↔`topic`,
  `messages`↔`search`, `messages`↔`navigation`, plus `scripting`↔`topic`,
  `scripting`↔`search`, `scripting`↔`navigation`, `topic`↔`search`,
  `topic`↔`navigation`, `search`↔`navigation`. Six of those pairs involve only
  modules that are acyclic today — the hub would re-couple them through
  `messages` even where nothing imports `messages` directly.
- **Guards that react:** the import-cycle guard fails on those 10 pairs; the
  locator guard reports the three `ActiveConnectionController` lookups as new
  (the subtree `lib/src/features/messages/presentation` has a baseline of zero);
  the size guard does *not* react — the three oversized files are already over
  800 lines at the merge base and the guard only reports growth.
- **Read-only invariant:** no new Kafka or Schema Registry call.
  `scripts/check_read_only.sh` passes unchanged, no new exception.
- **Tests:** 19 test files move; their imports and any `package:kafkalyzer/…`
  path in `test/l10n/hardcoded_strings_allowlist.txt` follow. No test assertion
  changes.
- **Dependency:** `break-feature-cycles` must be archived before this change is
  archived, so the `feature-module-boundaries` requirements this change relies
  on are in the main specs. Its guard is already live on `quality-improvements`,
  so this change is bound by it either way.
