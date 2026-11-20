# Proposal

## Why

The CI workflow runs tests and the read-only gate, but never runs a formatter, static analyzer or linter, so every style/quality rule the project already documents (`dart format`, `cargo fmt`, structured errors, 120-character lines) is unenforced. Today the repository passes those tools almost everywhere — `cargo fmt --check` is clean, `dart format` is clean, `flutter analyze` reports 7 issues, `cargo clippy` 16 warnings — which means a gate can be switched on at essentially zero cost now, and will cost steadily more the longer it waits.

Source: task **Q-1** in `design/code-quality-refactoring-backlog.md`.

## What Changes

- Add a `quality-gates` job to the existing CI workflow that runs on every pull request and every push to `main`, and that fails the run when any of these reports a finding:
  - `dart format --output=none --set-exit-if-changed lib test`
  - `flutter analyze`
  - `cargo fmt --all --manifest-path rust/Cargo.toml --check`
  - `cargo clippy --manifest-path rust/Cargo.toml --workspace --all-targets -- -D warnings` — **enabled by a follow-up change**, not in this one: task 1.1 measured 30 clippy warnings at `e786fd7`, and a check may only be switched on over a clean baseline. It becomes active the moment `rust-ffi-parameter-objects` (Q-4) removes those findings.
- Remove the existing findings that would make the gate red on its first run: the 5 `flutter analyze` errors (4 `deprecated_member_use` in generated localizations and in the legacy-Material theme bridge, 1 in a theme-bridge test) and the 2 unused imports in tests. Suppressions are per-line/per-file only and each carries the reason already documented in the code (flex_color_scheme has not migrated to `material_ui`).
- The gate is enabled in warnings-as-errors mode from the start; no repository-wide allowlist, no ratchet/baseline file.
- No application behaviour changes: no Dart, Rust or bridge source is added, no user-visible feature, no UI change.

## Capabilities

### New Capabilities

- `static-analysis-gates`: the automated enforcement of formatting, static analysis and lint cleanliness on every change, including how findings are reported, which scopes are checked, and how pre-existing findings must be cleared before a check is turned on.

### Modified Capabilities

_None. `read-only-invariants-enforcement` already specifies the read-only CI job; that job, its script and its regression test stay unchanged. No existing requirement changes._

## Impact

- **CI:** `.github/workflows/build.yml` — one new job (`quality-gates`) plus one new `needs` edge; existing `run-tests`, `build-*` and `create-release` jobs are otherwise untouched.
- **Code:** generated localizations regenerated via a `l10n.yaml` footer; `lib/src/flex_theme_bridge.dart` regenerated via `scripts/gen_flex_theme_bridge.py`; targeted `// ignore: deprecated_member_use` markers in `lib/src/theme.dart` and `test/src/flex_theme_bridge_test.dart`; two unused imports deleted in `test/src/features/search/`.
- **Configuration:** `l10n.yaml`, `scripts/gen_flex_theme_bridge.py`, `analysis_options.yaml` unchanged unless a specific finding requires a documented exception.
- **Prerequisite:** none for the three checks that land here — they are already clean (`dart format` clean, `cargo fmt --check` clean) except for the 5 `flutter analyze` errors this change fixes. `rust-ffi-parameter-objects` (Q-4) is the prerequisite **only** for the clippy check; per the activation rule that check stays switched off until Q-4 removes the 30 warnings, and the follow-up change that switches it on is named `enable-rust-lint-gate`.
- **Read-only impact:** no new Kafka or Schema Registry calls. The gate performs no network I/O against any broker or registry; it only runs local tooling. `scripts/check_read_only.sh` and its regression test are not modified.
- **Non-goals:**
  - Enforcing the 120-character line limit (no tooling exists for it in this stack; would need a new dependency).
  - `cargo clippy` fix-up work itself (that is Q-4; measured at 30 warnings across workspace targets, not 16).
  - Generated-binding drift verification (`flutter_rust_bridge_codegen generate` + `git diff`) — separate change `verify-generated-bindings` (Q-9).
  - Kafka-dependent ignored integration tests in CI — separate change `ci-kafka-integration-tests` (Q-11).
  - Test coverage ratchets or minimum-coverage thresholds.
  - Any change to release/build jobs, signing or packaging.
  - Changing the Rust or Dart lint rule set beyond what is needed to make the gate green.
