# Proposal: ci-kafka-integration-tests (Q-11)

## Why

Backlog `design/code-quality-refactoring-backlog.md` §3 Q-11 (change id from
§8) wants the broker-dependent Rust tests run in CI. Checking the backlog
entry against the code shows the gap is wider than it says. Three of its
claims are wrong:

- **CI does not run most Rust unit tests.** The `run-tests` job runs
  `cargo test --manifest-path rust/Cargo.toml`. The workspace root is also a
  package (`rust_lib_kafkalyzer`) and declares no `default-members`, so the
  command tests only that crate: 35 of 319 tests. The 107 `kafkalyzer-kafka`
  and 167 `kafkalyzer-core` unit tests never run on a push. They pass today
  (`cargo test --workspace`, 2026-11-23).
- **There are 7 broker tests, not 6.** All of them are in `kafkalyzer-kafka`:
  five `integration_*` tests in `kafka_metadata.rs` and `topic_time_range.rs`,
  plus two `spike_*` tests. `duplicate_fingerprint.rs:296` is a CPU benchmark
  in `kafkalyzer-core` and needs no broker.
- **`docker-compose.yaml` does not create the fixtures.** Its seed services
  create `user-activity`, `system-logs`, `inventory-updates` and
  `avro-test-topic`. The tests need `lag-spike` with group `lag-spike-g`,
  `spike-t-000`, `spike-offset-dist-60p` and `spike-tx-12`, which were made by
  hand during earlier spikes. Only `lag-spike-g` has a written recipe
  (`openspec/changes/archive/2026-11-14-fix-consumer-lag-accuracy/spike.md`).
  That recipe is not deterministic: the console producer sends unkeyed
  records, and the test only passes when all 150 land on partition 2. Two
  `#[ignore]` reasons also name `spike-t-0000`, while the tests read
  `spike-t-000`.

As a result, no test of the rdkafka metadata, admin, lag or time-range code
runs on a push. A fresh checkout cannot run the broker tests either, because
their data exists only on one developer's broker.

## What Changes

- **CI runs the whole Rust workspace.** `run-tests` uses
  `cargo test --workspace`, so the core and Kafka crate unit tests gate every
  push.
- **One entry point for the broker tests: `scripts/kafka_integration_tests.sh`.**
  It starts the existing compose `kafka` service and waits until it is ready.
  It creates every fixture the broker tests read and checks that each fixture
  has the expected shape. Then it runs
  `cargo test -p kafkalyzer-kafka -- --ignored` and checks afterwards that the
  tests changed no fixture data. The same command runs locally and in CI.
- **New CI job `kafka-integration`.** It runs the script on every push and pull
  request. The build jobs list it in `needs:`, so a failing broker test blocks
  builds and releases (user decision).
- **Delete the print-only spike** `spike_describe_configs_and_single_topic_metadata`.
  It asserts nothing, needs 500 topics, and its findings are recorded in the
  archived topic-config design (user decision). `spike_parallel_fetch_watermarks`
  stays, because it asserts that sequential and parallel watermark reads match.
- **Accurate `#[ignore]` reasons.** Each remaining broker test names the
  script as the way to run it.
- **Project rules** in `openspec/config.yaml`: how a broker test is added, the
  local verification step, and why fixture seeding is not a read-only
  exception (see design D6).
- **Backlog**: correct the Q-11 entry and mark it implemented.

## Capabilities

### New Capabilities

- `kafka-integration-verification`: the backend's Kafka read paths are verified
  against a real, disposable broker on every change. That broker is seeded
  from a script, and the tests are checked to change no broker data.

### Modified Capabilities

None. `static-analysis-gates` keeps its rule that the quality gate opens no
cluster connection. The broker job runs on its own, outside the gate.
`read-only-invariants-enforcement` is unchanged.

## Read-Only Impact

No new Kafka or Schema Registry calls in the application. The tests use
existing read calls only: metadata, describe configs, watermarks, the group
offset list, the consumer-group describe and assign-based reads.

Fixture seeding writes to a broker: it creates topics, produces records,
commits group offsets with the console consumer and deletes one partition's
offsets. Those writes happen only inside the disposable compose container,
through `docker exec`. The script takes no bootstrap address, so it cannot be
pointed at another cluster. It is test infrastructure under `scripts/`, not an
application entry point. `scripts/check_read_only.sh` scans `rust/` and
`lib/src/` and passes unchanged. No gate exception is needed.

## Non-Goals

- No broker access in `scripts/quality_gates.sh` (static-analysis-gates forbids it).
- No Schema Registry, ACL/"not readable" or TLS broker scenarios. They would
  need an auth-enabled broker and are a follow-up.
- No broker runs on macOS or Windows runners.
- The two `kafkalyzer-core` benchmarks (`duplicate_fingerprint.rs`,
  `tests/bench_filter_expr.rs`) stay ignored and are not run.
- No changes to the dev seed services in `docker-compose.yaml`, and no new
  dependency.

## Prerequisites

None. Q-9 (`verify-generated-bindings`) is implemented; this change does not
touch bridge code.

## Impact

- `.github/workflows/build.yml`: add `--workspace` to `run-tests`, add the
  `kafka-integration` job, and add that job to the build jobs' `needs:`.
- New `scripts/kafka_integration_tests.sh`.
- `rust/kafkalyzer-kafka/src/kafka_metadata.rs` and `topic_time_range.rs`:
  delete one test and update the `#[ignore]` reasons. No production code
  changes.
- `openspec/config.yaml` and `design/code-quality-refactoring-backlog.md`.
- CI time: one more Linux job (about 8–12 min cold). It runs in parallel with
  `run-tests`.
