# Design

## Context

See `proposal.md` — Why. Fresh measurement 2026-11-22: hand-written coverage **83.0 %**, suite **1 313** green, gap list unchanged in shape from backlog Q-5 (two dialogs still at 0 %, `script_history/` at 38 %).

Constraints that shape the approach:

- `test/flutter_test_config.dart` already resets the container; new widget tests register only what they need via `registerTestSessionState` / `provideSubstitute` (`test/helpers/test_container.dart`).
- Widget pumps already used in neighbouring tests wrap with `MaterialApp` + `AppLocalizations.localizationsDelegates` and `package:material_ui/material_ui.dart` (not `flutter/material.dart`).
- Product specs already define the behaviours; this change only adds verification (`targeted-regression-coverage`).
- Backlog §6.7: do **not** add a CI coverage ratchet below the prior hand-written baseline.

## Goals / Non-Goals

**Goals:**

- Close the ordered Q-5 gaps with the smallest set of unit/widget tests that move the floors to ≥86 % hand-written, no file under 40 % (except bootstrap), `script_history/` >70 %.
- Keep production code untouched unless a test is blocked by an existing bug (e.g. listener leak); prefer fakes over production edits.
- Document why `openspec/config.yaml` agent rules stay as they are.

**Non-Goals:**

- Coverage percentage gate in `quality_gates.sh` / CI.
- Expanding into next-tier files or `update_dialog` (already ≥40 %, not in the ordered task list).
- Refactors, l10n, bridge, Rust, or Tier 3 cleanups as a goal.

## Decisions

### D1 — New capability, not a gate delta

**Choice:** Add `targeted-regression-coverage` instead of modifying `static-analysis-gates`.

**Why:** The Done-when floors are acceptance criteria for this change and durable obligations for those paths; they are not a blocking pipeline check. Putting a % floor into `static-analysis-gates` would fight backlog §6.7 and the existing "no baseline/ratchet file" requirements.

**Rejected:** `skip_specs: true` — the user asked for Q-5 specs, and the floors + no-ratchet rule need a durable home. **Rejected:** inventing product-behaviour deltas on `headless-script-execution` / `auto-update` — behaviour is unchanged.

### D2 — Test order matches backlog (cheapest first)

**Choice:** schema simplifier → two 0 % dialogs → script_history trio → filter editor + schemas view → headless edges.

**Why:** Pure unit test first (fast feedback); then entry-point dialogs; then the directory that must cross 70 %; then deepen partial suites; headless last because existing tests already cover the happy CLI-format paths.

**Rejected:** Coverage-driven "largest uncovered file first" — `filter_expression_editor` already has a partial suite; finishing 0 % dialogs unlocks more risk per line.

### D3 — Extend existing test files where they exist

**Choice:** Add cases to `filter_expression_editor_test.dart`, `script_schemas_view_test.dart`, `script_run_details_view_test.dart`, `headless_script_runner_test.dart` rather than parallel files. New files only for surfaces with no test today (`schema_simplifier`, `topic_selection_dialog`, `parameter_values_dialog`, `script_history_list`, `script_run_sidebar`).

**Why:** Neighbour tests already own mocks and pump wrappers; duplication would drift.

### D4 — No production edits by default; pump dialogs in isolation

**Choice:** Construct dialogs/widgets with explicit constructor args and in-memory fixtures. Do not drive them through full Explorer/Script shells.

**Why:** Matches Q-3 injection pattern, keeps tests off Kafka/keyring, and avoids 1 000-line setup. If `parameter_values_dialog`'s search listener pattern makes dispose assertions fail, fix that leak in the same commit group (Tier 3 item 1 overlap) — only then.

### D5 — `openspec/config.yaml` rules: no change

**Choice:** Leave agent `context` and `rules` untouched for this change.

**Why (checked against current file):**

| Concern | Already covered? |
|---|---|
| Backlog §8 change id `cover-test-gaps` | Yes — context points at `design/code-quality-refactoring-backlog.md` and requires keeping the §8 table in step when implemented |
| How to run tests | Yes — Verification list includes `flutter test` and `quality_gates.sh` |
| Test isolation / locator | Yes — Q-3 rules + `test-execution-isolation` |
| Bridge / clippy conventions | Yes — Q-4 rules; unrelated to Q-5 |
| Coverage ratchet | Must **not** be added — backlog §6.7; owned by the new spec's "No Coverage Percentage Ratchet" requirement |

Updating config only to restate "write the Q-5 tests" would be noise. Backlog status for Q-5 is updated when the change is archived, same as Q-3/Q-4.

### D6 — Measurement command is the acceptance oracle

**Choice:** After the last test group, re-run the same awk filters documented in backlog §1 on a fresh `coverage/lcov.info` and record the three floors in the final tasks checkbox. No committed `lcov` artifact.

**Why:** `coverage/` is gitignored; stale committed numbers caused the earlier false 49.8 % scare.

## Risks / Trade-offs

- **[Risk] Widget tests chase pixels / private keys** → Mitigate: assert on visible localized labels, dialog results (`Navigator.pop` values), and public callbacks; use `find.text` / semantics already present.
- **[Risk] Partial suites look "done" while floors miss 86 %** → Mitigate: tasks end with an explicit re-measure step; if short, add cases against the largest remaining uncovered lines in the listed surfaces only (not next-tier files).
- **[Risk] script_history widgets need ScriptController / run models** → Mitigate: build minimal fake run records in the test file; `provideSubstitute` for session-wide types if the widget defaults into the container.
- **[Trade-off] No CI ratchet** → Coverage can regress after this change; accepted by backlog §6.7. Future work can re-open only with an explicit proposal.

## Migration Plan

Not a runtime migration. Land test commits in the five groups; each group keeps `flutter test` green. No rollback beyond reverting the test commits.

## Open Questions

None. Floors, file list, and config.yaml verdict are fixed by the backlog and the analysis above.
