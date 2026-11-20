#!/usr/bin/env bash
#
# kafkalyzer Source Quality Gate
#
# Runs the checks that the CI job "quality-gates" runs, so a local run and a CI
# run produce the same verdict. Stops at the first failing check.
#
# OpenSpec change: ci-quality-gates (capability: static-analysis-gates)

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> dart format --output=none --set-exit-if-changed lib test"
dart format --output=none --set-exit-if-changed lib test

echo "==> flutter analyze"
flutter analyze

echo "==> cargo fmt --all --manifest-path rust/Cargo.toml --check"
cargo fmt --all --manifest-path rust/Cargo.toml --check

# Not enabled yet: cargo clippy --manifest-path rust/Cargo.toml --workspace
# --all-targets -- -D warnings currently reports 30 pre-existing findings.
# Enable that line in the follow-up change enable-rust-lint-gate, once
# rust-ffi-parameter-objects (Q-4) has removed them.

echo "Quality gate passed."
