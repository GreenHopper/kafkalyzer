#!/usr/bin/env bash
#
# Automated regression tests for the guards in scripts/quality_gates.sh: the
# session-wide state locator guard (OpenSpec change: remove-global-controller-
# state), the feature import-cycle guard (OpenSpec change: break-feature-
# cycles), the shared-module import guard (OpenSpec change:
# relocate-feature-services), the generated-source drift guard (OpenSpec
# change: verify-generated-bindings), and the legacy-material import guard
# (OpenSpec change: material-ui-migration-tracking), all under the
# static-analysis-gates capability.
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

    # Two more feature modules. alpha and beta import each other already at the
    # base, so the import-cycle guard has a pre-existing cycle to tolerate.
    mkdir -p "$TEMP_DIR/lib/src/features/beta/presentation/widgets"
    mkdir -p "$TEMP_DIR/lib/src/features/gamma/presentation"
    cat > "$TEMP_DIR/lib/src/features/alpha/presentation/alpha_imports_beta.dart" << 'EOF'
import 'package:kafkalyzer/src/features/beta/presentation/widgets/beta_widget.dart';
EOF
    cat > "$TEMP_DIR/lib/src/features/beta/presentation/widgets/beta_widget.dart" << 'EOF'
import 'package:kafkalyzer/src/features/alpha/presentation/alpha_view.dart';

class BetaWidget {}
EOF
    cat > "$TEMP_DIR/lib/src/features/gamma/presentation/gamma_view.dart" << 'EOF'
import 'package:kafkalyzer/src/features/alpha/presentation/alpha_view.dart';

class GammaView {}
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

run_cycle_guard() {
    "$GATE_SCRIPT" cycle-guard >/dev/null 2>&1
}

expect_pass() {
    local label="$1"
    echo -n "$label ... "
    if "$RUNNER"; then
        pass
    else
        fail "$label should have passed"
    fi
}

expect_reject() {
    local label="$1"
    echo -n "$label ... "
    if "$RUNNER"; then
        fail "$label should have been rejected"
    else
        echo "OK (rejected as expected)"
    fi
}

# Which guard the next expect_* call runs; the locator guard is the default.
RUNNER=run_guard

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

# OpenSpec change: split-god-widgets follow-up. A file split moves an existing
# lookup into a file that did not exist at the merge base; that is a move, not a
# gain, and must not fail the gate.
build_repo
cat > "$TEMP_DIR/lib/src/features/alpha/presentation/widgets/already_oversized.dart" << 'EOF'
void buildSomething() {}
EOF
cat > "$TEMP_DIR/lib/src/features/alpha/presentation/widgets/moved_into_new_file.dart" << 'EOF'
void buildSomethingElse() {
  final foo = getIt<FooController>();
}
EOF
expect_pass "Test 8: lookup moved into a new file in the same subtree passes"

# dart format wraps `x ?? (getIt.isRegistered<T>() ? getIt<T>() : null)` over
# several lines; the allowed default must survive that wrapping.
build_repo
cat > "$TEMP_DIR/lib/src/features/alpha/presentation/widgets/wrapped_default.dart" << 'EOF'
class WrappedWidget {
  WrappedWidget({BarController? bar}) : _bar = bar ??
      (getIt.isRegistered<BarController>()
          ? getIt<BarController>()
          : null);

  final BarController? _bar;
}
EOF
expect_pass "Test 9: wrapped null-safe container default is not an ambient lookup"

# OpenSpec change: break-feature-cycles (capability: feature-module-boundaries).
# The cycle guard compares mutual reachability with the merge base, so the
# fixture ships with an alpha<->beta cycle the guard must tolerate.
echo "Running tests for the feature import-cycle guard..."
RUNNER=run_cycle_guard

build_repo
expect_pass "Test 10: a cycle that already exists at the base passes"

build_repo
cat >> "$TEMP_DIR/lib/src/features/beta/presentation/widgets/beta_widget.dart" << 'EOF'

import 'package:kafkalyzer/src/features/gamma/presentation/gamma_view.dart';
EOF
expect_reject "Test 11: an import that makes two modules mutually reachable fails"

build_repo
rm "$TEMP_DIR/lib/src/features/alpha/presentation/alpha_imports_beta.dart"
expect_pass "Test 12: removing a cycle passes"

build_repo
cat > "$TEMP_DIR/lib/src/features/alpha/presentation/widgets/generated_bridge.g.dart" << 'EOF'
import 'package:kafkalyzer/src/features/gamma/presentation/gamma_view.dart';
EOF
expect_pass "Test 13: generated source is exempt from the cycle graph"

build_repo
rm "$TEMP_DIR/lib/src/features/gamma/presentation/gamma_view.dart"
build_repo
rm "$TEMP_DIR/lib/src/features/gamma/presentation/gamma_view.dart"
expect_pass "Test 14: deleting the source of a cycle edge passes"

build_repo
echo -n "Test 15: unresolvable base revision is a tooling error ... "
if KAFKALYZER_BASE_REF="definitely-not-a-ref" run_cycle_guard; then
    fail "a missing base revision must not report success"
else
    echo "OK (rejected as expected)"
fi

# OpenSpec change: relocate-feature-services (capability: static-analysis-gates).
# Shared folders must not import features; the composition root may.
echo "Running tests for the shared-module import guard..."
run_shared_guard() {
    "$GATE_SCRIPT" shared-guard >/dev/null 2>&1
}
RUNNER=run_shared_guard

build_repo
mkdir -p "$TEMP_DIR/lib/src/ui" "$TEMP_DIR/lib/src/services" "$TEMP_DIR/lib/src/utils"
cat > "$TEMP_DIR/lib/src/ui/clean_shared.dart" << 'EOF'
class CleanShared {}
EOF
expect_pass "Test 16: shared tree with no feature import passes"

build_repo
mkdir -p "$TEMP_DIR/lib/src/ui"
cat > "$TEMP_DIR/lib/src/ui/imports_feature.dart" << 'EOF'
import 'package:kafkalyzer/src/features/alpha/presentation/alpha_view.dart';
EOF
echo -n "Test 17: package import of a feature from shared fails and names both ... "
out="$("$GATE_SCRIPT" shared-guard 2>&1)" && fail "Test 17 should have been rejected" || true
printf '%s\n' "$out" | grep -q 'lib/src/ui/imports_feature.dart → alpha' \
  || fail "Test 17 must name the shared file and the feature"
echo "OK (rejected as expected)"

build_repo
mkdir -p "$TEMP_DIR/lib/src/ui/widgets" "$TEMP_DIR/lib/src/features/alpha/presentation"
cat > "$TEMP_DIR/lib/src/ui/widgets/relative_import.dart" << 'EOF'
import '../../features/alpha/presentation/alpha_view.dart';
EOF
expect_reject "Test 18: relative import into a feature from shared fails"

build_repo
mkdir -p "$TEMP_DIR/lib/src/services"
cat > "$TEMP_DIR/lib/src/services/reexports_feature.dart" << 'EOF'
export 'package:kafkalyzer/src/features/beta/presentation/widgets/beta_widget.dart';
EOF
expect_reject "Test 19: export of a feature from shared fails"

build_repo
mkdir -p "$TEMP_DIR/lib/src/ui"
cat > "$TEMP_DIR/lib/src/ui/generated_bridge.g.dart" << 'EOF'
import 'package:kafkalyzer/src/features/alpha/presentation/alpha_view.dart';
EOF
expect_pass "Test 20: generated .g.dart under a shared folder is exempt"

build_repo
cat > "$TEMP_DIR/lib/src/composition_root.dart" << 'EOF'
import 'package:kafkalyzer/src/features/alpha/presentation/alpha_view.dart';
EOF
expect_pass "Test 21: top-level lib/src/*.dart importing a feature passes"

build_repo
mkdir -p "$TEMP_DIR/lib/src/ui"
cat > "$TEMP_DIR/lib/src/ui/unreadable.dart" << 'EOF'
class Unreadable {}
EOF
chmod a-r "$TEMP_DIR/lib/src/ui/unreadable.dart"
echo -n "Test 22: unreadable listed shared file is a tooling error ... "
if "$GATE_SCRIPT" shared-guard >/dev/null 2>&1; then
    chmod a+r "$TEMP_DIR/lib/src/ui/unreadable.dart" 2>/dev/null || true
    fail "an unreadable shared file must not report success"
else
    chmod a+r "$TEMP_DIR/lib/src/ui/unreadable.dart" 2>/dev/null || true
    echo "OK (rejected as expected)"
fi

# OpenSpec change: verify-generated-bindings (capability: static-analysis-gates).
# Stub generators on PATH so fixtures stay offline and fast.
echo "Running tests for the generated-source drift guard..."

FAKE_BIN=""
FAKE_FRB_CALLED=""
FAKE_DART_CALLED=""

install_fake_generators() {
    FAKE_BIN="$TEMP_DIR/fake-bin"
    FAKE_FRB_CALLED="$TEMP_DIR/frb.called"
    FAKE_DART_CALLED="$TEMP_DIR/dart.called"
    mkdir -p "$FAKE_BIN"
    rm -f "$FAKE_FRB_CALLED" "$FAKE_DART_CALLED"
    cat > "$FAKE_BIN/flutter_rust_bridge_codegen" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${FAKE_FRB_CALLED:?}"
if [ "${1:-}" = "--version" ]; then
  echo "flutter_rust_bridge_codegen ${FAKE_FRB_VERSION:-2.11.1}"
  exit 0
fi
echo called >> "$FAKE_FRB_CALLED"
if [ "${FAKE_FRB_EXIT:-0}" != "0" ]; then
  echo "fake frb fail" >&2
  exit "${FAKE_FRB_EXIT}"
fi
case "${FAKE_FRB_ACTION:-noop}" in
  mutate)
    printf 'mutated-bridge\n' > lib/src/rust/api.dart
    ;;
  newfile)
    printf 'new\n' > lib/src/rust/extra_generated.dart
    ;;
  noop|*) ;;
esac
exit 0
EOF
    cat > "$FAKE_BIN/dart" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${FAKE_DART_CALLED:?}"
echo called >> "$FAKE_DART_CALLED"
if [ "${FAKE_DART_EXIT:-0}" != "0" ]; then
  echo "fake dart fail" >&2
  exit "${FAKE_DART_EXIT}"
fi
case "${FAKE_DART_ACTION:-noop}" in
  mutate)
    printf 'mutated-mock\n' > test/example.mocks.dart
    ;;
  noop|*) ;;
esac
exit 0
EOF
    chmod +x "$FAKE_BIN/flutter_rust_bridge_codegen" "$FAKE_BIN/dart"
    export PATH="$FAKE_BIN:$PATH"
    export FAKE_FRB_CALLED FAKE_DART_CALLED
    export FAKE_FRB_VERSION=2.11.1
    export FAKE_FRB_EXIT=0
    export FAKE_DART_EXIT=0
    export FAKE_FRB_ACTION=noop
    export FAKE_DART_ACTION=noop
}

build_bindings_repo() {
    build_repo
    mkdir -p "$TEMP_DIR/lib/src/rust" "$TEMP_DIR/rust/src" "$TEMP_DIR/test"
    cat > "$TEMP_DIR/pubspec.yaml" << 'EOF'
name: kafkalyzer
dependencies:
  flutter_rust_bridge: 2.11.1
EOF
    cat > "$TEMP_DIR/rust/Cargo.toml" << 'EOF'
[dependencies]
flutter_rust_bridge = "=2.11.1"
EOF
    printf 'bridge\n' > "$TEMP_DIR/lib/src/rust/api.dart"
    printf 'rs\n' > "$TEMP_DIR/rust/src/frb_generated.rs"
    printf 'mock\n' > "$TEMP_DIR/test/example.mocks.dart"
    git_in add -A >/dev/null
    git_in commit -m bindings-base >/dev/null
    BASE_REF="$(git_in rev-parse HEAD)"
    export KAFKALYZER_REPO_DIR="$TEMP_DIR"
    export KAFKALYZER_BASE_REF="$BASE_REF"
    install_fake_generators
}

run_bindings_guard() {
    "$GATE_SCRIPT" bindings-guard >/dev/null 2>&1
}

RUNNER=run_bindings_guard

build_bindings_repo
expect_pass "Test 23: clean regeneration passes"

build_bindings_repo
export FAKE_FRB_ACTION=mutate
echo -n "Test 24: modified bridge file fails and names it ... "
out="$("$GATE_SCRIPT" bindings-guard 2>&1)" && fail "Test 24 should have been rejected" || true
printf '%s\n' "$out" | grep -q 'lib/src/rust/api.dart differs from generator output' \
  || fail "Test 24 must name the drifted bridge file"
echo "OK (rejected as expected)"

build_bindings_repo
export FAKE_DART_ACTION=mutate
echo -n "Test 25: stale mock fails and names it ... "
out="$("$GATE_SCRIPT" bindings-guard 2>&1)" && fail "Test 25 should have been rejected" || true
printf '%s\n' "$out" | grep -q 'test/example.mocks.dart differs from generator output' \
  || fail "Test 25 must name the stale mock"
echo "OK (rejected as expected)"

build_bindings_repo
export FAKE_FRB_ACTION=newfile
echo -n "Test 26: new untracked generated file fails ... "
out="$("$GATE_SCRIPT" bindings-guard 2>&1)" && fail "Test 26 should have been rejected" || true
printf '%s\n' "$out" | grep -q 'lib/src/rust/extra_generated.dart is generated but not checked in' \
  || fail "Test 26 must name the new generated file"
echo "OK (rejected as expected)"

build_bindings_repo
# Drop the fake and hide the real cargo install so "missing" is unambiguous.
rm -f "$FAKE_BIN/flutter_rust_bridge_codegen"
export PATH="$FAKE_BIN:/usr/bin:/bin"
echo -n "Test 27: generator missing gives a tooling error ... "
out="$("$GATE_SCRIPT" bindings-guard 2>&1)" && fail "Test 27 should have been rejected" || true
printf '%s\n' "$out" | grep -q 'not installed' \
  || fail "Test 27 must report the generator as missing"
echo "OK (rejected as expected)"
# Restore PATH for later cases (reinstall puts FAKE_BIN first again).

build_bindings_repo
export FAKE_FRB_VERSION=9.9.9
echo -n "Test 28: wrong version gives a tooling error ... "
out="$("$GATE_SCRIPT" bindings-guard 2>&1)" && fail "Test 28 should have been rejected" || true
printf '%s\n' "$out" | grep -q "need 2.11.1" \
  || fail "Test 28 must name the expected version"
echo "OK (rejected as expected)"

build_bindings_repo
cat > "$TEMP_DIR/rust/Cargo.toml" << 'EOF'
[dependencies]
flutter_rust_bridge = "=9.9.9"
EOF
echo -n "Test 29: pubspec/Cargo version mismatch gives a tooling error ... "
out="$("$GATE_SCRIPT" bindings-guard 2>&1)" && fail "Test 29 should have been rejected" || true
printf '%s\n' "$out" | grep -q 'version mismatch' \
  || fail "Test 29 must report a version mismatch"
echo "OK (rejected as expected)"

build_bindings_repo
printf 'dirty\n' >> "$TEMP_DIR/lib/src/rust/api.dart"
rm -f "$FAKE_FRB_CALLED" "$FAKE_DART_CALLED"
echo -n "Test 30: dirty generated file fails without regenerating ... "
out="$("$GATE_SCRIPT" bindings-guard 2>&1)" && fail "Test 30 should have been rejected" || true
printf '%s\n' "$out" | grep -q 'lib/src/rust/api.dart has uncommitted changes' \
  || fail "Test 30 must name the dirty file"
[ ! -f "$FAKE_FRB_CALLED" ] || fail "Test 30 must not call the generator"
echo "OK (rejected as expected)"

build_bindings_repo
export FAKE_FRB_EXIT=1
echo -n "Test 31: generator exit 1 gives a tooling error ... "
out="$("$GATE_SCRIPT" bindings-guard 2>&1)" && fail "Test 31 should have been rejected" || true
printf '%s\n' "$out" | grep -q 'flutter_rust_bridge_codegen generate failed' \
  || fail "Test 31 must report the generator failure"
echo "OK (rejected as expected)"

# OpenSpec change: material-ui-migration-tracking (capability: static-analysis-gates).
echo "Running tests for the legacy-material import guard..."

run_legacy_material_guard() {
    "$GATE_SCRIPT" legacy-material-guard >/dev/null 2>&1
}
RUNNER=run_legacy_material_guard

build_repo
mkdir -p "$TEMP_DIR/lib/src/ui"
cat > "$TEMP_DIR/lib/src/ui/material_ui_only.dart" << 'EOF'
import 'package:material_ui/material_ui.dart';
EOF
expect_pass "Test 32: material_ui-only tree passes"

build_repo
mkdir -p "$TEMP_DIR/lib/src/ui"
cat > "$TEMP_DIR/lib/src/ui/legacy_prefixed.dart" << 'EOF'
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy;
EOF
echo -n "Test 33: prefixed import with an ignore comment fails and names both ... "
out="$("$GATE_SCRIPT" legacy-material-guard 2>&1)" && fail "Test 33 should have been rejected" || true
printf '%s\n' "$out" | grep -q 'lib/src/ui/legacy_prefixed.dart → package:flutter/material.dart' \
  || fail "Test 33 must name the file and the library"
echo "OK (rejected as expected)"

build_repo
mkdir -p "$TEMP_DIR/lib/src/ui"
cat > "$TEMP_DIR/lib/src/ui/reexport_cupertino.dart" << 'EOF'
export 'package:flutter/cupertino.dart';
EOF
expect_reject "Test 34: cupertino export fails"

build_repo
mkdir -p "$TEMP_DIR/test/src"
cat > "$TEMP_DIR/test/src/legacy_in_test.dart" << 'EOF'
import 'package:flutter/material.dart';
EOF
expect_reject "Test 35: import under test/ fails"

build_repo
mkdir -p "$TEMP_DIR/lib/l10n"
cat > "$TEMP_DIR/lib/l10n/x.dart" << 'EOF'
import 'package:flutter/material.dart';
EOF
expect_pass "Test 36: legacy import in lib/l10n/x.dart passes"

build_repo
mkdir -p "$TEMP_DIR/test"
cat > "$TEMP_DIR/test/foo.mocks.dart" << 'EOF'
import 'package:flutter/material.dart';
EOF
expect_pass "Test 37: legacy import in test/foo.mocks.dart passes"

build_repo
mkdir -p "$TEMP_DIR/lib/src/ui"
cat > "$TEMP_DIR/lib/src/ui/unreadable.dart" << 'EOF'
import 'package:flutter/material.dart';
EOF
chmod a-r "$TEMP_DIR/lib/src/ui/unreadable.dart"
echo -n "Test 38: a listed but unreadable file is a tooling error ... "
if "$GATE_SCRIPT" legacy-material-guard >/dev/null 2>&1; then
    chmod a+r "$TEMP_DIR/lib/src/ui/unreadable.dart" 2>/dev/null || true
    fail "an unreadable file must not report success"
else
    chmod a+r "$TEMP_DIR/lib/src/ui/unreadable.dart" 2>/dev/null || true
    echo "OK (rejected as expected)"
fi

echo "All quality gate tests passed."