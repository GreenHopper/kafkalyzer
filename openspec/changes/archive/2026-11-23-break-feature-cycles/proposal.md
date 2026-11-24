# Proposal

OpenSpec change for task **Q-6** of `design/code-quality-refactoring-backlog.md`
(section 3, evidence in section 5; change id fixed by section 8).

## Why

The `features/` split is currently decorative. Measured on the current `main`
(`29f9e7f`), the feature modules import each other through **106 import edges**
and the graph contains **four import cycles**, not the three the backlog
documented at its baseline: `cluster↔topic` (6/8 edges), `topic↔schema` (8/2),
`topic↔search` (7/2) and `topic↔scripting` (1/2), which also carries the
longer cycle `scripting→search→topic→scripting`.

Every cycle is formed by view code in one feature reaching into another
feature's session-wide state or presentation widgets. That bidirectionality is
what lets a controller in one feature own the state of another — the
connection controller currently creates and caches the per-topic stream,
facts and analysis controllers — and it is why a change in one feature
regularly produces a review diff across several. Making the direction explicit
is the precondition for the Q-7 and Q-8 relocations, which both move code
between modules and would otherwise move it into a graph with no rules.

## What Changes

- Fix one import direction per feature pair and remove the eleven edges that
  close a cycle, so the feature import graph becomes acyclic. The relocations
  are moves, not rewrites: no behaviour, no UI, no signature changes.
  - The scan-step status enum, defined in a scripting controller and consumed
    by the shared progress widget and two topic widgets, moves to the shared
    widget module. This single move removes the `topic→scripting` edge and with
    it the `topic↔scripting` and `scripting→search→topic→scripting` cycles.
  - The message-consume stream seam (the stream factory type and the wrapper
    that packs the criteria into the single bridge request) moves from the
    topic module to the shared services module, so the search module no longer
    imports a topic presentation source.
  - The cluster environment badge and the insecure-TLS badge, rendered by four
    features, move to the shared widget module.
  - The topic list query and preference state, and the factory that creates and
    caches the per-topic stream, facts and analysis controllers, move out of
    the connection controller into the topic module. The connection controller
    stops importing any topic presentation source; the cluster picker receives
    a narrow "has cached topics" callback instead of the topic controller.
  - The schema diff and schema viewer dialogs receive the topic list through a
    constructor parameter instead of looking the session-wide topic controller
    up from the container. This removes the `schema→topic` edge and two lookups
    that already violate the session-wide state locator rule.
- New capability `feature-module-boundaries`: the feature import graph stays
  acyclic, items used by more than one feature live once in a shared module,
  and moving a source between modules does not change what the user sees or
  which read-only requests an action issues.
- **Modified** `static-analysis-gates`: one added requirement for an
  import-cycle guard that decides from the sources a change touches and its
  merge base, with the same no-exception-list rule as the size guard and the
  session-wide state locator guard. The guard joins `scripts/quality_gates.sh`,
  so the existing `quality-gates` CI job covers it without a workflow change.
- Update `openspec/config.yaml`: the source-layout context gains the dependency
  direction rule, the verification list gains the new guard, and
  `rules.design` gains one rule that a change must not introduce a new feature
  import cycle. Without this, the next artifact set can re-add an edge.
- No **BREAKING** changes: no public API, no bridge signature, no stored-data
  format, no user-visible behaviour.

**Read-only impact:** no new Kafka or Schema Registry calls. The set of
describe-only requests each user action issues is unchanged, and
`scripts/check_read_only.sh` passes with no new exception.

## Capabilities

### New Capabilities

- `feature-module-boundaries`: what the module layout guarantees — one
  direction per feature pair, no import cycles, single shared definition for
  anything two features render, and relocating a source between modules is
  behaviour-preserving.

### Modified Capabilities

- `static-analysis-gates`: adds the import-cycle guard requirement for the
  sources a change touches. No existing gate requirement changes.

Not re-specified: `controller-state-lifetime` already fixes which state is
session-wide and already requires that re-scoping state does not change cluster
or registry access. This change moves sources between modules; it does not add,
remove or re-scope any item of session-wide state, so no delta there.

## Impact

- Dart sources under `lib/src/features/`: `cluster` (connection controller,
  cluster picker), `topic` (topic controller, new per-topic controller factory,
  topic detail widgets), `schema` (diff and viewer dialogs), `search` (multi
  search controller, topic selection dialog), `scripting` (script runner),
  `explorer`, `settings` (import rewrite only).
- Shared modules: `lib/src/ui/` gains the badges and the status enum;
  `lib/src/services/` gains the consume-stream seam.
- `scripts/quality_gates.sh` (new guard), `scripts/test_quality_gates.sh`
  (fixture cases for it). `.github/workflows/build.yml` needs no change — the
  `quality-gates` job already runs the script.
- `openspec/config.yaml` (context and `rules.design`), and the section 8 status
  line of `design/code-quality-refactoring-backlog.md`.
- Test files move with the sources they cover; no test semantics change.
- Rust workspace, bridge, generated code, ARB files: untouched.

**Prerequisite changes:** `remove-global-controller-state` (Q-3) must already be
in place — it is, since 2026-11-21. It provides the enumerated session-wide
state set and the locator guard that the schema-dialog fix relies on. No other
prerequisite.

**Non-goals:**

- Q-7 (move `lib/src/ui/messages/` into a messages feature) and Q-8 (move the
  seven feature-owned services out of the flat services module).
- Making the shared modules a true lower layer: the 39 imports from
  `lib/src/ui/` and the 7 from `lib/src/services/` into feature code stay as
  they are, except for the items this change relocates. The guard checks
  feature-to-feature edges only.
- Moving the session-wide controllers out of the feature folders into a
  separate app-state module.
- Any change to behaviour, layout, controller lifetimes, the enumerated
  session-wide state set, or bridge signatures.
- A coverage ratchet, and a CI coverage or architecture dashboard.
