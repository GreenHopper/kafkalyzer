#!/usr/bin/env bash
#
# kafkalyzer Read-Only Invariant Verification Gate
#
# Scans Rust and Dart source trees to verify that no Kafka producer clients,
# message publishing calls, offset commit APIs, or consumer group subscriptions
# are introduced into the codebase.

set -euo pipefail

TARGET_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EXIT_CODE=0

# Define paths to scan
SCAN_PATHS=()
if [ -d "$TARGET_ROOT/rust" ]; then
    # Scan all rust source files excluding target directories
    while IFS= read -r -d '' file; do
        SCAN_PATHS+=("$file")
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
    done < <(find "$TARGET_ROOT" -type f \( -name "*.rs" -o -name "*.dart" \) -print0)
fi

if [ ${#SCAN_PATHS[@]} -eq 0 ]; then
    echo "Warning: No source files found to scan in $TARGET_ROOT"
    exit 0
fi

# Define checks:
# Format: "CHECK_NAME:::REGEX_PATTERN:::EXCLUDE_REGEX_PATTERN"
CHECKS=(
    "Prohibited Kafka Producer Types:::Producer|ThreadedProducer|BaseProducer|FutureProducer|FutureRecord:::"
    "Prohibited Kafka Consumer Commits:::\.commit\(|commit_message\(|commit_consumer_state\(:::"
    "Prohibited Consumer Group Subscription:::\.subscribe\(:::"
    "Prohibited Auto-Commit Enablement:::enable\.auto\.commit.*['\"]true['\"]:::"
    "Prohibited Message Send Calls:::\.send\(:::allow_read_only_exception"
)

echo "=========================================================="
echo "  kafkalyzer Read-Only Invariant Verification Check"
echo "=========================================================="
echo "Scanning ${#SCAN_PATHS[@]} source files across $TARGET_ROOT..."

TOTAL_VIOLATIONS=0

for check in "${CHECKS[@]}"; do
    name="${check%%:::*}"
    rest="${check#*:::}"
    pattern="${rest%%:::*}"
    exclude="${rest#*:::}"

    echo -n "Checking: $name ... "

    # Run grep on SCAN_PATHS
    if [ -n "$exclude" ]; then
        MATCHES=$(grep -nE "$pattern" "${SCAN_PATHS[@]}" 2>/dev/null | grep -vE "$exclude" || true)
    else
        MATCHES=$(grep -nE "$pattern" "${SCAN_PATHS[@]}" 2>/dev/null || true)
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
