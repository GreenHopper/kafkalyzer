#!/usr/bin/env bash
#
# kafkalyzer Read-Only Invariant Verification Gate
#
# Scans Rust and Dart source trees to verify that no Kafka producer clients,
# message publishing calls, offset commit APIs, or consumer group subscriptions
# are introduced into the codebase.

set -euo pipefail

TARGET_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TARGET_ROOT="${TARGET_ROOT%/}"
EXIT_CODE=0

# Define paths to scan
SCAN_PATHS=()
SCAN_PATHS_RS=()
if [ -d "$TARGET_ROOT/rust" ]; then
    # Scan all rust source files excluding target directories
    while IFS= read -r -d '' file; do
        SCAN_PATHS+=("$file")
        SCAN_PATHS_RS+=("$file")
    done < <(find "$TARGET_ROOT/rust" -name target -prune -o -type f -name "*.rs" -print0)
fi

if [ -d "$TARGET_ROOT/lib/src" ]; then
    while IFS= read -r -d '' file; do
        SCAN_PATHS+=("$file")
    done < <(find "$TARGET_ROOT/lib/src" -type f -name "*.dart" -print0)
fi

# Fallback: if scanning a custom temp directory where files might be directly in TARGET_ROOT
if [ ${#SCAN_PATHS[@]} -eq 0 ] && [ "$TARGET_ROOT" != "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" ]; then
    while IFS= read -r -d '' file; do
        SCAN_PATHS+=("$file")
        if [[ "$file" == *.rs ]]; then
            SCAN_PATHS_RS+=("$file")
        fi
    done < <(find "$TARGET_ROOT" -type f \( -name "*.rs" -o -name "*.dart" \) -print0)
fi

if [ ${#SCAN_PATHS[@]} -eq 0 ]; then
    echo "Warning: No source files found to scan in $TARGET_ROOT"
    exit 0
fi

# Define checks:
# Format: "CHECK_NAME:::SCOPE:::REGEX_PATTERN:::EXCLUDE_REGEX_PATTERN"
# SCOPE: all (Rust + Dart) | rs (Rust only)
CHECKS=(
    "Prohibited Kafka Producer Types:::all:::Producer|ThreadedProducer|BaseProducer|FutureProducer|FutureRecord:::"
    "Prohibited Kafka Consumer Commits:::all:::\.commit\(|commit_message\(|commit_consumer_state\(:::"
    "Prohibited Consumer Group Subscription:::all:::\.subscribe\(:::"
    "Prohibited Auto-Commit Enablement:::all:::enable\.auto\.commit.*['\"]true['\"]:::"
    "Prohibited Message Send Calls:::all:::\.send\(:::allow_read_only_exception"
    "Mutating admin calls:::all:::(^|[^A-Za-z0-9_])(create_topics|delete_topics|create_partitions|alter_configs|incremental_alter_configs|delete_records|delete_groups)[[:space:]]*\(:::"
    "Offset store:::all:::(^|[^A-Za-z0-9_])store_offset(s|_from_message)?[[:space:]]*\(:::"
    "HTTP PUT/DELETE/PATCH:::rs:::\.(put|delete|patch)[[:space:]]*\(|Method::(PUT|DELETE|PATCH):::"
    "HTTP POST:::rs:::\.post[[:space:]]*\(|Method::POST:::allow_read_only_exception:[[:space:]]*[^[:space:]]"
    "Native mutating calls:::rs:::rd_kafka_(produce|producev|produceva|produce_batch|send_offsets_to_transaction|commit|commit_message|commit_queue|offset_store|offsets_store|subscribe|CreateTopics|DeleteTopics|CreatePartitions|AlterConfigs|IncrementalAlterConfigs|DeleteRecords|DeleteGroups|DeleteConsumerGroupOffsets|AlterConsumerGroupOffsets|CreateAcls|DeleteAcls|AlterUserScramCredentials)[^A-Za-z_]:::"
    'Producer-mode kcat command:::all:::(kcat|kafkacat)[^"'\''`]*[[:space:]]-P([^A-Za-z]|$):::'
)

echo "=========================================================="
echo "  kafkalyzer Read-Only Invariant Verification Check"
echo "=========================================================="
echo "Scanning ${#SCAN_PATHS[@]} source files across $TARGET_ROOT..."

TOTAL_VIOLATIONS=0

for check in "${CHECKS[@]}"; do
    name="${check%%:::*}"
    rest="${check#*:::}"
    scope="${rest%%:::*}"
    rest="${rest#*:::}"
    pattern="${rest%%:::*}"
    exclude="${rest#*:::}"

    target_files=()
    if [ "$scope" = "rs" ]; then
        if [ ${#SCAN_PATHS_RS[@]} -gt 0 ]; then
            target_files=("${SCAN_PATHS_RS[@]}")
        fi
    else
        if [ ${#SCAN_PATHS[@]} -gt 0 ]; then
            target_files=("${SCAN_PATHS[@]}")
        fi
    fi

    echo -n "Checking: $name ... "

    if [ ${#target_files[@]} -eq 0 ]; then
        echo "PASSED"
        continue
    fi

    # Run grep on target_files
    if [ -n "$exclude" ]; then
        MATCHES=$(grep -nE "$pattern" "${target_files[@]}" 2>/dev/null | grep -vE "$exclude" || true)
    else
        MATCHES=$(grep -nE "$pattern" "${target_files[@]}" 2>/dev/null || true)
    fi

    if [ -n "$MATCHES" ]; then
        echo "FAILED"
        echo "----------------------------------------------------------"
        echo "Violation detected for: $name"
        echo "$MATCHES"
        echo "----------------------------------------------------------"
        VIOLATIONS_COUNT=$(echo "$MATCHES" | wc -l)
        TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + VIOLATIONS_COUNT))
        EXIT_CODE=1
    else
        echo "PASSED"
    fi
done

# Crate dependency allowlist check
if [ -d "$TARGET_ROOT/rust" ]; then
    MANIFESTS=()
    while IFS= read -r -d '' manifest; do
        MANIFESTS+=("$manifest")
    done < <(find "$TARGET_ROOT/rust" -name target -prune -o -type f -name "Cargo.toml" -print0)

    echo -n "Checking: Crate dependency allowlist (${#MANIFESTS[@]} manifests) ... "
    DEP_VIOLATIONS=""
    for manifest in "${MANIFESTS[@]}"; do
        rel_path="${manifest#"$TARGET_ROOT"/}"
        if [ "$rel_path" != "rust/kafkalyzer-kafka/Cargo.toml" ]; then
            hits=$(grep -nE '^[[:space:]]*(rdkafka|rdkafka-sys|reqwest)[[:space:]]*=|dependencies\.(rdkafka|rdkafka-sys|reqwest)[[:space:]]*\]|package[[:space:]]*=[[:space:]]*"(rdkafka|rdkafka-sys|reqwest)"' "$manifest" 2>/dev/null || true)
            if [ -n "$hits" ]; then
                while IFS= read -r line; do
                    DEP_VIOLATIONS+="${manifest}:${line}"$'\n'
                done <<< "$hits"
            fi
        fi
        if [ "$rel_path" != "rust/Cargo.toml" ]; then
            hits=$(grep -nE '^[[:space:]]*(flutter_rust_bridge)[[:space:]]*=|dependencies\.(flutter_rust_bridge)[[:space:]]*\]|package[[:space:]]*=[[:space:]]*"(flutter_rust_bridge)"' "$manifest" 2>/dev/null || true)
            if [ -n "$hits" ]; then
                while IFS= read -r line; do
                    DEP_VIOLATIONS+="${manifest}:${line}"$'\n'
                done <<< "$hits"
            fi
        fi
    done

    DEP_VIOLATIONS="${DEP_VIOLATIONS%$'\n'}"
    if [ -n "$DEP_VIOLATIONS" ]; then
        echo "FAILED"
        echo "----------------------------------------------------------"
        echo "Violation detected for: Crate dependency allowlist"
        echo "$DEP_VIOLATIONS"
        echo "----------------------------------------------------------"
        VIOLATIONS_COUNT=$(echo "$DEP_VIOLATIONS" | wc -l)
        TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + VIOLATIONS_COUNT))
        EXIT_CODE=1
    else
        echo "PASSED"
    fi
fi

echo "=========================================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "SUCCESS: All read-only invariants satisfied. Zero violations found."
    exit 0
else
    echo "FAILURE: $TOTAL_VIOLATIONS read-only invariant violation(s) found!"
    echo "kafkalyzer is strictly read-only. Producer clients, message sends,"
    echo "and offset commits are forbidden by architectural invariant."
    exit 1
fi
