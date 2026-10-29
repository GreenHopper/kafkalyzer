#!/usr/bin/env bash
#
# kafkalyzer Linux Test and Build Script
#
# Runs all verification gates, unit tests (Rust and Flutter), and compiles
# a full release build for Linux desktop.
#
# Usage:
#   ./scripts/build_linux.sh [options] [-- <extra flutter build flags>]
#
# Options:
#   --tests-only      Run only unit tests and gates without building the binary
#   --skip-tests      Skip unit tests and proceed directly to the build step
#   --skip-read-only  Skip the read-only invariant check
#   --no-pack         Skip Velopack packaging even if vpk is installed
#   -h, --help        Show this help message

set -euo pipefail

# Determine repository root
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Formatting helpers
if [ -t 1 ]; then
  BOLD="\033[1m"
  GREEN="\033[0;32m"
  YELLOW="\033[0;33m"
  RED="\033[0;31m"
  BLUE="\033[0;34m"
  RESET="\033[0m"
else
  BOLD=""
  GREEN=""
  YELLOW=""
  RED=""
  BLUE=""
  RESET=""
fi

info() {
  echo -e "${BLUE}${BOLD}[INFO]${RESET} $*"
}

success() {
  echo -e "${GREEN}${BOLD}[SUCCESS]${RESET} $*"
}

warn() {
  echo -e "${YELLOW}${BOLD}[WARNING]${RESET} $*"
}

error() {
  echo -e "${RED}${BOLD}[ERROR]${RESET} $*" >&2
}

header() {
  echo ""
  echo -e "${BOLD}==========================================================${RESET}"
  echo -e "${BOLD}  $*${RESET}"
  echo -e "${BOLD}==========================================================${RESET}"
}

# CLI flag parsing
RUN_TESTS=true
RUN_BUILD=true
RUN_READ_ONLY=true
RUN_PACK=true
RUN_CLEAN=false
EXTRA_BUILD_FLAGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean)
      RUN_CLEAN=true
      shift
      ;;
    --tests-only)
      RUN_BUILD=false
      shift
      ;;
    --skip-tests)
      RUN_TESTS=false
      shift
      ;;
    --skip-read-only)
      RUN_READ_ONLY=false
      shift
      ;;
    --no-pack)
      RUN_PACK=false
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options] [-- <extra flutter build flags>]"
      echo ""
      echo "Options:"
      echo "  --clean           Run flutter clean before building"
      echo "  --tests-only      Run only unit tests and exit"
      echo "  --skip-tests      Skip unit tests and run build only"
      echo "  --skip-read-only  Skip the read-only invariant check"
      echo "  --no-pack         Skip Velopack packaging even if vpk is installed"
      echo "  -h, --help        Show this help message"
      exit 0
      ;;
    --)
      shift
      EXTRA_BUILD_FLAGS=("$@")
      break
      ;;
    *)
      warn "Unknown option: $1 (passing through to flutter build)"
      EXTRA_BUILD_FLAGS+=("$1")
      shift
      ;;
  esac
done

header "kafkalyzer Linux Test & Build Pipeline"

# 1. Environment & Dependency Checks
info "Checking build tools and system dependencies..."

MISSING_TOOLS=()
for tool in flutter cargo pkg-config; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    MISSING_TOOLS+=("$tool")
  fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  error "Missing required build tools in PATH: ${MISSING_TOOLS[*]}"
  exit 1
fi

# Check required Linux development packages for CMake/GTK/Secret storage
if [ "$RUN_BUILD" = true ]; then
  MISSING_PKGS=()
  for pkg in gtk+-3.0 libsecret-1; do
    if ! pkg-config --exists "$pkg" 2>/dev/null; then
      MISSING_PKGS+=("$pkg")
    fi
  done

  if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    error "Missing required Linux pkg-config libraries: ${MISSING_PKGS[*]}"
    echo ""
    echo "Please install required development packages with:"
    echo "  sudo apt-get update && sudo apt-get install -y libgtk-3-dev libsecret-1-dev libblkid-dev liblzma-dev pkg-config libssl-dev libsasl2-dev libz-dev"
    echo ""
    exit 1
  fi
fi

success "All required build tools and libraries are present."

# 2. Read-Only Invariants Verification
if [ "$RUN_READ_ONLY" = true ]; then
  header "Step 1: Read-Only Invariant Gate"
  if [ -x "$REPO_ROOT/scripts/check_read_only.sh" ]; then
    "$REPO_ROOT/scripts/check_read_only.sh" "$REPO_ROOT"
  else
    error "Read-only verification script not found at scripts/check_read_only.sh"
    exit 1
  fi
  success "Read-only invariants verified."
fi

# 3. Unit Tests
if [ "$RUN_TESTS" = true ]; then
  header "Step 2: Rust Workspace Tests"
  info "Running cargo test in rust/..."
  cargo test --manifest-path "$REPO_ROOT/rust/Cargo.toml"
  success "Rust tests passed."

  header "Step 3: Flutter Dependencies & Unit Tests"
  info "Fetching Flutter dependencies..."
  flutter pub get

  info "Running flutter test..."
  flutter test
  success "Flutter unit and widget tests passed."
fi

if [ "$RUN_BUILD" = false ]; then
  header "Finished"
  success "Tests completed successfully. Build skipped (--tests-only)."
  exit 0
fi

# 4. Linux Release Build
header "Step 4: Linux Desktop Application Build"

if [ "$RUN_CLEAN" = true ]; then
  info "Running flutter clean..."
  flutter clean
  flutter pub get
fi

# Extract version and build number
if [ -z "${VERSION:-}" ]; then
  if TAG=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null); then
    VERSION="${TAG#v}"
  else
    VERSION=$(grep -E '^version:' "$REPO_ROOT/pubspec.yaml" | head -n1 | cut -d ' ' -f 2 | cut -d '+' -f 1)
    VERSION="${VERSION:-1.0.0}"
  fi
fi

if [ -z "${BUILD_NUMBER:-}" ]; then
  BUILD_NUMBER=$(grep -E '^version:' "$REPO_ROOT/pubspec.yaml" | head -n1 | cut -d '+' -f 2)
  if [ -z "$BUILD_NUMBER" ] || [ "$BUILD_NUMBER" = "$VERSION" ]; then
    BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "1")
  fi
fi

info "Building version: ${VERSION}+${BUILD_NUMBER}"

BUILD_CMD=(
  flutter build linux --release
  "--build-name=${VERSION}"
  "--build-number=${BUILD_NUMBER}"
  "--dart-define=APP_VERSION=${VERSION}+${BUILD_NUMBER}"
)

if [ ${#EXTRA_BUILD_FLAGS[@]} -gt 0 ]; then
  BUILD_CMD+=("${EXTRA_BUILD_FLAGS[@]}")
fi

info "Executing: ${BUILD_CMD[*]}"
"${BUILD_CMD[@]}"

BUNDLE_DIR="$REPO_ROOT/build/linux/x64/release/bundle"
EXECUTABLE="$BUNDLE_DIR/kafkalyzer"

if [ ! -f "$EXECUTABLE" ]; then
  error "Build finished but executable was not found at $EXECUTABLE"
  exit 1
fi

success "Linux release binary successfully built at: $EXECUTABLE"

# 5. Optional Velopack Packaging
if [ "$RUN_PACK" = true ] && command -v vpk >/dev/null 2>&1; then
  header "Step 5: Velopack Package Generation"
  info "vpk detected. Packaging release..."

  if [ -f "$REPO_ROOT/changelog.md" ]; then
    cp "$REPO_ROOT/changelog.md" "$BUNDLE_DIR/"
  fi

  APPDIR="$REPO_ROOT/build/linux/x64/release/Kafkalyzer.AppDir"
  rm -rf "$APPDIR"
  mkdir -p "$APPDIR/usr/bin"
  mkdir -p "$APPDIR/usr/share/icons/hicolor/scalable/apps"

  cp -a "$BUNDLE_DIR/." "$APPDIR/usr/bin/"
  if [ -f "$REPO_ROOT/assets/logo.png" ]; then
    cp "$REPO_ROOT/assets/logo.png" "$APPDIR/Kafkalyzer.png"
    cp "$REPO_ROOT/assets/logo.png" "$APPDIR/.DirIcon"
    cp "$REPO_ROOT/assets/logo.png" "$APPDIR/usr/share/icons/hicolor/scalable/apps/Kafkalyzer.png"
  fi

  cat > "$APPDIR/Kafkalyzer.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Kafkalyzer
Comment=Kafkalyzer
Icon=Kafkalyzer
Exec=kafkalyzer
StartupWMClass=Kafkalyzer
Categories=Utility;
EOF

  cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/sh
if [ ! -z "$APPIMAGE" ] && [ ! -z "$APPDIR" ]; then
    MD5=$(echo -n "file://$APPIMAGE" | md5sum | cut -d' ' -f1)
    cp "$APPDIR/Kafkalyzer.png" "$HOME/.cache/thumbnails/normal/$MD5.png" >/dev/null 2>&1
    cp "$APPDIR/Kafkalyzer.png" "$HOME/.cache/thumbnails/large/$MD5.png" >/dev/null 2>&1
    xdg-icon-resource forceupdate >/dev/null 2>&1
    if [ -d "$HOME/.local/share/applications" ]; then
        for f in "$HOME/.local/share/applications/"*Kafkalyzer*.desktop; do
            [ -f "$f" ] || continue
            sed -i -e 's/^Name=Kafkalyzer (.*/Name=Kafkalyzer/' -e 's/^Comment=Kafkalyzer .*/Comment=Kafkalyzer/' -e '/^X-AppImage-Version=/d' "$f" 2>/dev/null || true
        done
    fi
fi
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="${HERE}"/usr/bin/:"${PATH}"
EXEC=$(grep -e '^Exec=.*' "${HERE}"/*.desktop | head -n 1 | cut -d "=" -f 2 | cut -d " " -f 1 | sed 's/\\s/ /g')
exec "${EXEC}" "$@"
EOF
  chmod +x "$APPDIR/AppRun"

  vpk pack -u Kafkalyzer --packTitle "Kafkalyzer" -v "$VERSION" -p "$APPDIR" -e kafkalyzer --icon "$REPO_ROOT/assets/logo.png" -o "$REPO_ROOT/velopack_release"
  success "Velopack package generated at: $REPO_ROOT/velopack_release/"
fi

header "Summary"
success "Pipeline completed successfully!"
echo "  • Executable: $EXECUTABLE"
echo "  • Bundle directory: $BUNDLE_DIR"
if [ -d "$REPO_ROOT/velopack_release" ]; then
  echo "  • Velopack packages: $REPO_ROOT/velopack_release/"
fi
echo ""
