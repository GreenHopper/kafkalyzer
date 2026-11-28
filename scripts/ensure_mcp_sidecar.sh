#!/usr/bin/env bash
#
# Build kafkalyzer-mcp and copy it next to any existing desktop app binary
# (Flutter places the GUI there; MCP clients launch the sibling sidecar).
#
# Usage:
#   ./scripts/ensure_mcp_sidecar.sh          # debug binary → debug bundles
#   ./scripts/ensure_mcp_sidecar.sh --release
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

PROFILE=debug
CARGO_FLAGS=()
SRC_NAME=kafkalyzer-mcp
DEST_NAME=kafkalyzer-mcp

for arg in "$@"; do
  case "$arg" in
    --release)
      PROFILE=release
      CARGO_FLAGS=(--release)
      ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (try --help)" >&2
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]]; then
  SRC_NAME=kafkalyzer-mcp.exe
  DEST_NAME=kafkalyzer-mcp.exe
fi

echo "Building kafkalyzer-mcp ($PROFILE)..."
cargo build --manifest-path rust/Cargo.toml -p kafkalyzer-mcp "${CARGO_FLAGS[@]}"

SRC="$REPO_ROOT/rust/target/$PROFILE/$SRC_NAME"
if [ ! -f "$SRC" ]; then
  echo "error: expected binary missing: $SRC" >&2
  exit 1
fi

DEST_DIRS=()
case "$PROFILE" in
  debug)
    DEST_DIRS+=(
      "$REPO_ROOT/build/linux/x64/debug/bundle"
      "$REPO_ROOT/build/windows/x64/runner/Debug"
    )
    ;;
  release)
    DEST_DIRS+=(
      "$REPO_ROOT/build/linux/x64/release/bundle"
      "$REPO_ROOT/build/windows/x64/runner/Release"
    )
    ;;
esac

# macOS app bundles: product name varies; place next to the main binary.
MAC_PRODUCTS="$REPO_ROOT/build/macos/Build/Products"
if [ -d "$MAC_PRODUCTS" ]; then
  case "$PROFILE" in
    debug) MAC_CFG=Debug ;;
    release) MAC_CFG=Release ;;
  esac
  if [ -d "$MAC_PRODUCTS/$MAC_CFG" ]; then
    while IFS= read -r -d '' macos_dir; do
      DEST_DIRS+=("$macos_dir")
    done < <(find "$MAC_PRODUCTS/$MAC_CFG" -maxdepth 2 -type d -path '*/Contents/MacOS' -print0 2>/dev/null)
  fi
fi

copied=0
for dir in "${DEST_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    cp -a "$SRC" "$dir/$DEST_NAME"
    chmod +x "$dir/$DEST_NAME" 2>/dev/null || true
    echo "placed: $dir/$DEST_NAME"
    copied=$((copied + 1))
  fi
done

if [ "$copied" -eq 0 ]; then
  echo "error: built $SRC but no Flutter bundle dir exists yet." >&2
  echo "Run a desktop build (e.g. flutter run -d linux) once, then re-run this script." >&2
  exit 1
fi

echo "done: $copied location(s)"
