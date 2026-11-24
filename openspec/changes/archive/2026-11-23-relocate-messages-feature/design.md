# Design

## Context

`lib/src/ui/messages/` (17 files, 7 028 lines, 19 test files / 6 285 lines) is
the message presentation surface: table view, timeline view, diff view,
inspector panel, cards, sort and projection helpers. Four features render
through it — `topic`, `consumer`, `search`, `scripting` — and it reaches back
into five feature modules. See proposal.md for the measured graph and the
projected 10 mutually reachable pairs a plain move produces.

Two of those back-references are not imports of data but fallbacks inside the
inspector panel:

- `message_inspector_panel.dart:1074-1075` looks `ActiveConnectionController`
  up from the container to run `openTopicByNameWithFeedback` (which lives in
  `features/topic/topic_utils.dart:14`) when a DLQ card asks to jump to the
  original message. A `onJumpToOriginalMessage` callback parameter already
  exists — the lookup is only its default.
- `message_inspector_panel.dart:1378-1379` looks the same controller up again
  to get a profile, then builds `TopicSchemaInspectorView` itself, even though
  `MessagesView` already accepts a `schemaViewBuilder` slot that `topic` uses.

Constraints that shape the approach: the import-cycle guard and the locator
guard from `break-feature-cycles` are live in `scripts/quality_gates.sh`; the
size guard reports only growth past 800 lines, so the three oversized files in
this surface are not blocked; `test/l10n/hardcoded_strings_allowlist.txt` is
keyed by source path.

## Goals / Non-Goals

**Goals:**
- `messages` is a feature module in the house layout and imports **no other
  feature module** — it becomes a sink that four features render through.
- Every item two modules need has exactly one definition, in the module that
  owns the concept or in an existing shared module; no duplicated type is kept
  to keep a build green.
- The moved sources stop reading session-wide state from the container, so they
  conform to `controller-state-lifetime` instead of merely escaping its guard.
- The move is reviewable as a move: each `git mv` step changes import lines and
  nothing else, in its own commit.

**Non-Goals:**
- No split of `messages_table_view.dart`, `message_inspector_panel.dart`,
  `messages_view.dart`; no line-count churn of any kind.
- No new controller in the messages module: streaming, topic caches and search
  sessions stay where they are (`TopicStore`, `MessageStreamController` in
  `topic`).
- No move of `lib/src/services/message_export_service.dart` (imports this
  surface; `relocate-feature-services` owns it), and no move of
  `openTopicByNameWithFeedback` out of `features/topic/topic_utils.dart` even
  though it takes a cluster controller — noted as follow-up debt.
- No change to which read-only requests a user action issues, and no new guard.

## Decisions

**D1 — `messages` becomes a feature module, not a shared lower layer.**
Layout: `lib/src/features/messages/presentation/{views,widgets}`,
`presentation/models`, `domain`. Alternative considered: keep the surface in
`lib/src/ui/` and declare it a lower layer. Rejected: it would then be a shared
module that imports five features, and the rule added by `break-feature-cycles`
("an item two features need lives in a shared module") would be inverted into a
licence for shared UI to depend on features — 11 other files under
`lib/src/services/` and `lib/src/ui/` already import features, and making that
legal is not what the boundary work is for.

**D2 — Relocate the shared items first, then move the surface.**
Doing the inversions first means the `git mv` commit contains only path changes,
which is what makes a 7 000-line move reviewable and revertible. Alternative:
one big commit; rejected for review and revert reasons.

**D3 — Script-run message data moves into the messages module.**
`ScriptResultMessage` (scripting/domain/script_result_message.dart, 20 L),
`ScriptExtraction` (from scripting/domain/script.dart) and `ExtractionUtils`
(scripting/domain/extraction_utils.dart) become
`features/messages/domain/…`; `scripting` builds them and imports them from
there, the messages surface renders them. Alternative: move them to
`lib/src/services/`. Rejected: they carry no cross-feature logic, only the step
labels this surface renders, and `lib/src/services/` is exactly the flat pile
`relocate-feature-services` is meant to break up.

**D4 — `MessageReference` moves into the messages module.**
105 lines, produced when the user copies or shares a message reference from the
table view and consumed by the command palette and quick-jump. After the move
`navigation` imports it from `messages`, and `messages` imports nothing from
`navigation`. Alternative: `lib/src/services/` — rejected as in D3.

**D5 — The DLQ file is split along the ownership line, not moved whole.**
`DlqFailureMetadata` (parses failure metadata out of message headers, used only
by this surface) becomes `features/messages/domain/dlq_failure_metadata.dart`;
`DlqTopicDetector` (topic-name conventions, used by `topic` and `explorer`)
stays in `features/topic/utils/`. Alternative: move the whole 256-line file to
`lib/src/utils/`; rejected, it would put topic naming conventions in a util pile
and leave `topic` importing outward for nothing.

**D6 — The diff widget kit becomes shared UI.**
`features/scripting/presentation/widgets/diff/` (6 files, 1 062 lines) moves to
`lib/src/ui/diff/`; `scripting` (`script_schemas_view.dart`) and
`messages/views/messages_diff_view.dart` both import it from there.
Alternative: move it into `features/messages/` — also acyclic, but wrong:
`scripting` uses it for schema diffs, so neither feature owns diff UI.
`lib/src/ui/` after this change holds app chrome plus genuinely
feature-neutral UI (smart tree, diff kit, shared utils), which is what the
config layout text will say.

**D7 — The inspector's two fallbacks are deleted, not ported.**
`onJumpToOriginalMessage` becomes a required parameter; the `getIt` lookup that
served as its default is removed. The schema tab arrives through the builder
slot `MessagesView` already has, so the panel's own
`TopicSchemaInspectorView` construction and its second `ActiveConnectionController`
lookup go away; the "no active cluster" empty state moves with the builder to
the caller that knows the cluster.
Alternatives considered: a `lib/src/services/` port in the style of Q-6's
`TopicNameSource`/`TopicStore`, and passing an `ActiveConnectionController`
parameter. Rejected: the panel needs an *action* and a *widget*, not a data
source, and a controller-typed parameter would keep the `messages → cluster`
import that this decision exists to remove. A closure costs one line per call
site (`messages_view.dart:1189`, `consumer/presentation/topic_partition_table.dart:107`).

**D8 — `topic_utils` usage in the inspector is cut, not relocated.**
`features/topic/topic_utils.dart` is imported for `openTopicByNameWithFeedback`
and the `TopicMetadataFacts` extension. D7 removes the first. For the second,
the formatted topic text is produced by the caller and passed in — the extension
stays in `topic`. Alternative: move the extension to `lib/src/utils/`; rejected
for now because it is topic semantics and only one call site in this surface
needs it. If the call turns out to be deeper than one formatting helper, this is
the one decision in this design that may flip to the move during implementation.

**D9 — Tests move 1:1 with their sources; the path-keyed allowlist follows.**
`test/src/ui/messages/` → `test/src/features/messages/`, `test/src/features/navigation/models/message_reference_test.dart`
stays where its subject was, so it follows the type to `messages`. No assertion
is rewritten; a test that needs a rewritten assertion is a behaviour change and
gets reverted and reported. `test/l10n/hardcoded_strings_allowlist.txt:21` gains
the new path for `message_inspector_panel.dart`.

**D10 — No guard change, and no exception list.**
The guards are run at each checkpoint below. If a guard reports something the
move caused, the move is fixed, not the guard; this mirrors the
`static-analysis-gates` requirements "No Repository-Wide Exception Mechanism"
and "Gate Verdict Reproducible Locally".

## The 19 back-references and where each goes

| File in the surface | Imports today | Decision |
|---|---|---|
| `messages_view.dart` | `scripting/domain/script.dart`, `scripting/domain/script_result_message.dart`, `services/message_export_service.dart` | D3; service import stays (Q-8) |
| `views/messages_table_view.dart` | `navigation/models/message_reference.dart`, `scripting/domain/script_result_message.dart` | D4, D3 |
| `views/messages_timeline_view.dart` | `scripting/domain/{script_result_message,script,extraction_utils}.dart` | D3 |
| `views/messages_diff_view.dart` | `scripting/…/diff/{diff_ignore_list_dialog,diff_ignore_suggestions,message_diff,json_diff_widget}.dart`, `services/diff_ignore_list_service.dart` | D6; service import stays (Q-8) |
| `widgets/message_metadata_card.dart` | `scripting/domain/script_result_message.dart` | D3 |
| `widgets/dlq_failure_diagnostics_card.dart` | `topic/utils/dlq_topic_detector.dart` | D5 |
| `widgets/message_inspector_panel.dart` | `cluster/…/active_connection_controller.dart`, `schema/…/local_schema_error_formatter.dart`, `schema/…/topic_schema_inspector_view.dart`, `navigation/models/message_reference.dart`, `topic/topic_utils.dart`, `topic/utils/dlq_topic_detector.dart` | D7, D4, D5, D8 |

## Migration Plan

1. Record the baseline: current matrix (48 cross-feature import files, zero
   cycles), the projected matrix of a plain move (10 pairs), the 7 external
   importing files, and the three inspector lookups. This is the go/no-go
   measurement, not a guess.
2. Relocate `ScriptResultMessage`, `ScriptExtraction`, `ExtractionUtils`,
   `MessageReference`, `DlqFailureMetadata` (D3-D5) and the diff kit (D6) in
   separate `git mv` commits, rewriting importers each time.
   Checkpoint: `flutter analyze`, `flutter test test/src/ui/messages test/src/features`,
   `quality_gates.sh cycle-guard` — still zero cycles, because the surface is
   still outside `features/`.
3. Delete the inspector fallbacks and add the injected callback/builder plus the
   profile parameter; wire `messages_view.dart` and
   `consumer/presentation/topic_partition_table.dart` and their callers (D7).
   Checkpoint: widget tests for the inspector and the DLQ card, and
   `quality_gates.sh locator-guard`.
4. `git mv lib/src/ui/messages lib/src/features/messages` with the house layout,
   then `git mv test/src/ui/messages test/src/features/messages`; rewrite import
   paths mechanically; update the l10n allowlist path (D9).
   Checkpoint: full `flutter analyze`, `flutter test`, and `quality_gates.sh`
   with all guards — this is the commit the guards decide.
5. Update `openspec/config.yaml` layout text and the backlog rows.

Rollback: each `git mv` is a revertible commit; the move commit touches no
behaviour, so `git revert` of it restores the old layout without touching the
relocations that precede it.

## Risks / Trade-offs

- [A `git mv` of 17 files with 44 importing files hides a semantic change in
  the diff] → Steps 2 and 3 land before step 4, and step 4's diff is verified to
  contain only path lines (`git show --stat` plus a grep for changed lines that
  are not imports).
- [The injected schema/closure parameters are optional at some call site, so a
  schema tab or a jump silently disappears] → the parameters are required where
  the fallback was deleted, and the existing inspector widget tests that assert
  the schema tab and the jump action keep running against the injected version.
- [Diff-kit move to `lib/src/ui/diff/` touches generated-looking test names and
  the DI import] → the move is one commit; `dart run build_runner build` is not
  expected to change, and any regenerated mock file is reported.
- [Cycle guard baselines are per merge base: a reviewer running without
  `KAFKALYZER_BASE_REF` may see a different verdict] → tasks pin the base ref in
  the verification command, as in `break-feature-cycles`.
- [The three >800-line files keep growing while unsplit] → the guard reports any
  growth past 800 lines, so the split stays urgent rather than invisible; the
  follow-up id is recorded in the backlog by this change.

## Open Questions

- Whether `MessageReference` keeps its current public surface or gains the
  `TopicName`-style typed accessors the palette wants — cosmetic, does not
  change this plan.
