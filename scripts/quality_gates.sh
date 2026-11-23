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

# When a file was renamed, the new path is absent at the base. Comparing it to
# 0 lines would treat a pure move of an already-oversized file as a new growth;
# follow the rename so the line count is taken from the old path at the base.
base_path_for_size() {
  local base="$1" file="$2"
  if git cat-file -e "$base:$file" 2>/dev/null; then
    printf '%s\n' "$file"
    return 0
  fi
  local old
  old="$(
    git diff -M --name-status --diff-filter=R "$base" -- |
      awk -F'\t' -v f="$file" '$1 ~ /^R/ && $3 == f { print $2; exit }'
  )"
  if [ -n "$old" ] && git cat-file -e "$base:$old" 2>/dev/null; then
    printf '%s\n' "$old"
    return 0
  fi
  return 1
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
    if base_file="$(base_path_for_size "$base" "$file")"; then
      base_lines=$(git show "$base:$base_file" | wc -l)
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

# OpenSpec change: break-feature-cycles (capability: feature-module-boundaries)
#
# A feature module may import another one in one direction only. The cycles that
# already exist at the merge base are not reported - the guard forbids a pair of
# modules that *becomes* mutually reachable, the same base-relative style the
# size and locator guards use. Generated sources are exempt, with the same
# exemption list the size guard uses.
feature_files() {
  # $1: revision, or empty for the worktree.
  if [ -n "$1" ]; then
    git ls-tree -r --name-only "$1" -- lib/src/features | grep -E '\.dart$' || true
  else
    # The worktree is what a contributor edits, so a deleted file is simply gone
    # from the graph; find also covers files that are not tracked yet.
    { find lib/src/features -name '*.dart' || true; } | sort
  fi
}

# Prints one "from to file" line per cross-feature import. A file that cannot be
# read is a tooling error, not a missing edge: a silently smaller graph would
# report "no new cycle" for a repository the guard could not actually read.
feature_edges() {
  rev="$1"
  unreadable=0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    is_generated "$file" && continue
    if [ -n "$rev" ]; then
      if ! git cat-file -e "$rev:$file" 2>/dev/null; then
        echo "cycle guard: $file is listed at $rev but cannot be read" >&2
        unreadable=1
        continue
      fi
      source_text="$(git show "$rev:$file")"
    else
      if [ ! -f "$file" ]; then
        echo "cycle guard: $file is listed in the worktree but cannot be read" >&2
        unreadable=1
        continue
      fi
      source_text="$(cat "$file")"
    fi
    from="$(printf '%s\n' "$file" | sed -E 's#^lib/src/features/([^/]+)/.*#\1#')"
    for to in $(printf '%s\n' "$source_text" |
      { grep -oE "package:kafkalyzer/src/features/[A-Za-z0-9_]+/" || true; } |
      sed -E 's#package:kafkalyzer/src/features/([A-Za-z0-9_]+)/#\1#' | sort -u); do
      [ "$to" = "$from" ] && continue
      echo "$from $to $file"
    done
  done < <(feature_files "$rev")
  return "$unreadable"
}

# Warshall over the module set: at most a handful of modules, so the naive
# closure is cheap and keeps the whole check inside the gate script.
mutually_reachable_pairs() {
  awk '
    { e[$1 SUBSEP $2] = 1; mods[$1] = 1; mods[$2] = 1 }
    END {
      for (a in mods)
        for (b in mods)
          r[a SUBSEP b] = (a == b || (a SUBSEP b) in e) ? 1 : 0
      for (k in mods)
        for (i in mods)
          for (j in mods)
            if (r[i SUBSEP k] && r[k SUBSEP j]) r[i SUBSEP j] = 1
      for (a in mods)
        for (b in mods)
          if (a < b && r[a SUBSEP b] && r[b SUBSEP a]) print a, b
    }
  '
}

check_feature_cycles() {
  base="$(resolve_base)" || return 1

  now_edges="$(feature_edges '')" || return 1
  now_pairs="$(printf '%s\n' "$now_edges" | mutually_reachable_pairs | sort)"
  base_edges="$(feature_edges "$base")" || return 1
  base_pairs="$(printf '%s\n' "$base_edges" | mutually_reachable_pairs | sort)"

  new_pairs="$(comm -23 <(printf '%s\n' "$now_pairs") <(printf '%s\n' "$base_pairs"))"
  [ -z "$new_pairs" ] && return 0

  failed=0
  while IFS=' ' read -r a b; do
    [ -n "$a" ] || continue
    echo "cycle guard: $a and $b are mutually reachable and were not at $base" >&2
    for pair in "$a $b" "$b $a"; do
      set -- $pair
      file="$(printf '%s\n' "$now_edges" | awk -v f="$1" -v t="$2" '$1==f && $2==t {print $3; exit}')"
      echo "cycle guard:   $1 -> $2 via ${file:-an import no file lists}" >&2
    done
    echo "cycle guard: move the shared item to a shared module, or invert one direction" >&2
    failed=1
  done <<< "$new_pairs"
  return "$failed"
}


# OpenSpec change: relocate-feature-services (capability: static-analysis-gates)
#
# Shared modules (lib/src/{ui,services,utils}) must not import or re-export a
# feature module. Absolute: any finding fails. Composition root is the top
# level of lib/src/ (and lib/main.dart), which this guard does not scan.
# Generated sources use the same exemption as the size guard.
shared_files() {
  for dir in lib/src/ui lib/src/services lib/src/utils; do
    [ -d "$dir" ] || continue
    find "$dir" -name '*.dart' || true
  done | sort
}

# Prints "feature" for a path under lib/src/features/<feature>/..., else empty.
feature_from_path() {
  printf '%s\n' "$1" | sed -nE 's#^lib/src/features/([^/]+)/.*#\1#p'
}

# Resolve an import/export target relative to $1 (source file) into a
# repo-relative path, or empty when it is not a path into this package.
resolve_import_target() {
  local src="$1" target="$2"
  case "$target" in
    package:kafkalyzer/src/*)
      printf 'lib/src/%s\n' "${target#package:kafkalyzer/src/}"
      return 0
      ;;
    package:* | dart:*)
      return 1
      ;;
  esac
  # Relative path: resolve against the source directory.
  local abs
  abs="$(cd "$(dirname "$src")" && realpath -m -- "$target" 2>/dev/null)" || return 1
  case "$abs" in
    "$REPO_DIR"/*) printf '%s\n' "${abs#"$REPO_DIR"/}" ;;
    *) return 1 ;;
  esac
}

check_shared_imports() {
  failed=0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    is_generated "$file" && continue
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
      echo "shared guard: $file is listed in the worktree but cannot be read" >&2
      failed=1
      continue
    fi
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      target="$(printf '%s\n' "$line" | sed -E "s/^(import|export)[[:space:]]+['\"]([^'\"]+)['\"].*/\2/")"
      [ -n "$target" ] || continue
      [ "$target" = "$line" ] && continue
      resolved="$(resolve_import_target "$file" "$target" || true)"
      [ -n "$resolved" ] || continue
      feat="$(feature_from_path "$resolved")"
      [ -n "$feat" ] || continue
      echo "shared guard: $file → $feat" >&2
      failed=1
    done < <(grep -E '^(import|export)[[:space:]]+' "$file" || true)
  done < <(shared_files)
  return "$failed"
}

# scripts/test_quality_gates.sh exercises one guard against a fixture repo.
if [ "${1:-all}" = "cycle-guard" ]; then
  echo "==> feature import-cycle guard (new mutual reachability)"
  check_feature_cycles
  echo "cycle guard passed"
  exit 0
fi

if [ "${1:-all}" = "locator-guard" ]; then
  echo "==> session-wide state locator guard (presentation subtrees of touched features)"
  check_controller_locator
  echo "locator guard passed"
  exit 0
fi

if [ "${1:-all}" = "shared-guard" ]; then
  echo "==> shared-module import guard (ui/services/utils must not import features)"
  check_shared_imports
  echo "shared guard passed"
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

echo "==> feature import-cycle guard (new mutual reachability)"
check_feature_cycles

echo "==> shared-module import guard (ui/services/utils must not import features)"
check_shared_imports

# Not enabled yet: cargo clippy --manifest-path rust/Cargo.toml --workspace
# --all-targets -- -D warnings currently reports 30 pre-existing findings.
# Enable that line in the follow-up change enable-rust-lint-gate, once
# rust-ffi-parameter-objects (Q-4) has removed them.

echo "Quality gate passed."
