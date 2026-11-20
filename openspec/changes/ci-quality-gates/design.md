# Design

## Context

`.github/workflows/build.yml` is the only workflow. Its jobs: `read-only-gate` (runs `scripts/check_read_only.sh` plus its regression test), `run-tests` (Linux, `flutter test` + `cargo test`, runs on every PR and every push to `main`), three `build-*` jobs and `create-release` (all gated on `needs: [run-tests]` and on tags/`workflow_dispatch`). None of them runs a formatter, the Dart analyzer or clippy.

Measured on the current `main` (`e786fd7`):

| Check | Current result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | clean (458 files, 1.4 s) |
| `flutter analyze` | **exit 1** — 5 errors, 2 warnings |
| `cargo fmt --all --manifest-path rust/Cargo.toml --check` | clean |
| `cargo clippy --manifest-path rust/Cargo.toml --workspace --all-targets` | **30 warnings** (`kafkalyzer-core` 9, `kafkalyzer-kafka` 12 lib / 16 with tests, bridge crate 4 / 5 with tests) |

The 5 analyzer errors are `deprecated_member_use`, which `analysis_options.yaml` already escalates to `error`:

- `lib/l10n/app_localizations.dart:90,91` — generated file, `GlobalMaterialLocalizations` / `GlobalCupertinoLocalizations` deprecated in Flutter 3.47+.
- `lib/src/flex_theme_bridge.dart:8` and `lib/src/theme.dart:7` — `package:flutter/material` is deprecated in favour of `package:material_ui`, but `flex_color_scheme` 8.4 has not migrated, so the legacy import is mandatory while the bridge exists (upstream issue #310, documented in the file header).
- `test/src/flex_theme_bridge_test.dart:2` — same legacy import.

Constraints: the read-only gate job and its script are untouchable (`read-only-invariants-enforcement`), and `cargo clippy` on the Kafka crate needs the native build dependencies (`libssl-dev`, `libsasl2-dev`, `pkg-config`, …) that `run-tests` already installs.

See `proposal.md` — Why — for motivation, and `specs/static-analysis-gates/spec.md` for the requirements this design satisfies.

## Goals / Non-Goals

**Goals:**

- One gate that fails a run for any finding in the four checks, on the same trigger set that `run-tests` already uses.
- Local and CI verdicts are produced by the same commands, in the same order.
- Every exception is narrow (single file or generator output) and carries the reason that already exists in the code.

**Non-Goals (design-level, beyond the proposal's list):**

- No per-file inventory of clippy findings and no baseline file — Q-4 removes the findings instead.
- No coverage threshold, no dependency-audit step, no line-length enforcement.
- No change to how the read-only gate is triggered or reported.
- No change to any `flutter build`, Velopack packaging or release step.

## Decisions

### D1 — One new `quality-gates` job inside the existing workflow

Add `quality-gates` to `.github/workflows/build.yml` on `ubuntu-latest`, reusing the workflow-level `on:` triggers and `concurrency:` block.

- Rejected: a second workflow file (`quality.yml`). It duplicates the apt dependency block and the Rust/Flutter setup, and the two files drift.
- Rejected: appending the four steps to `run-tests`. It couples a 1-second formatter check to a job that needs the full GTK/OpenSSL toolchain, so a formatting failure only surfaces after ~7 minutes of test time, and a failing lint would hide the test result entirely.
- The job installs the same apt packages as `run-tests` because `cargo clippy --all-targets` compiles `kafkalyzer-kafka`, which links OpenSSL and Cyrus SASL. Cost: one extra apt run (~1 min).

### D2 — Warnings-as-errors, no ratchet, staged on a clean baseline

Target command: `cargo clippy --manifest-path rust/Cargo.toml --workspace --all-targets -- -D warnings`.

- Rejected: a diff-based ratchet (`cargo-clippy` on changed files only, or a checked-in baseline of known findings). It needs a new tool and a baseline file that silently grows, and it contradicts the "no repository-wide exception mechanism" requirement.
- Rejected: a permanent half-gate (`-p kafkalyzer-core` only, or clippy without `-D warnings`). Half-gating invites the untouched crates to rot.
- **Activated in two steps, because task 1.1 measured 30 warnings at `e786fd7`.** This change enables `dart format`, `flutter analyze` and `cargo fmt --check` — all three verifiably clean at the activation commit — and leaves the clippy line commented out in `scripts/quality_gates.sh` with a pointer to Q-4. The follow-up change `enable-rust-lint-gate` is one uncommented line plus a `shellcheck` run, and is valid the moment `cargo clippy --workspace --all-targets` reports zero warnings.
- Rationale for staging over blocking the whole change: the three clean checks protect the repository today, and the spec's activation requirement is written for exactly this case ("leave that check disabled and name the prerequisite change"). Blocking everything would have left the repo with zero static-analysis coverage for the 4-6 h Q-4 needs.
- Trade-off: the Rust lint check is not enforced while Q-4 is open, so new Rust lint findings can enter `main` in that window. Q-4 is therefore sequenced immediately after this change.

### D3 — Clear the 5 analyzer errors with narrow, reasoned exceptions

| Finding | Fix | Why not the alternative |
| --- | --- | --- |
| generated `app_localizations.dart:90,91` | add `footer: "// ignore_for_file: deprecated_member_use"` to `l10n.yaml` and regenerate `lib/l10n/*.dart` | editing the generated file directly is lost on the next `flutter gen-l10n` run; globally relaxing `deprecated_member_use` in `analysis_options.yaml` would delete a guardrail the project deliberately set to `error` |
| generated `flex_theme_bridge.dart:8` | emit the `ignore_for_file: deprecated_member_use` line from `scripts/gen_flex_theme_bridge.py` | hand-editing the generated file is lost on regeneration |
| `lib/src/theme.dart:7`, `test/src/flex_theme_bridge_test.dart:2` | `// ignore: deprecated_member_use` on the single legacy import line, keeping the existing comment that names flex_color_scheme #310 | the legacy import cannot be removed until flex_color_scheme migrates (tracked as Q-10 `material-ui-migration-tracking`) |
| 2 unused imports in `test/src/features/search/` | delete them | they are dead code, no exception needed |

### D4 — A single local script so CI and workstation verdicts match

Add `scripts/quality_gates.sh` (POSIX sh, ~15 lines) that runs the four checks in the order Dart format → Dart analyze → Rust format → Rust clippy, stopping on the first failure, and reference it from the workflow and from the README contributing section.

- Rejected: duplicating the four commands inline in YAML. The spec requires a locally reproducible verdict; a script is the single place both sides call.
- The script is a thin wrapper, not new tooling: no configuration file, no flags.
- Each check runs exactly as documented in `openspec/config.yaml` under "Verification", so the contributor-facing order does not fork.

### D5 — Job graph: gate blocks builds, not tests

`quality-gates` has no `needs`. The three `build-*` jobs change from `needs: [run-tests]` to `needs: [run-tests, quality-gates]`. `run-tests` keeps only `read-only-gate` as a dependency so test feedback stays fast.

- Rationale: releases ship from tags on `main`; blocking the build jobs means no artifact is ever produced from a revision with lint debt, while PRs still get the test result without waiting for the clippy compile.
- Rejected: `run-tests` also depending on `quality-gates`. It would delay the 1 298 Dart tests and the Rust tests behind a 3–6 minute clippy cold build for no additional safety.
- Note: making the check *merge-blocking* on `main` additionally requires marking it as a required status check in repository branch protection. That is a repository setting, not a file in this change; it is listed as a task with an owner (repository administrator).

### D6 — Toolchain pinning stays as-is

The job uses the same `actions-rust-lang/setup-rust-toolchain@v1` with `toolchain: stable` and `cache-workspaces: "rust"`, and `subosito/flutter-action@v2` with `channel: stable`, as the existing jobs. Pinning exact versions is deliberately not part of this change: it is a separate decision that affects builds and releases, and pinning would mask the class of failure (a new stable release adding lints) that Q-10 already tracks.

## Risks / Trade-offs

- [A new Flutter or Rust stable release adds findings and turns the gate red on unrelated PRs] → the gate failing loudly is intended; the fix is one commit that resolves the new finding. Q-10 tracks the Flutter/Material migration explicitly, and the gate never gets relaxed to unblock a build.
- [clippy cold compile makes CI slower] → ~3–6 min on the first run per cache key; `cache-workspaces: "rust"` is already configured for the other jobs. The gate runs in parallel with `run-tests`, so total wall time for a PR is unchanged.
- [`cargo clippy --all-targets` also builds test and bench targets, so an ignored or `#[cfg(test)]`-only warning becomes blocking] → accepted deliberately: the `spike_*` and `integration_*` tests in `kafkalyzer-kafka` must compile cleanly; suppressing them would hide rot in the very tests Q-11 wants to run.
- [Two apt dependency installs per PR] → ~1 min extra per PR, no caching involved. Accepted in exchange for a single workflow file.
- [`l10n.yaml` footer changes every generated localization file] → regeneration touches three tracked generated files; reviewers should expect a large generated diff with no semantic change. The change touches no `.arb` key.
- [Gate green does not mean behaviour is correct] → the gate complements, it does not replace, `flutter test`, `cargo test` or the read-only gate; the spec keeps them separate stages.

## Migration Plan

1. Confirm the three enabled checks are clean at the activation revision (`scripts/quality_gates.sh`, task 1.1/3.1 evidence), and record the clippy warning count as the work list for Q-4.
2. Add `scripts/quality_gates.sh`; run it and record the single remaining failing check (`flutter analyze`).
3. Clear the 5 analyzer errors and 2 unused imports as in D3; regenerate localizations and the theme bridge; commit the regenerated files.
4. Run `scripts/quality_gates.sh` until exit 0.
5. Add the `quality-gates` job and the `needs` change in `build.yml`; open a throwaway PR containing one deliberately unformatted file to confirm the gate fails, then revert it.
6. Ask the repository administrator to mark `quality-gates` as a required status check.

Rollback: revert the `build.yml` commit. The source fixes (unused imports, regenerated files, ignore comments) are harmless on their own and do not need to be reverted.

## Open Questions

- Should the gate also enforce the documented 120-character line limit (no tool is installed for it today)? Deferred; it does not change this design.
- Should `flutter analyze` be run on `test/` and `packages/velopack_flutter/` too, or only on `lib` + `test` as the current default (whole-project `flutter analyze` already covers `lib` and `test`)? Deferred; the current default is used.
- Exact date/commit at which `enable-rust-lint-gate` can be switched on depends on Q-4; the switch itself needs no new design.
