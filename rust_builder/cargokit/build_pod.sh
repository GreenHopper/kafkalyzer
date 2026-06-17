#!/bin/sh
set -e

BASEDIR=$(dirname "$0")

# Ensure Rust environment is loaded (needed for Xcode build phases)
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
if [ -f "$CARGO_HOME/env" ]; then
  . "$CARGO_HOME/env"
fi
export PATH="$CARGO_HOME/bin:$PATH"

# 1c. Resolve SSL certificate issues (corporate proxy)
if [ -f "/tmp/custom_ca.pem" ]; then
  export CARGO_HTTP_CAINFO="/tmp/custom_ca.pem"
  export CURL_CA_BUNDLE="/tmp/custom_ca.pem"
  export GIT_SSL_CAINFO="/tmp/custom_ca.pem"
  export SSL_CERT_FILE="/tmp/custom_ca.pem"
  export RUSTUP_USE_CURL=1
fi

# Global Cross-compilation hints
export krb5_cv_attr_constructor_destructor=yes
export ac_cv_func_regcomp=yes
export ac_cv_printf_positional=yes
export ac_cv_func_getpwent=yes
export ac_cv_func_getpwnam_r=yes
export ac_cv_func_getpwuid_r=yes
export ac_cv_func_strerror_r=yes
export ac_cv_func_getaddrinfo=yes
export ac_cv_func_getnameinfo=yes
export ac_cv_gssapi_supports_spnego=yes
export sasl_cv_gssapi_spnego=yes

# 1d. CMake Wrapper
export PATH="/tmp/cmake_wrapper:$PATH"

# 1e. Smart Cargo Wrapper V5
# Detects target and sets isolated environment for C dependencies.
mkdir -p /tmp/cargo_wrapper
cat << 'EOF' > /tmp/cargo_wrapper/cargo
#!/bin/bash
REAL_CARGO=""
IFS=':' read -ra PATH_DIRS <<< "$PATH"
for dir in "${PATH_DIRS[@]}"; do
    if [ "$dir" != "/tmp/cargo_wrapper" ] && [ -x "$dir/cargo" ]; then
        REAL_CARGO="$dir/cargo"
        break
    fi
done
if [ -z "$REAL_CARGO" ]; then
    REAL_CARGO="cargo"
fi

DEBUG_LOG="/tmp/cargo_wrapper_debug.log"

TARGET=""
if [[ "$*" == *"aarch64-apple-darwin"* ]]; then TARGET="arm64"; fi
if [[ "$*" == *"x86_64-apple-darwin"* ]]; then TARGET="x64"; fi

echo "--- Cargo Wrapper Call ---" >> $DEBUG_LOG
echo "Args: $@" >> $DEBUG_LOG
echo "Detected Target: $TARGET" >> $DEBUG_LOG

if [ "$TARGET" == "arm64" ]; then
    echo "Applying ARM64 environment" >> $DEBUG_LOG
    export CC="clang -arch arm64"
    export CXX="clang++ -arch arm64"
    export AR="ar"
    export CFLAGS="-arch arm64"
    export LDFLAGS="-arch arm64"
    export CC_aarch64_apple_darwin="clang -arch arm64"
    export CXX_aarch64_apple_darwin="clang++ -arch arm64"
    export AR_aarch64_apple_darwin="ar"
    export CFLAGS_aarch64_apple_darwin="-arch arm64"
    export LDFLAGS_aarch64_apple_darwin="-arch arm64"
elif [ "$TARGET" == "x64" ]; then
    echo "Applying X86_64 environment" >> $DEBUG_LOG
    export CC="clang -arch x86_64"
    export CXX="clang++ -arch x86_64"
    export AR="ar"
    export CFLAGS="-arch x86_64"
    export LDFLAGS="-arch x86_64"
    export CC_x86_64_apple_darwin="clang -arch x86_64"
    export CXX_x86_64_apple_darwin="clang++ -arch x86_64"
    export AR_x86_64_apple_darwin="ar"
    export CFLAGS_x86_64_apple_darwin="-arch x86_64"
    export LDFLAGS_x86_64_apple_darwin="-arch x86_64"
fi

exec "$REAL_CARGO" "$@"
EOF
chmod +x /tmp/cargo_wrapper/cargo

cat << 'EOF' > /tmp/cargo_wrapper/rustup
#!/bin/bash
REAL_RUSTUP=""
IFS=':' read -ra PATH_DIRS <<< "$PATH"
for dir in "${PATH_DIRS[@]}"; do
    if [ "$dir" != "/tmp/cargo_wrapper" ] && [ -x "$dir/rustup" ]; then
        REAL_RUSTUP="$dir/rustup"
        break
    fi
done
if [ -z "$REAL_RUSTUP" ]; then
    REAL_RUSTUP="rustup"
fi

DEBUG_LOG="/tmp/cargo_wrapper_debug.log"

TARGET=""
if [[ "$*" == *"aarch64-apple-darwin"* ]]; then TARGET="arm64"; fi
if [[ "$*" == *"x86_64-apple-darwin"* ]]; then TARGET="x64"; fi

echo "--- Rustup Wrapper Call ---" >> $DEBUG_LOG
echo "Args: $@" >> $DEBUG_LOG
echo "Detected Target: $TARGET" >> $DEBUG_LOG

if [ "$TARGET" == "arm64" ]; then
    echo "Applying ARM64 environment to Rustup" >> $DEBUG_LOG
    export CC="clang -arch arm64"
    export CXX="clang++ -arch arm64"
    export AR="ar"
    export CFLAGS="-arch arm64"
    export LDFLAGS="-arch arm64"
    export CC_aarch64_apple_darwin="clang -arch arm64"
    export CXX_aarch64_apple_darwin="clang++ -arch arm64"
    export AR_aarch64_apple_darwin="ar"
    export CFLAGS_aarch64_apple_darwin="-arch arm64"
    export LDFLAGS_aarch64_apple_darwin="-arch arm64"
elif [ "$TARGET" == "x64" ]; then
    echo "Applying X86_64 environment to Rustup" >> $DEBUG_LOG
    export CC="clang -arch x86_64"
    export CXX="clang++ -arch x86_64"
    export AR="ar"
    export CFLAGS="-arch x86_64"
    export LDFLAGS="-arch x86_64"
    export CC_x86_64_apple_darwin="clang -arch x86_64"
    export CXX_x86_64_apple_darwin="clang++ -arch x86_64"
    export AR_x86_64_apple_darwin="ar"
    export CFLAGS_x86_64_apple_darwin="-arch x86_64"
    export LDFLAGS_x86_64_apple_darwin="-arch x86_64"
fi

exec "$REAL_RUSTUP" "$@"
EOF
chmod +x /tmp/cargo_wrapper/rustup

export PATH="/tmp/cargo_wrapper:$PATH"

echo "--- Build Environment Snapshot ---" >&2
env | grep -E "CARGO|RUST|CC|CFLAGS|LDFLAGS|SDK|ARCHS" >&2 || true

# Workaround for https://github.com/dart-lang/pub/issues/4010
BASEDIR=$(cd "$BASEDIR" ; pwd -P)

# Remove XCode SDK from path. Otherwise this breaks tool compilation when building iOS project
NEW_PATH=`echo $PATH | tr ":" "\n" | grep -v "Contents/Developer/" | tr "\n" ":"`

export PATH=${NEW_PATH%?} # remove trailing :

env

# Platform name (macosx, iphoneos, iphonesimulator)
export CARGOKIT_DARWIN_PLATFORM_NAME=$PLATFORM_NAME

# Arctive architectures (arm64, armv7, x86_64), space separated.
export CARGOKIT_DARWIN_ARCHS=$ARCHS

# Current build configuration (Debug, Release)
export CARGOKIT_CONFIGURATION=$CONFIGURATION

# Path to directory containing Cargo.toml.
export CARGOKIT_MANIFEST_DIR=$PODS_TARGET_SRCROOT/$1

# Temporary directory for build artifacts.
export CARGOKIT_TARGET_TEMP_DIR=$TARGET_TEMP_DIR

# Output directory for final artifacts.
export CARGOKIT_OUTPUT_DIR=$PODS_CONFIGURATION_BUILD_DIR/$PRODUCT_NAME

# Directory to store built tool artifacts.
export CARGOKIT_TOOL_TEMP_DIR=$TARGET_TEMP_DIR/build_tool

# Directory inside root project. Not necessarily the top level directory of root project.
export CARGOKIT_ROOT_PROJECT_DIR=$SRCROOT

FLUTTER_EXPORT_BUILD_ENVIRONMENT=(
  "$PODS_ROOT/../Flutter/ephemeral/flutter_export_environment.sh" # macOS
  "$PODS_ROOT/../Flutter/flutter_export_environment.sh" # iOS
)

for path in "${FLUTTER_EXPORT_BUILD_ENVIRONMENT[@]}"
do
  if [[ -f "$path" ]]; then
    source "$path"
  fi
done

sh "$BASEDIR/run_build_tool.sh" build-pod "$@"

# Make a symlink from built framework to phony file, which will be used as input to
# build script. This should force rebuild (podspec currently doesn't support alwaysOutOfDate
# attribute on custom build phase)
ln -fs "$OBJROOT/XCBuildData/build.db" "${BUILT_PRODUCTS_DIR}/cargokit_phony"
ln -fs "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}" "${BUILT_PRODUCTS_DIR}/cargokit_phony_out"
