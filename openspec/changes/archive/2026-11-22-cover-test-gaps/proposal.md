# Proposal

## Why

Hand-written Dart coverage is healthy overall (**83.0 %** measured 2026-11-22, 1 313 tests) but eight user-facing or pure-logic surfaces still sit far below that floor — two dialogs at **0 %**, the script-history directory at **38 %**, and the schema simplifier (pure logic) at **28 %**. Those gaps are the last Tier-1 item in the code-quality backlog and the cheapest remaining way to make search, scripting and schema flows regression-safe before MCP/headless work leans on them.

Source: task **Q-5** in `design/code-quality-refactoring-backlog.md` (§2), change id `cover-test-gaps` (§8).

## What Changes

- Add targeted unit and widget tests for the backlog's ordered gap list (one commit group each):
  1. `schema_simplifier` (pure Avro → display-map logic)
  2. Topic selection dialog and parameter-values dialog (both currently uncovered)
  3. Script-history list, run sidebar and run details (directory currently 38 %)
  4. Filter-expression editor and script-schemas view (largest single-file gaps with partial tests)
  5. Headless script runner edge paths (currently 68 %, required before MCP reuse)
- Re-measure with `flutter test --coverage` after each group; stop when the Done-when floors are met (see Capabilities).
- Follow existing `test-execution-isolation` and constructor-injection patterns — no production behaviour, layout, copy, bridge or Kafka changes.
- Record the measured floors and the "no CI coverage ratchet" rule in a durable capability; leave `openspec/config.yaml` agent rules unchanged (analysis below).

## Capabilities

### New Capabilities

- `targeted-regression-coverage`: which critical search, scripting, schema-display and headless paths MUST be exercised by automated verification, what the hand-written coverage floors are for this change's acceptance, and that the quality gate MUST NOT gain a line-coverage percentage ratchet.

### Modified Capabilities

- None. Existing product specs (`headless-script-execution`, `auto-update`, `search-configuration-panel`, `integrated-schema-inspector`, `ergonomic-script-workspace`, `saved-topic-searches`, `test-execution-isolation`) already define the behaviours under test; this change only adds verification. `static-analysis-gates` stays unmodified — backlog §6.7 forbids a coverage ratchet below the prior hand-written baseline, and that prohibition is owned by the new capability instead of re-opening the gate spec.

## Impact

- **Code**: test files only under `test/src/features/{schema,search,scripting,settings}/` (and helpers if a shared pump wrapper is missing). Production sources under the eight gap paths are **read for fixtures**, not rewritten; listener-leak cleanups from backlog Tier 3 item 1 are **out of scope** unless a test cannot be written without them.
- **Fresh baseline (2026-11-22)**:

  | Coverage | Uncovered | Surface |
  |---|---|---|
  | 0 % | 114 | topic selection dialog |
  | 0 % | 74 | parameter-values dialog |
  | 11 % | 186 | script-history list |
  | 28 % | 61 | schema simplifier |
  | 30 % | 215 | filter-expression editor |
  | 33 % | 200 | script-schemas view |
  | 41 % | 92 | script-run sidebar |
  | 54 % | 78 | script-run details |
  | 68 % | 56 | headless script runner |

  Hand-written `lib/`: **25 633 / 30 879 = 83.0 %**. `script_history/`: **38.2 %** (221/579). Suite: 1 313 passing.
- **Dependencies**: none.
- **Tooling / CI**: no new gate check; no change to `scripts/quality_gates.sh` or `build.yml`.
- **config.yaml rules**: **no update**. Context already points at the backlog §8 table; Verification already runs `flutter test`; a coverage ratchet would contradict backlog §6.7; test isolation and locator rules landed with Q-3. Status line for Q-5 in the backlog table is updated when this change is archived, not in agent rules.
- **Read-only impact**: no new Kafka or Schema Registry calls. Tests use substitutes per `test-execution-isolation`.
- **Prerequisites**: `remove-global-controller-state` (archived) — shared `getIt.reset()` and constructor defaults make the new widget tests fakeable. `ci-quality-gates` (archived) — analyze/format still green.
- **Non-goals**:
  - CI or local coverage percentage ratchet / baseline file.
  - Raising coverage for the next-tier files (`settings_view`, `script_runner`, `topic_detail_view`, `explorer_view`) or for `update_dialog` (already ≥40 %; not in the Q-5 ordered task list).
  - Product behaviour, l10n, bridge, Rust, or Tier 3 cleanups except where a test is blocked.
  - Enabling `clippy -D warnings` — that is `enable-rust-lint-gate`.
