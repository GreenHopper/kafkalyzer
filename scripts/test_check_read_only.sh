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
    local rel_path="${3:-rust/src/test_violation.rs}"
    local target_file="$TEMP_DIR/$rel_path"

    echo -n "$test_name ... "
    mkdir -p "$(dirname "$target_file")"
    printf '%s\n' "$bad_code" > "$target_file"

    if "$CHECK_SCRIPT" "$TEMP_DIR" > /dev/null 2>&1; then
        echo "FAILED: Expected violation to be rejected!"
        rm -f "$target_file"
        exit 1
    else
        echo "OK (Rejected as expected)"
    fi
    rm -f "$target_file"
}

# Helper function to test acceptance on compliant code
test_accepted() {
    local test_name="$1"
    local good_code="$2"
    local rel_path="${3:-rust/src/test_accepted.rs}"
    local target_file="$TEMP_DIR/$rel_path"

    echo -n "$test_name ... "
    mkdir -p "$(dirname "$target_file")"
    printf '%s\n' "$good_code" > "$target_file"

    if "$CHECK_SCRIPT" "$TEMP_DIR" > /dev/null 2>&1; then
        echo "OK (Accepted as expected)"
    else
        echo "FAILED: Expected compliant code to be accepted!"
        rm -f "$target_file"
        exit 1
    fi
    rm -f "$target_file"
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

# Mutating admin calls & offset store
test_violation "Test 11: 'create_topics()' admin call" "admin.create_topics(&t, &o);"
test_violation "Test 12: 'incremental_alter_configs()' admin call" "admin.incremental_alter_configs(&c);"
test_violation "Test 13: 'delete_groups ()' admin call with space" "admin.delete_groups (&g, &o);"
test_violation "Test 14: 'store_offsets()' call" "c.store_offsets(&tpl);"
test_violation "Test 15: 'store_offset_from_message()' call" "c.store_offset_from_message(&m);"
test_violation "Test 16: 'delete_topics()' ignores exception marker" "admin.delete_topics(&t, &o); // allow_read_only_exception: x"
test_accepted "Test 17: 'describe_configs()' admin call" "admin.describe_configs(&r, &o);"
test_accepted "Test 18: 'committed_offsets()' consumer call" "consumer.committed_offsets(tpl, t);"
test_accepted "Test 19: 'my_delete_topics_view()' word boundary" "fn my_delete_topics_view() {}"

# HTTP write methods (Rust only)
test_violation "Test 20: HTTP '.put()'" "client.put(url);"
test_violation "Test 21: HTTP '.delete()'" "client.delete(url);"
test_violation "Test 22: HTTP '.patch ()' with space" "client.patch (url);"
test_violation "Test 23: HTTP 'Method::DELETE'" "client.request(Method::DELETE, url);"
test_violation "Test 24: Unmarked HTTP '.post()'" "client.post(url);"
test_violation "Test 25: HTTP '.post()' with marker but no reason" "client.post(url) // allow_read_only_exception"
test_accepted "Test 26: Reasoned HTTP '.post()' exception" "client.post(url) // allow_read_only_exception: compatibility check"
test_accepted "Test 27: HTTP '.get()'" "client.get(url);"
test_accepted "Test 28: Dart '.delete()' is ignored by Rust-only HTTP check" "await _storage.delete(key: key);" "lib/src/s.dart"

# Native mutating calls (librdkafka C API)
test_violation "Test 29: 'rd_kafka_commit' native call" "rd_kafka_commit(rk, ptr::null(), 0);"
test_violation "Test 30: 'rd_kafka_AlterConsumerGroupOffsets' native call" "rd_kafka_AlterConsumerGroupOffsets(rk, o, 1, opts, q);"
test_violation "Test 31: 'rd_kafka_offsets_store' native call" "rd_kafka_offsets_store(rk, tpl);"
test_accepted "Test 32: 'rd_kafka_ListConsumerGroupOffsets' native call" "rd_kafka_ListConsumerGroupOffsets(rk, r, 1, opts, q);"
test_accepted "Test 33: 'rd_kafka_DescribeConsumerGroups' native call" "rd_kafka_DescribeConsumerGroups(rk, g, 1, opts, q);"

# Accepted cases for existing rows
test_accepted "Test 34: 'enable.auto.commit = false' is accepted" 'config.set("enable.auto.commit", "false");'
test_accepted "Test 35: 'consumer.assign()' is accepted" "consumer.assign(&tpl)?;"

# Crate dependency allowlist
test_violation "Test 36: rdkafka in kafkalyzer-core/Cargo.toml" $'[dependencies]\nrdkafka = "0.36"' "rust/kafkalyzer-core/Cargo.toml"
test_violation "Test 37: [dependencies.reqwest] in kafkalyzer-core/Cargo.toml" '[dependencies.reqwest]' "rust/kafkalyzer-core/Cargo.toml"
test_violation "Test 38: renamed rdkafka package in kafkalyzer-core/Cargo.toml" 'kafka = { package = "rdkafka", version = "0.36" }' "rust/kafkalyzer-core/Cargo.toml"
test_violation "Test 39: flutter_rust_bridge in kafkalyzer-core/Cargo.toml" $'[dependencies]\nflutter_rust_bridge = "=2.11.1"' "rust/kafkalyzer-core/Cargo.toml"
test_accepted "Test 40: rdkafka/reqwest in target-specific deps of kafkalyzer-kafka/Cargo.toml" $'[target.\x27cfg(target_os = "linux")\x27.dependencies]\nrdkafka = "0.36"\nreqwest = "0.12"' "rust/kafkalyzer-kafka/Cargo.toml"
test_accepted "Test 41: flutter_rust_bridge in rust/Cargo.toml" $'[dependencies]\nflutter_rust_bridge = "=2.11.1"' "rust/Cargo.toml"

echo "All 41 check_read_only test cases passed successfully!"
