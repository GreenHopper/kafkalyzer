#!/usr/bin/env bash
#
# Automated regression test for the session-wide state locator guard in
# scripts/quality_gates.sh (OpenSpec change: remove-global-controller-state,
# capability: static-analysis-gates).
#
# The guard compares the worktree with a base revision, so every case runs
# against a throwaway git repository with a known base.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SCRIPT="$SCRIPT_DIR/quality_gates.sh"
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

git_in() {
    git -C "$TEMP_DIR" -c user.email=gate@example.invalid -c user.name=gate "$@"
}

pass() {
    echo "OK"
}

fail() {
    echo "FAILED: $1"
    exit 1
}

# Builds a fixture repository: two session-wide types, one clean presentation
# source, one source that already violates the rule at the base, one view that
# only touches a stateless service, and a composition root.
build_repo() {
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR/scripts" "$TEMP_DIR/lib/src/features/alpha/presentation/widgets"
    git_in init -q "$TEMP_DIR"
    cp "$GATE_SCRIPT" "$TEMP_DIR/scripts/quality_gates.sh"

    cat > "$TEMP_DIR/lib/src/dependency_injection.dart" << 'EOF'
final getIt = GetIt.instance;

const List<Type> sessionWideState = <Type>[
  FooController,
  BarController,
];
EOF

    cat > "$TEMP_DIR/lib/src/features/alpha/presentation/widgets/clean.dart" << 'EOF'
class CleanWidget {
  CleanWidget({FooController? foo}) : _foo = foo ?? getIt<FooController>();

  final FooController _foo;
}
EOF

    cat > "$TEMP_DIR/lib/src/features/alpha/presentation/widgets/already_oversized.dart" << 'EOF'
void buildSomething() {
  final foo = getIt<FooController>();
}
EOF

    cat > "$TEMP_DIR/lib/src/features/alpha/presentation/alpha_view.dart" << 'EOF'
void render() {
  final service = getIt<SomeStatelessService>();
}
EOF

    git_in add -A >/dev/null
    git_in commit -m base >/dev/null
    BASE_REF="$(git_in rev-parse HEAD)"
    export KAFKALYZER_REPO_DIR="$TEMP_DIR"
    export KAFKALYZER_BASE_REF="$BASE_REF"
}

run_guard() {
    "$GATE_SCRIPT" locator-guard >/dev/null 2>&1
}

expect_pass() {
    local label="$1"
    echo -n "$label ... "
    if run_guard; then
        pass
    else
        fail "$label should have passed"
    fi
}

expect_reject() {
    local label="$1"
    echo -n "$label ... "
    if run_guard; then
        fail "$label should have been rejected"
    else
        echo "OK (rejected as expected)"
    fi
}

echo "Running tests for the session-wide state locator guard..."

build_repo
expect_pass "Test 1: unchanged fixture passes"

build_repo
cat >> "$TEMP_DIR/lib/src/features/alpha/presentation/widgets/clean.dart" << 'EOF'

void helper() {
  final foo = getIt<FooController>();
}
EOF
expect_reject "Test 2: new session-wide lookup in a touched presentation source fails"

build_repo
cat > "$TEMP_DIR/lib/src/features/alpha/presentation/widgets/already_oversized.dart" << 'EOF'
void buildSomething() {}
EOF
expect_pass "Test 3: removing an existing lookup passes"

build_repo
echo "// unrelated edit" >> "$TEMP_DIR/lib/src/features/alpha/presentation/alpha_view.dart"
expect_pass "Test 4: untouched source with an existing lookup passes"

build_repo
cat > "$TEMP_DIR/lib/src/features/alpha/presentation/widgets/clean.dart" << 'EOF'
void render() {
  final service = getIt<SomeStatelessService>();
  final foo = BarController();
}
EOF
expect_pass "Test 5: stateless service and direct construction pass"

build_repo
cat >> "$TEMP_DIR/lib/src/dependency_injection.dart" << 'EOF'

void registerSessionWideState() {
  getIt.registerLazySingleton<FooController>(() => FooController());
}
EOF
expect_pass "Test 6: the composition root may wire the state"

build_repo
echo -n "Test 7: unresolvable base revision is a tooling error ... "
if KAFKALYZER_BASE_REF="definitely-not-a-ref" run_guard; then
    fail "a missing base revision must not report success"
else
    echo "OK (rejected as expected)"
fi

echo "All locator guard tests passed."
