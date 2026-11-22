#!/usr/bin/env bash
#
# kafkalyzer Source Quality Gate
#
# Runs the checks that the CI job "quality-gates" runs, so a local run and a CI
# run produce the same verdict. Stops at the first failing check.
#
# OpenSpec change: ci-quality-gates (capability: static-analysis-gates)

set -euo pipefail

# KAFKALYZER_REPO_DIR lets scripts/test_quality_gates.sh point the guard at a
# fixture repository instead of the real one.
REPO_DIR="${KAFKALYZER_REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_DIR"

# OpenSpec change: split-god-widgets (capability: static-analysis-gates)
MAX_LINES=800

# The size guard needs the revision the change started from, otherwise it cannot
# tell "already oversized" from "just became oversized".
resolve_base() {
  local base_ref="${KAFKALYZER_BASE_REF:-origin/main}"
  if ! git rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null; then
    echo "guard: cannot resolve base revision '$base_ref'" >&2
    echo "guard: fetch it, or set KAFKALYZER_BASE_REF to a known revision" >&2
    return 1
  fi
  if ! git merge-base HEAD "$base_ref"; then
    echo "guard: no merge base between HEAD and '$base_ref' (shallow clone?)" >&2
    echo "guard: use a full checkout, or set KAFKALYZER_BASE_REF" >&2
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

# OpenSpec change: remove-global-controller-state
# (capability: static-analysis-gates)
#
# Session-wide state is enumerated in the composition root. A presentation
# source must receive it from its caller instead of picking it up from the
# container, so a change may not increase the ambient lookups of a feature's
# presentation subtree. The count is taken per subtree rather than per file so
# splitting a screen into section widgets - which moves an existing lookup into a
# file that did not exist at the merge base - does not read as a new lookup.
SESSION_STATE_FILE=lib/src/dependency_injection.dart

session_state_types() {
  sed -n '/^const List<Type> sessionWideState/,/^];/p' "$SESSION_STATE_FILE" |
    { grep -oE '^  [A-Za-z][A-Za-z0-9_]*' || true; } | tr -d ' '
}

# Counts one session type's container lookups. Two shapes are allowed and are
# removed before counting, because the capability lets a caller keep its call
# sites unchanged by defaulting a parameter to the container:
#   `x ?? getIt<Type>()`
#   `x ?? (getIt.isRegistered<Type>() ? getIt<Type>() : null)`
# Both are flattened to one line first, since dart format wraps them freely and
# a line-based filter would count an allowed default as an ambient lookup.
count_lookups() {
  {
    if [ "$1" = "-" ]; then
      cat
    else
      cat "$1"
    fi
  } | tr '\n' ' ' |
    sed -E \
      -e 's/\([[:space:]]*getIt\.isRegistered<[A-Za-z0-9_]+>\(\)[[:space:]]*\?[[:space:]]*getIt<[A-Za-z0-9_]+>\(\)[[:space:]]*:[[:space:]]*null[[:space:]]*\)/container_default/g' \
      -e 's/\?\?[[:space:]]*getIt<[A-Za-z0-9_]+>\(\)/container_default/g' |
    { grep -oE "getIt<($2)>" || true; } | wc -l
}

# Sums the lookups of one session type across a source tree. $1 is the revision,
# or empty for the worktree; the worktree side is what a contributor edits.
count_tree_lookups() {
  rev="$1"
  dir="$2"
  type="$3"
  total=0
  if [ -n "$rev" ]; then
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      is_generated "$file" && continue
      total=$((total + $(git show "$rev:$file" | count_lookups - "$type")))
    done < <(git ls-tree -r --name-only "$rev" -- "$dir")
  else
    [ -d "$dir" ] || { echo 0; return; }
    while IFS= read -r file; do
      is_generated "$file" && continue
      total=$((total + $(count_lookups "$file" "$type")))
    done < <(find "$dir" -name '*.dart' | sort)
  fi
  echo "$total"
}

check_controller_locator() {
  base="$(resolve_base)" || return 1

  if [ ! -f "$SESSION_STATE_FILE" ]; then
    echo "locator guard: $SESSION_STATE_FILE not found" >&2
    return 1
  fi
  types="$(session_state_types)"
  if [ -z "$types" ]; then
    echo "locator guard: no session-wide types listed in $SESSION_STATE_FILE" >&2
    return 1
  fi

  features="$(
    {
      git diff --name-only --diff-filter=d "$base"
      git ls-files -o --exclude-standard
    } | grep -E '^lib/src/features/[^/]+/presentation/' |
      sed -E 's#^lib/src/features/([^/]+)/presentation/.*#\1#' | sort -u || true
  )"
  [ -z "$features" ] && return 0

  failed=0
  for feature in $features; do
    dir="lib/src/features/$feature/presentation"
    for type in $types; do
      before="$(count_tree_lookups "$base" "$dir" "$type")"
      now="$(count_tree_lookups '' "$dir" "$type")"
      if [ "$now" -gt "$before" ]; then
        echo "locator guard: $dir gains a container lookup of session-wide $type ($before at $base, now $now)" >&2
        echo "locator guard: receive it as a constructor parameter instead; a lookup that only moved to another file inside $dir does not count as a gain" >&2
        failed=1
      fi
    done
  done
  return "$failed"
}

# scripts/test_quality_gates.sh exercises one guard against a fixture repo.
if [ "${1:-all}" = "locator-guard" ]; then
  echo "==> session-wide state locator guard (presentation subtrees of touched features)"
  check_controller_locator
  echo "locator guard passed"
  exit 0
fi

echo "==> dart format --output=none --set-exit-if-changed lib test"
dart format --output=none --set-exit-if-changed lib test

echo "==> flutter analyze"
flutter analyze

echo "==> cargo fmt --all --manifest-path rust/Cargo.toml --check"
cargo fmt --all --manifest-path rust/Cargo.toml --check

echo "==> source file size guard (limit $MAX_LINES lines, changed files only)"
check_file_size

echo "==> session-wide state locator guard (presentation subtrees of touched features)"
check_controller_locator

# Not enabled yet: cargo clippy --manifest-path rust/Cargo.toml --workspace
# --all-targets -- -D warnings currently reports 30 pre-existing findings.
# Enable that line in the follow-up change enable-rust-lint-gate, once
# rust-ffi-parameter-objects (Q-4) has removed them.

echo "Quality gate passed."
