#!/usr/bin/env bash
#
# Automated regression test for scripts/check_read_only.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="$SCRIPT_DIR/check_read_only.sh"
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Running tests for check_read_only.sh..."

# Test 1: Clean codebase passes
echo -n "Test 1: Full repository check passes ... "
if "$CHECK_SCRIPT" > /dev/null 2>&1; then
    echo "OK"
else
    echo "FAILED: Clean codebase should have passed!"
    exit 1
fi

# Test 2: Clean temp source passes
mkdir -p "$TEMP_DIR/rust/src" "$TEMP_DIR/lib/src"
cat << 'EOF' > "$TEMP_DIR/rust/src/clean.rs"
pub fn read_metadata() {
    println!("read only");
}
EOF
echo -n "Test 2: Clean temp directory passes ... "
if "$CHECK_SCRIPT" "$TEMP_DIR" > /dev/null 2>&1; then
    echo "OK"
else
    echo "FAILED: Clean temp source should have passed!"
    exit 1
fi

# Helper function to test failure on simulated violation
test_violation() {
    local test_name="$1"
    local bad_code="$2"

    echo -n "$test_name ... "
    cat << EOF > "$TEMP_DIR/rust/src/test_violation.rs"
$bad_code
EOF

    if "$CHECK_SCRIPT" "$TEMP_DIR" > /dev/null 2>&1; then
        echo "FAILED: Expected violation to be rejected!"
        exit 1
    else
        echo "OK (Rejected as expected)"
    fi
    rm -f "$TEMP_DIR/rust/src/test_violation.rs"
}

# Test 3: Producer violation
test_violation "Test 3: 'Producer' keyword" "use rdkafka::producer::Producer;"

# Test 4: FutureProducer violation
test_violation "Test 4: 'FutureProducer' type" "let p: FutureProducer = create();"

# Test 5: FutureRecord violation
test_violation "Test 5: 'FutureRecord' usage" "let rec = FutureRecord::to(\"topic\");"

# Test 6: commit() violation
test_violation "Test 6: 'commit()' method" "consumer.commit(&topic_partition, CommitMode::Sync);"

# Test 7: subscribe() violation
test_violation "Test 7: 'subscribe()' method" "consumer.subscribe(&[\"topic\"]);"

# Test 8: enable.auto.commit = true violation
test_violation "Test 8: 'enable.auto.commit = true'" 'config.set("enable.auto.commit", "true");'

# Test 9: unwhitelisted .send() violation
test_violation "Test 9: Unwhitelisted .send()" "producer.send(record);"

# Test 10: whitelisted .send() passes
echo -n "Test 10: Whitelisted .send() with allow_read_only_exception passes ... "
cat << 'EOF' > "$TEMP_DIR/rust/src/whitelisted.rs"
fn notify() {
    channel.send(msg); // allow_read_only_exception: internal channel
}
EOF
if "$CHECK_SCRIPT" "$TEMP_DIR" > /dev/null 2>&1; then
    echo "OK"
else
    echo "FAILED: Whitelisted send should have passed!"
    exit 1
fi
rm -f "$TEMP_DIR/rust/src/whitelisted.rs"

echo "All 10 check_read_only test cases passed successfully!"
