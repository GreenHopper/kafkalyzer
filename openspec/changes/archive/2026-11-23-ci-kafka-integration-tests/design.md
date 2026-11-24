# Design

## Context

See proposal.md (Why) for the findings. Current state, checked 2026-11-23:

- `.github/workflows/build.yml` has these jobs: `read-only-gate`, `run-tests`
  (`needs: [read-only-gate]`, runs `cargo test --manifest-path rust/Cargo.toml`),
  `quality-gates`, the three builds
  (`needs: [run-tests, quality-gates]`) and the release
  (`needs: [build-linux, build-macos, build-windows]`).
- `rust/Cargo.toml` is a workspace (`.`, `kafkalyzer-core`, `kafkalyzer-kafka`)
  whose root is also the package `rust_lib_kafkalyzer`. It has no
  `default-members`, so plain `cargo test` tests only the root package. It
  lists 35 tests; with `--workspace` it lists 319, all passing (9 ignored).
- `cargo test -p kafkalyzer-kafka -- --ignored --list` lists 7 tests:

  | Test | File | Reads | Asserts |
  |---|---|---|---|
  | `integration_lag_spike_g_empty_group_has_accurate_lags` | kafka_metadata.rs | `lag-spike`, group `lag-spike-g` | state Empty; p0 Known, p1 NoCommit, p2 Known lag 50 |
  | `integration_fetch_topic_metadata_existing_and_missing` | kafka_metadata.rs | `spike-t-000` | partitions > 0; missing topic → NotFound |
  | `integration_describe_topic_configs_returns_cleanup_policy` | kafka_metadata.rs | `spike-t-000` | `cleanup.policy` present |
  | `integration_describe_topic_configs_detailed_existing_and_missing` | kafka_metadata.rs | `spike-t-000` | entries; missing → TopicNotFound |
  | `integration_cluster_overview_and_time_range` | topic_time_range.rs | `spike-tx-12` | brokers, cluster id; 1 partition, oldest/newest known |
  | `spike_parallel_fetch_watermarks` | kafka_metadata.rs | `spike-offset-dist-60p` | 60 partitions; sequential == parallel watermarks |
  | `spike_describe_configs_and_single_topic_metadata` | kafka_metadata.rs | `spike-t-0000..0499` | nothing (prints timings) |

- Every test hard-codes `localhost:9094`, the host port that
  `docker-compose.yaml` maps for service `kafka` (container `sift_kafka`, image
  `confluentinc/cp-kafka:7.6.0`, KRaft, internal listener `sift_kafka:29092`,
  logs in the container's `/tmp`, no volume).
- The image ships `kafka-topics`, `kafka-console-producer` (no partition
  option), `kafka-console-consumer`, `kafka-consumer-groups`,
  `kafka-get-offsets` and `kafka-producer-perf-test` (`--transactional-id`,
  `--transaction-duration-ms`).
- `scripts/check_read_only.sh` scans `rust/**/*.rs` and `lib/src/**/*.dart`
  only.
- static-analysis-gates, "Quality Gate Performs No Cluster Or Registry Access",
  keeps the broker out of `scripts/quality_gates.sh`.

## Goals / Non-Goals

Goals: every Rust unit test gates every push. Every broker test runs on every
push against fixtures the run creates itself. The run proves the tests changed
no broker data. Local and CI runs use one command.

Non-goals: see proposal.md.

## Decisions

### D1. The broker is the compose `kafka` service

`docker compose up -d kafka` starts only that service, because it has no
`depends_on`. Local runs and CI use the same broker definition, with the
listener on `localhost:9094` that the tests already use.

Rejected: a GitHub `services: kafka` container. It would copy the KRaft
environment into the workflow, creating a second definition that can drift.
It also cannot run locally.

### D2. One entry point: `scripts/kafka_integration_tests.sh`

Steps, stopping at the first failure. Every broker command runs as
`docker exec sift_kafka <tool> --bootstrap-server sift_kafka:29092 …`:

1. **Preflight.** Check that `docker` and `docker compose` are available.
   If not, raise a tooling error that names the missing runtime.
2. **Start.** Run `docker compose up -d kafka`, then wait up to 90 s with a
   retry loop on `kafka-topics --list`. On timeout, report
   "broker unavailable" and exit non-zero, without running any test.
3. **Seed and check** (D3).
4. **Snapshot before** (D4).
5. **Test.** Run `cargo test --manifest-path rust/Cargo.toml -p kafkalyzer-kafka -- --ignored`.
6. **Snapshot after and compare** (D4). The script exits non-zero if step 5
   failed or the comparison fails. It runs step 6 even when step 5 failed, so
   a data change is never hidden by a test failure.

The script takes no broker address and reads no Kafka environment variable,
so every write goes to the compose container (spec: seeding confined).

### D3. Fixtures: deterministic creation plus a shape check

| Fixture | Creation | Expected shape |
|---|---|---|
| `spike-t-000` | `kafka-topics --create --partitions 1` | 1 partition |
| `spike-offset-dist-60p` | `--partitions 60` | 60 partitions |
| `spike-tx-12` | `--partitions 1`, then `kafka-producer-perf-test --topic spike-tx-12 --num-records 11 --record-size 32 --throughput -1 --transactional-id kafkalyzer-it-tx --transaction-duration-ms 600000` (one committed transaction) | end offset 12 (11 records + commit marker) |
| `lag-spike` | `--partitions 3`, then 150 records `k0:msg-N` via `kafka-console-producer --property parse.key=true --property key.separator=:`. With the default partitioner, murmur2 maps `k0` to partition 2 of 3 | end offsets `0:0, 1:0, 2:150` |
| `lag-spike-g` | `kafka-console-consumer --group lag-spike-g --from-beginning --max-messages 100`, then `kafka-consumer-groups --delete-offsets --group lag-spike-g --topic lag-spike:1` (the recipe from the archived spike.md) | Empty; committed `p0=0`, `p1` none, `p2=100` |

For each fixture the script reuses it when it already exists and checks its
shape; otherwise it creates the fixture and then checks the shape. A mismatch
stops the run before any test. The error names the fixture and the
difference, and gives the reset command
`docker compose rm -sf kafka && docker compose up -d kafka`. The broker keeps
its data in the container's `/tmp`, so this reset is complete. The script never
deletes or repairs a fixture by itself, because the local broker may hold a
developer's data.

Fixture names stay as the tests use them, so no test logic changes. The
`#[ignore]` reasons become one text:
`"broker test: run scripts/kafka_integration_tests.sh"`.

Rejected: an unkeyed producer (the spike's recipe). The sticky partitioner
picks a random partition. Also rejected: seeding from Rust. It would put a
producer in the Kafka crate and break the read-only gate.

### D4. Read-only comparison

Each snapshot is one text file with lines in a fixed order:

- `kafka-get-offsets --topic <t>` for the four fixture topics (end offsets),
- `kafka-consumer-groups --describe --group lag-spike-g --offsets` (only the
  committed offset per partition),
- `kafka-consumer-groups --describe --group lag-spike-g --members` (member count),
- `kafka-consumer-groups --list` (sorted).

The script diffs the two snapshots. Any difference fails the run and prints
the diff. When a snapshot command fails, its line reads
`<item>: unknown (<error>)`, and that fails the run (spec: unknown is not
unchanged). Task 1.2 confirms on a fresh broker that two test runs in a row
leave the snapshot identical. In particular, the lag code's
`group.id`-only OffsetFetch must not add a group to `--list`.

### D5. Test changes

Delete `spike_describe_configs_and_single_topic_metadata` (user decision).
Keep `spike_parallel_fetch_watermarks`: it is cheap and it asserts. After the
deletion, CI runs *all* ignored `kafkalyzer-kafka` tests, with no name filter
or skip list, so a new broker test runs automatically. The two
`kafkalyzer-core` benchmarks are not run: the command is limited to
`-p kafkalyzer-kafka`.

### D6. Seeding is not a read-only exception

The read-only invariant governs the application and its entry points (GUI,
headless runner, MCP). Fixture seeding is test infrastructure. It writes only
into the disposable container (D2) and lives in `scripts/`, which
`check_read_only.sh` does not scan. The gate passes unchanged, so no exception
is recorded. `openspec/config.yaml` states this so later changes do not
re-litigate it (task 4.1).

### D7. CI wiring

- `run-tests`: `cargo test --manifest-path rust/Cargo.toml --workspace`.
- New job `kafka-integration` (ubuntu-latest, `needs: [read-only-gate]`,
  `timeout-minutes: 25`): checkout, the `run-tests` apt packages, Rust
  (`actions-rust-lang/setup-rust-toolchain@v1`, `cache-workspaces: "rust"`),
  then `bash scripts/kafka_integration_tests.sh`. The runner image ships
  Docker and Compose v2. No Flutter step.
- `build-linux`, `build-macos`, `build-windows`:
  `needs: [run-tests, quality-gates, kafka-integration]`.

## Risks / Trade-offs

- **Broker start flakiness** → 90 s readiness loop, and a clear "broker
  unavailable" error instead of a test failure.
- **Partitioner assumption** (`k0` → partition 2) → the shape check catches a
  wrong mapping before any test runs. If task 1.1 sees a different partition,
  it changes the key there.
- **Cold CI time** for the rdkafka `cmake-build` (~8–12 min) → the job runs in
  parallel with `run-tests`, and the cargo cache is shared by workspace.
- **`--workspace` may expose hidden CI-only failures** (for example
  environment-dependent unit tests) → they all pass locally today. A failure
  is a real finding, fixed in this change.
- **Broker tests now block releases** (user decision) → a red infra run
  blocks a release until rerun. Accepted.

## Open Questions

None.
