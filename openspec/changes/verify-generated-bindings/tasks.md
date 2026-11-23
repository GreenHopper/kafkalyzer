# Tasks

No Rust crate, bridge API, or ARB changes: this change adds one gate check plus
the CI setup it needs.

## 1. Spikes

- [x] 1.1 CI install method (D4): in a scratch workflow run on this branch, time `taiki-e/install-action` with `flutter_rust_bridge_codegen@2.11.1` and `cargo install flutter_rust_bridge_codegen --version 2.11.1 --locked` (cache cold and warm). Record the timings and the choice in design.md D4. Choose (a) only if `flutter_rust_bridge_codegen --version` prints exactly `2.11.1`
- [x] 1.2 CI/local agreement (Risks): in the same scratch run, run both generators on a clean checkout, then `git status --porcelain`. It must be empty, matching the local spike. If it is not empty, stop and add a Flutter version pin to this change before continuing; do not narrow the guard's path scope

## 2. Guard

- [x] 2.1 Add `check_generated_bindings` to `scripts/quality_gates.sh` per D1/D2: version check (pubspec vs Cargo vs installed, tooling error with the install command), dirty check on the bridge paths + `*.mocks.dart`, run `flutter_rust_bridge_codegen generate` and `dart run build_runner build` (tooling error with the output on non-zero exit), then report every modified or untracked path in scope
- [x] 2.2 Add the `bindings-guard` entry point, and run the guard first in the full gate (D3)
- [x] 2.3 Run `bash scripts/quality_gates.sh bindings-guard` on the real repo: it passes, and `git status` is clean afterwards

## 3. Fixtures

- [x] 3.1 In `scripts/test_quality_gates.sh`, add fake generator scripts on `PATH` (D5) and fixtures for: clean pass; modified bridge file fails and names it; stale mock fails; new untracked generated file fails; generator missing gives a tooling error; wrong version gives a tooling error; pubspec/Cargo version mismatch gives a tooling error; dirty generated file fails and the fake generator was not called; generator exit 1 gives a tooling error
- [x] 3.2 Run `bash scripts/test_quality_gates.sh`: all old and new fixtures pass

## 4. CI

- [x] 4.1 `.github/workflows/build.yml` job `quality-gates`: add the install step chosen in 1.1, reading the version from `pubspec.yaml`, before `Run quality gates`
- [ ] 4.2 Show that the CI step fails on drift: on a scratch commit, edit one line of `lib/src/rust/api/kafka_types.dart`; the `quality-gates` job must fail and name that file. Drop the scratch commit

## 5. Rules, backlog, verification

- [x] 5.1 `openspec/config.yaml`: add the generated-source drift guard to verification step 6. Add one Code Quality bullet: the gate regenerates the bridge bindings and checked-in mocks with the pinned generator and fails on any difference, so commit the regenerated files with every bridge or mocked-interface change. Put the install command for the pinned generator in that bullet
- [x] 5.2 `design/code-quality-refactoring-backlog.md`: mark Q-9 implemented (bridge + mocks, `bindings-guard`, CI install method), and set its §8 status to implemented
- [x] 5.3 Full verification, every step exits 0: `cargo fmt --all --check`, `cargo clippy --workspace --all-targets`, `cargo test --workspace`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, `scripts/check_read_only.sh`, `KAFKALYZER_BASE_REF=origin/main bash scripts/quality_gates.sh`, `bash scripts/test_quality_gates.sh`; then `git status` shows no generated-file changes
