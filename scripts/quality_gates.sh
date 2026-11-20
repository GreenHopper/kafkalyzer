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

# OpenSpec change: split-god-widgets (capability: static-analysis-gates)
MAX_LINES=800

# The size guard needs the revision the change started from, otherwise it cannot
# tell "already oversized" from "just became oversized".
resolve_base() {
  local base_ref="${KAFKALYZER_BASE_REF:-origin/main}"
  if ! git rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null; then
    echo "size guard: cannot resolve base revision '$base_ref'" >&2
    echo "size guard: fetch it, or set KAFKALYZER_BASE_REF to a known revision" >&2
    return 1
  fi
  if ! git merge-base HEAD "$base_ref"; then
    echo "size guard: no merge base between HEAD and '$base_ref' (shallow clone?)" >&2
    echo "size guard: use a full checkout, or set KAFKALYZER_BASE_REF" >&2
    return 1
  fi
}

is_generated() {
  case "$1" in
    *.g.dart | *.freezed.dart | lib/src/rust/* | lib/l10n/*) return 0 ;;
    *) return 1 ;;
  esac
}

check_file_size() {
  base="$(resolve_base)" || return 1
  files="$(
    {
      # Diff the worktree against the base: covers committed, staged and
      # uncommitted edits, so a local run matches the CI verdict.
      git diff --name-only --diff-filter=d "$base"
      git ls-files -o --exclude-standard
    } | grep -E '^lib/.*\.dart$' | sort -u || true
  )"
  [ -z "$files" ] && return 0

  failed=0
  for file in $files; do
    is_generated "$file" && continue
    # The worktree is what a contributor edits; in CI it equals HEAD.
    [ -f "$file" ] || continue
    lines=$(wc -l <"$file")
    if git cat-file -e "$base:$file" 2>/dev/null; then
      base_lines=$(git show "$base:$file" | wc -l)
    else
      base_lines=0 # new file: there is no earlier revision to compare against
    fi
    if [ "$lines" -gt "$MAX_LINES" ] && [ "$base_lines" -le "$MAX_LINES" ]; then
      echo "size guard: $file has $lines lines (limit $MAX_LINES, $base_lines at $base)" >&2
      failed=1
    fi
  done
  return "$failed"
}

echo "==> dart format --output=none --set-exit-if-changed lib test"
dart format --output=none --set-exit-if-changed lib test

echo "==> flutter analyze"
flutter analyze

echo "==> cargo fmt --all --manifest-path rust/Cargo.toml --check"
cargo fmt --all --manifest-path rust/Cargo.toml --check

echo "==> source file size guard (limit $MAX_LINES lines, changed files only)"
check_file_size

# Not enabled yet: cargo clippy --manifest-path rust/Cargo.toml --workspace
# --all-targets -- -D warnings currently reports 30 pre-existing findings.
# Enable that line in the follow-up change enable-rust-lint-gate, once
# rust-ffi-parameter-objects (Q-4) has removed them.

echo "Quality gate passed."
