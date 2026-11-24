# Design

## Context

See `proposal.md` — Why, for motivation. The facts that constrain the approach:

- The graph is small. Nine feature modules, 106 import edges between them, four
  cycles. Nine nodes means cycle detection is a graph walk, not an analysis
  project.
- `topic` is the hub: 33 of the 106 edges point into it, 24 point out of it.
  Every cycle passes through `topic`. Any rule that keeps the graph acyclic has
  to decide, per pair, which side moves, and the cheap side is almost always the
  one that imports *out of* `topic` only for a single shared item.
- `lib/src/ui` (39 edges into features) and `lib/src/services` (7 edges into
  features) are already coupled to feature code. They are therefore not a lower
  layer today, and this change does not make them one; they are deliberately not
  nodes in the guarded graph.
- Precedent for enforcement exists: `scripts/quality_gates.sh` already carries a
  source-size guard and a session-wide state locator guard, both scoped to the
  files a change touches, both compared against the merge base, both with no
  exception list. `scripts/test_quality_gates.sh` runs one guard against a
  throwaway git repository so the base comparison is testable.
- `remove-global-controller-state` (Q-3) already enumerated the session-wide
  state set in the composition root, and the locator guard already reads that
  list. The two schema dialogs still do a bare `getIt.isRegistered` lookup of the
  session-wide topic controller — a lookup the existing guard tolerates only
  because it predates the guard.
- `ActiveConnectionController` (725 lines) is the coupling centre: it holds the
  topic list query and preference state, memoises the topic list view, and
  creates and caches the per-topic stream, facts and analysis controllers. That
  is why `cluster` imports four `topic` presentation sources while six `topic`
  sources import `cluster` back.

## Goals / Non-Goals

**Goals:**

- Zero cycles in the feature-to-feature import graph, verified by a gate check
  that keeps it that way.
- Every relocated item keeps one definition and one owner.
- Every individual relocation is a separate, revertable step that leaves
  `flutter analyze` and `flutter test` green on its own.

**Non-Goals:**

- Design-level, beyond the proposal: no new abstraction layer, no new base
  class, no new container registration for *state* (the enumerated session-wide
  set stays exactly as it is), no change to any widget tree, and no renaming of
  public behaviour.
- The guarded graph covers `lib/src/features/*` only. `lib/src/ui`,
  `lib/src/services`, generated sources and `test/` are not nodes, so the 46
  shared-module-to-feature imports are untouched except where a relocated item
  happens to sit in them.
- Q-7 (`lib/src/ui/messages`) and Q-8 (feature-owned services) stay separate
  changes.

## Decisions

### D1 — Direction per pair, chosen by which side carries a single shared item

The allowed directions after this change:

```text
navigation, cluster  <-  topic  <-  schema
                       topic  <-  search
cluster, schema, search, topic  <-  scripting
navigation, cluster  <-  consumer, explorer, settings
schema, search, topic  <-  explorer
```

`topic` sits below `schema`, `search`, `scripting`, `explorer`, `settings` and
`consumer`, and above `cluster` and `navigation`. Alternative considered: make
`topic` the top module, which needs 27 edge removals instead of 11, or make it
the bottom module, which needs 24. Neither is smaller, and both would require
moving topic view state into the modules that render it.

### D2 — The shared scan-step status enum moves to the shared progress widget

`StepStatus` (pending/running/completed/error) is declared in the scripting
runner and imported by the shared progress widget, the script progress widget,
the topic detail progress tile, two scripting widgets and the headless script
runner. It is a presentation status of the progress widget, not of the script
runner, so it moves into the shared progress widget file, and the six importers
point there.

This single move removes the only `topic→scripting` edge and thereby both the
`topic↔scripting` cycle and the longer `scripting→search→topic→scripting`
cycle. Alternative considered: a dedicated status enum file — rejected because
the repo rule is to extend an existing shared file rather than add a new one,
and the progress widget is the item's only consumer.

### D3 — The consume-stream seam moves to the shared services module

The stream factory typedef and the wrapper that packs the criteria into the
single bridge request object live at the top of the per-topic stream controller.
The search controller needs only that seam, never the controller, which is what
creates the `search→topic` edge. Both move to a new file in the shared services
module; they reference bridge types only, so the new file imports nothing from
any feature. The topic controller keeps a thin use of the seam.

Placing it in the services module rather than in `search` keeps the topic
feature independent of the search feature, and matches the existing pattern of
services wrapping a bridge call.

### D4 — Cluster identity badges move to the shared widget module

The environment badge and the insecure-TLS badge are rendered by `cluster`,
`explorer`, `settings` and `topic`. They import only the localisation and bridge
profile types, so they move to the shared widgets directory without dragging any
feature import with them. This removes four `topic→cluster` edges and four more
from `explorer` and `settings`, which is churn this change accepts because those
files are on the path of the cycle work anyway.

### D5 — Topic-owned view state leaves the connection controller

Two blocks move out of `ActiveConnectionController` into the `topic` module:

1. The topic list query, filter, sort, favourite and unhealthy-only state, and
   the memoised topic list view. They become part of the session-wide topic
   controller, which already owns the topic cache and the topic list fetch.
   Call sites in `explorer` and the cluster picker address the topic controller
   instead; the connection controller keeps the profile, connection and TLS
   concerns only.
2. The factory and cache for the per-topic stream, facts and analysis
   controllers. These are per-topic view state, so the `topic` module owns them
   through one new class in the topic module's controllers directory, reached
   from the session-wide topic controller. `ActiveConnectionController` stops
   importing any topic presentation source.

Cache invalidation follows the topic cache: clearing the cached topic list
clears the per-topic controllers with it, which also removes the cross-feature
cleanup call the connection controller performs on disconnect today.

Alternatives considered:

- Keep the state in `cluster` and invert the direction, so `topic` may not import
  `cluster`. That needs a port for the active profile and cluster list at four
  `topic` call sites, and it leaves `cluster` owning topic state, which is the
  actual smell. Rejected.
- Register the per-topic controller registry as a new session-wide type. Rejected:
  `controller-state-lifetime` requires each entry in that set to be justified by
  a user-visible cross-destination fact, and these controllers are per-item state
  already covered by the topic controller's lifetime.

The cluster picker stops taking the topic controller and takes a narrow
"does this cluster have cached topics" predicate plus a listenable for
repaints, both supplied by its caller. The predicate is a plain function type, so
no `topic` type is named in the `cluster` module.

### D6 — Schema dialogs receive the topic names through a port, not the container

The schema diff and schema viewer dialogs list the cluster topic names to show
which topics a subject is associated with. They currently resolve the
session-wide topic controller from the container inside `initState`, which is the
`schema→topic` edge and a session-wide lookup in a presentation source.

The dialogs get a narrow read-only port in the shared services module — "the
known topic names for this profile, or unknown if they are not loaded" — and the
`topic` module provides the implementation over its own controller, wired once in
the composition root. The container fallback disappears: the parameter is
required, and the tests pass their own list.

Alternatives considered:

- Pass the names down from the callers. Rejected: one caller is a shared message
  inspector panel used by several destinations, so the parameter would have to be
  threaded through every destination that shows a message.
- Let the schema feature fetch the topic names itself. Rejected: it would issue a
  second describe-topics request for data the app already caches, against the
  shared-cache rule.
- Allow `schema→topic` and remove the eight `topic→schema` edges instead.
  Rejected: the topic detail view legitimately renders the schema inspector and
  the schema error formatting.

Because the port returns "names" or "unknown", the dialog can no longer present
an unloaded topic list as an empty association list; the existing unknown
presentation is kept.

### D7 — The topic selection dialog belongs to the topic module

The topic selection dialog takes its topics as a parameter and its only feature
import is the topic list item, while its only production caller is the script
step editor. It is a topic picker rendered with the topic list item, so the file
and its test move from `search` to the `topic` feature's widgets. The
`search→topic` edge disappears; the `scripting→topic` edge that replaces the old
`scripting→search` one is an allowed direction.

Alternative considered: move the topic list item to the shared widget module.
Rejected: that item uses topic helpers, so it would push feature imports into the
shared module instead of removing them.

### D8 — The gate check compares mutual reachability at the merge base and now

`scripts/quality_gates.sh` gains a third guard:

- Build the module graph from the import lines of hand-written sources under
  `lib/src/features`, one node per feature, one edge per import. Same `is_generated`
  exemption as the size guard.
- Build the same graph at the merge base with a single `git grep` over that
  revision.
- Fail when a pair of modules that was not mutually reachable at the base is
  mutually reachable now, naming the modules on the new cycle and the touched
  source carrying the added import. A pair that is already mutually reachable at
  the base stays allowed, which is the same grandfathering the size and locator
  guards use.
- A source whose imports cannot be resolved, or a missing merge base, is a
  tooling error and not a pass.

Alternatives considered:

- A Dart dev-dependency validator or a custom analyzer plugin. Rejected: a new
  dependency to justify on three platforms, and a plugin to maintain, for nine
  nodes. Bash plus `git grep` matches the two guards already in the script, runs
  in milliseconds, and keeps the local and CI verdicts identical.
- A committed allowlist of known cycles. Rejected by the existing
  `static-analysis-gates` requirement against repository-wide exception lists.
- Scanning the whole graph instead of the touched files. Rejected: the existing
  guards all use "the change touches it" scoping, and a whole-graph rule would
  fail unrelated work on the four pre-existing cycles until this change lands.

The guard is enabled last, after the relocations, because
`static-analysis-gates` requires a check to be switched on only for a revision
that already passes it.

### D9 — `openspec/config.yaml` changes with the code

Two edits, both small:

- `context.key Guidelines & Architecture / Code Quality & Style`: one bullet
  stating that feature modules import each other in one direction only, that an
  item used by two or more features lives once in a shared module, and that a
  reverse need is met by relocating the item or by a narrow port rather than by a
  new reverse import.
- `context.Verification` step 6: the enumerated `quality_gates.sh` check list
  gains the import-cycle guard. Without it the config lists a gate set that no
  longer matches the script.
- `rules.design`: one rule that a change must not add a feature import cycle and
  must say, in design, where a relocated item goes.

`context.Tech Stack / Source layout` is left alone: Q-7 and Q-8 will change that
description, and rewriting it here would pre-decide their scope.

## Risks / Trade-offs

- [Moving the topic list state changes the seam ~20 test files use, including
  two checked-in mock files] → move the affected tests with the state, keep their
  assertions, regenerate mocks with `dart run build_runner build`, and land the
  move as one commit so a revert is one revert.
- [A relocation may hide a real behaviour difference, e.g. the connection
  controller currently clears per-topic controllers on disconnect while the topic
  cache clears on a different trigger] → add one regression test per moved cache
  that asserts the same clear on cluster switch and on topic-list refresh, and
  keep the existing tests that assert "not readable" instead of "empty".
- [The cycle guard compares two revisions, so a shallow CI checkout can break
  it] → reuse the existing base-resolution helper, which already fails with a
  named tooling error when the base or merge base is unavailable.
- [Nine-node reachability computed in shell is easy to get subtly wrong] → the
  guard gets fixture cases in `scripts/test_quality_gates.sh`: new cycle fails,
  removed cycle passes, untouched pre-existing cycle passes, generated source
  exempt, unresolvable source is a tooling error.
- [Making the topic-name parameter required on the schema dialogs could turn
  "not loaded" into "no topics"] → the port returns unknown, and the dialog keeps
  its existing unavailable presentation; the existing
  "associated topics" failure test stays and gains an unknown-input case.
- [The badges and the status enum move across module boundaries that other
  in-flight changes also touch] → land the small moves first; they are the
  cheapest conflicts to rebase.

## Migration Plan

Order matters: the graph must be acyclic before the guard is switched on.

1. Small moves, one commit each: status enum, consume-stream seam, the two
   badges, the topic selection dialog. Each commit: `flutter analyze`, targeted
   `flutter test`.
2. The two bigger groups, one commit each: schema dialogs behind the topic-name
   port; topic view state out of the connection controller (with mock
   regeneration).
3. Verify the graph has no cycle (`git grep`-based listing) and only then add the
   guard to `scripts/quality_gates.sh`, plus its fixture cases. The gate must be
   green from its first run.
4. Update `openspec/config.yaml`, the section 8 status line of
   `design/code-quality-refactoring-backlog.md`, and the backlog's edge matrix in
   section 5 with the post-change numbers.

Rollback: every step is a pure move of sources and imports, so reverting the
commit restores the previous graph. No data, no stored format and no bridge
signature is involved at any step.
