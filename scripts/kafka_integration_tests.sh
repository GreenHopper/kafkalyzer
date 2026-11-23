#!/usr/bin/env bash
#
# Start the compose kafka broker, seed broker-test fixtures, run ignored
# kafkalyzer-kafka tests, and prove the tests left fixture data unchanged.
#
# Usage: bash scripts/kafka_integration_tests.sh
# Also sourcable for negative checks (snapshot helpers).

set -euo pipefail

KAFKA_IT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KAFKA_IT_CONTAINER="sift_kafka"
KAFKA_IT_BOOTSTRAP="sift_kafka:29092"
KAFKA_IT_RESET_CMD="docker compose rm -sf kafka && docker compose up -d kafka"

kafka_it_die() {
  echo "error: $*" >&2
  exit 1
}

kafka_it_shape_fail() {
  local fixture="$1"
  shift
  echo "error: fixture '$fixture' shape mismatch: $*" >&2
  echo "reset the broker with: $KAFKA_IT_RESET_CMD" >&2
  exit 1
}

kafka_it_exec() {
  docker exec "$KAFKA_IT_CONTAINER" "$@"
}

kafka_it_exec_i() {
  docker exec -i "$KAFKA_IT_CONTAINER" "$@"
}

kafka_it_kafka() {
  local tool="$1"
  shift
  kafka_it_exec "$tool" --bootstrap-server "$KAFKA_IT_BOOTSTRAP" "$@"
}

kafka_it_preflight() {
  if ! command -v docker >/dev/null 2>&1; then
    kafka_it_die "container runtime unavailable: docker not found"
  fi
  if ! docker compose version >/dev/null 2>&1; then
    kafka_it_die "container runtime unavailable: docker compose not found"
  fi
}

kafka_it_start_broker() {
  (
    cd "$KAFKA_IT_ROOT"
    docker compose up -d kafka
  ) || kafka_it_die "broker unavailable: failed to start compose service kafka"

  local i
  for i in $(seq 1 90); do
    if kafka_it_kafka kafka-topics --list >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  kafka_it_die "broker unavailable: kafka did not become ready within 90s"
}

kafka_it_topic_exists() {
  local topic="$1"
  local list
  list="$(kafka_it_kafka kafka-topics --list 2>/dev/null)" || return 1
  grep -Fxq "$topic" <<<"$list"
}

kafka_it_partition_count() {
  local topic="$1"
  local desc
  desc="$(kafka_it_kafka kafka-topics --describe --topic "$topic" 2>/dev/null)" || return 1
  # Avoid piping kafka CLI into awk/exit under pipefail (SIGPIPE → 141).
  awk -F'\t' '/PartitionCount:/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^PartitionCount:/) {
          split($i, a, ":"); gsub(/^ +| +$/, "", a[2]); print a[2]; exit
        }
      }
    }' <<<"$desc"
}

kafka_it_end_offsets() {
  # Prints "partition:offset" lines sorted by partition.
  local topic="$1"
  local raw
  raw="$(kafka_it_kafka kafka-get-offsets --topic "$topic" 2>/dev/null)" || return 1
  awk -F: -v t="$topic" '$1 == t { print $2 ":" $3 }' <<<"$raw" | sort -t: -n
}

kafka_it_ensure_topic() {
  local topic="$1"
  local partitions="$2"
  if kafka_it_topic_exists "$topic"; then
    return 0
  fi
  kafka_it_kafka kafka-topics --create --topic "$topic" \
    --partitions "$partitions" --replication-factor 1 >/dev/null
}

kafka_it_check_partition_count() {
  local topic="$1"
  local expected="$2"
  local actual
  actual="$(kafka_it_partition_count "$topic")"
  if [[ "$actual" != "$expected" ]]; then
    kafka_it_shape_fail "$topic" "expected $expected partitions, got '${actual:-unknown}'"
  fi
}

kafka_it_seed_spike_t_000() {
  kafka_it_ensure_topic "spike-t-000" 1
  kafka_it_check_partition_count "spike-t-000" 1
  # Empty topic: any record is a shape mismatch (task 3.3a / fixture reuse).
  local offsets
  offsets="$(kafka_it_end_offsets "spike-t-000" | tr '\n' ' ')"
  if [[ "$offsets" != "0:0 " ]]; then
    kafka_it_shape_fail "spike-t-000" "expected end offset 0:0, got '${offsets:-unknown}'"
  fi
}

kafka_it_seed_spike_offset_dist_60p() {
  kafka_it_ensure_topic "spike-offset-dist-60p" 60
  kafka_it_check_partition_count "spike-offset-dist-60p" 60
}

kafka_it_seed_spike_tx_12() {
  kafka_it_ensure_topic "spike-tx-12" 1
  local offsets
  offsets="$(kafka_it_end_offsets "spike-tx-12" | tr '\n' ' ')"
  if [[ "$offsets" != "0:12 " ]]; then
    if [[ "$offsets" == "0:0 " || -z "${offsets// }" ]]; then
      kafka_it_exec kafka-producer-perf-test \
        --topic spike-tx-12 \
        --num-records 11 \
        --record-size 32 \
        --throughput -1 \
        --producer-props "bootstrap.servers=$KAFKA_IT_BOOTSTRAP" \
        --transactional-id kafkalyzer-it-tx \
        --transaction-duration-ms 600000 >/dev/null
      offsets="$(kafka_it_end_offsets "spike-tx-12" | tr '\n' ' ')"
    fi
  fi
  if [[ "$offsets" != "0:12 " ]]; then
    kafka_it_shape_fail "spike-tx-12" "expected end offset 0:12, got '${offsets:-unknown}'"
  fi
}

kafka_it_seed_lag_spike() {
  kafka_it_ensure_topic "lag-spike" 3
  local offsets
  offsets="$(kafka_it_end_offsets "lag-spike" | tr '\n' ' ')"
  if [[ "$offsets" != "0:0 1:0 2:150 " ]]; then
    if [[ "$offsets" == "0:0 1:0 2:0 " || -z "${offsets// }" ]]; then
      local n
      for n in $(seq 1 150); do
        echo "k0:msg-$n"
      done | kafka_it_exec_i kafka-console-producer \
        --bootstrap-server "$KAFKA_IT_BOOTSTRAP" \
        --topic lag-spike \
        --property parse.key=true \
        --property key.separator=: >/dev/null
      offsets="$(kafka_it_end_offsets "lag-spike" | tr '\n' ' ')"
    fi
  fi
  if [[ "$offsets" != "0:0 1:0 2:150 " ]]; then
    kafka_it_shape_fail "lag-spike" "expected end offsets 0:0 1:0 2:150, got '${offsets:-unknown}'"
  fi
}

kafka_it_group_committed_map() {
  # Prints "partition=offset" for lag-spike-g / lag-spike, one per line, sorted.
  local raw
  raw="$(kafka_it_kafka kafka-consumer-groups --describe --group lag-spike-g --offsets 2>/dev/null)" || return 1
  awk '
      $1 == "lag-spike-g" && $2 == "lag-spike" {
        print $3 "=" $4
      }
    ' <<<"$raw" | sort -t= -n
}

kafka_it_seed_lag_spike_g() {
  local map
  map="$(kafka_it_group_committed_map | tr '\n' ' ')"
  if [[ "$map" != "0=0 2=100 " ]]; then
    if [[ -z "${map// }" ]]; then
      kafka_it_kafka kafka-console-consumer \
        --topic lag-spike \
        --group lag-spike-g \
        --from-beginning \
        --max-messages 100 \
        --timeout-ms 30000 >/dev/null
      kafka_it_kafka kafka-consumer-groups \
        --delete-offsets --group lag-spike-g --topic lag-spike:1 >/dev/null
      map="$(kafka_it_group_committed_map | tr '\n' ' ')"
    fi
  fi
  if [[ "$map" != "0=0 2=100 " ]]; then
    kafka_it_shape_fail "lag-spike-g" "expected committed 0=0 and 2=100 (no p1), got '${map:-unknown}'"
  fi
}

kafka_it_seed_and_check() {
  kafka_it_seed_spike_t_000
  kafka_it_seed_spike_offset_dist_60p
  kafka_it_seed_spike_tx_12
  kafka_it_seed_lag_spike
  kafka_it_seed_lag_spike_g
}

kafka_it_write_snapshot() {
  local path="$1"
  local tmp err
  tmp="$(mktemp)"
  {
    local t
    for t in spike-t-000 spike-offset-dist-60p spike-tx-12 lag-spike; do
      echo "offsets:$t"
      if ! kafka_it_kafka kafka-get-offsets --topic "$t" >"$tmp" 2>"$tmp.err"; then
        err="$(tr '\n' ' ' <"$tmp.err" 2>/dev/null || true)"
        echo "offsets:$t: unknown (${err:-command failed})"
      else
        cat "$tmp"
      fi
    done

    echo "group-offsets:lag-spike-g"
    # Only committed offset per partition (stable subset of --offsets output).
    if ! kafka_it_kafka kafka-consumer-groups --describe --group lag-spike-g --offsets \
      >"$tmp" 2>"$tmp.err"; then
      err="$(tr '\n' ' ' <"$tmp.err" 2>/dev/null || true)"
      echo "group-offsets:lag-spike-g: unknown (${err:-command failed})"
    else
      awk '
        $1 == "lag-spike-g" && $2 == "lag-spike" {
          print "p" $3 "=" $4
        }
      ' "$tmp" | sort -t= -k1.2n
    fi

    echo "group-members:lag-spike-g"
    if ! kafka_it_kafka kafka-consumer-groups --describe --group lag-spike-g --members \
      >"$tmp" 2>"$tmp.err"; then
      err="$(tr '\n' ' ' <"$tmp.err" 2>/dev/null || true)"
      echo "group-members:lag-spike-g: unknown (${err:-command failed})"
    else
      if grep -q "has no active members" "$tmp"; then
        echo "members=0"
      else
        awk 'NR > 1 && NF && $1 != "GROUP" { c++ } END { print "members=" (c+0) }' "$tmp"
      fi
    fi

    echo "groups-list"
    if ! kafka_it_kafka kafka-consumer-groups --list >"$tmp" 2>"$tmp.err"; then
      err="$(tr '\n' ' ' <"$tmp.err" 2>/dev/null || true)"
      echo "groups-list: unknown (${err:-command failed})"
    else
      sort "$tmp"
    fi
  } >"$path"
  rm -f "$tmp" "$tmp.err"
}

kafka_it_compare_snapshots() {
  local before="$1"
  local after="$2"
  if grep -q ': unknown (' "$before" "$after"; then
    echo "error: snapshot contains unknown values:" >&2
    grep ': unknown (' "$before" "$after" >&2 || true
    exit 1
  fi
  if ! diff -u "$before" "$after"; then
    echo "error: broker fixtures changed during tests (see diff above)" >&2
    # Name fixtures that differ for the negative-check contract.
    if ! diff -q <(grep -A20 'group-offsets:lag-spike-g' "$before" | head -20) \
      <(grep -A20 'group-offsets:lag-spike-g' "$after" | head -20) >/dev/null 2>&1; then
      echo "error: fixture 'lag-spike-g' changed" >&2
    fi
    exit 1
  fi
}

kafka_it_run_tests() {
  cargo test --manifest-path "$KAFKA_IT_ROOT/rust/Cargo.toml" -p kafkalyzer-kafka -- --ignored
}

main() {
  kafka_it_preflight
  kafka_it_start_broker
  kafka_it_seed_and_check

  local before after test_rc=0
  before="$(mktemp)"
  after="$(mktemp)"
  trap 'rm -f "$before" "$after"' EXIT

  kafka_it_write_snapshot "$before"
  kafka_it_run_tests || test_rc=$?
  kafka_it_write_snapshot "$after"
  kafka_it_compare_snapshots "$before" "$after"
  exit "$test_rc"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
