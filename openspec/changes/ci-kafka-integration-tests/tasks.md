# Tasks

No `kafkalyzer-core`, bridge (`rust/src/api/`), Dart or ARB changes. No
production code changes. Broker tasks need Docker and run against the compose
`kafka` service.

## 1. Spike: confirm the fixture recipe on a fresh broker (design D3, D4)

- [x] 1.1 Reset the broker (`docker compose rm -sf kafka && docker compose up -d kafka`). Run the D3 commands for `lag-spike` / `lag-spike-g` by hand. Verify with `kafka-get-offsets` that the end offsets are `0:0,1:0,2:150`. Verify with `kafka-consumer-groups --describe --group lag-spike-g` that the group is Empty with committed `p0=0`, no `p1`, `p2=100`. If `k0` lands elsewhere, choose the key that lands on partition 2 and update design D3
- [x] 1.2 Create the other three fixtures per D3 by hand (`spike-tx-12` end offset 12). Take the D4 snapshot, run `cargo test --manifest-path rust/Cargo.toml -p kafkalyzer-kafka -- --ignored` twice, and take the snapshot again. All 7 tests pass, and the snapshots are identical, including `kafka-consumer-groups --list`. If `--list` changes, record why in design D4 and pause for a decision

## 2. Rust tests (design D5)

- [x] 2.1 Delete `spike_describe_configs_and_single_topic_metadata` from `rust/kafkalyzer-kafka/src/kafka_metadata.rs` and drop any `use` it alone needed. `cargo clippy --workspace --all-targets` shows no new warning
- [x] 2.2 Set the `#[ignore]` reason of the remaining 6 broker tests to `"broker test: run scripts/kafka_integration_tests.sh"`. `cargo test --manifest-path rust/Cargo.toml -p kafkalyzer-kafka -- --ignored --list` lists exactly 6 tests, and `rg 'localhost:9094 with' rust` finds nothing
- [x] 2.3 `cargo fmt --all` and `cargo test --manifest-path rust/Cargo.toml --workspace` pass (no broker needed)

## 3. Entry point script (design D2–D4)

- [x] 3.1 Add `scripts/kafka_integration_tests.sh` per D2: preflight, compose start, 90 s readiness loop, seed and shape check, snapshot, `cargo test -p kafkalyzer-kafka -- --ignored`, snapshot and diff. Steps are functions, and `main "$@"` runs only when the script is executed, so it can also be sourced. No broker-address parameter, and no Kafka environment variable is read
- [x] 3.2 Positive runs: on a reset broker, `bash scripts/kafka_integration_tests.sh` exits 0, and a second run (fixtures reused) also exits 0
- [x] 3.3 Negative checks, each exits non-zero with the named message: (a) produce one record into `spike-t-000`, then run: it stops before the tests, names `spike-t-000` and prints the reset command; (b) source the script, take a snapshot, commit `lag-spike-g` offsets with a short console consumer, snapshot again and compare: it fails and names `lag-spike-g`; (c) `docker compose stop kafka` plus a blocked start (for example, a wrong compose project via `COMPOSE_FILE=/dev/null`): it reports the broker or runtime as unavailable and runs no test. Reset the broker afterwards
- [x] 3.4 `bash -n scripts/kafka_integration_tests.sh` passes, and `shellcheck` passes if it is installed. `scripts/check_read_only.sh` passes unchanged

## 4. CI, rules and backlog (design D6, D7)

- [x] 4.1 `.github/workflows/build.yml`: add `--workspace` to the `run-tests` Rust step, add the `kafka-integration` job per D7, and add `kafka-integration` to `needs:` of `build-linux`, `build-macos` and `build-windows`. Check the YAML with `python3 -c 'import yaml,sys;yaml.safe_load(open(".github/workflows/build.yml"))'`
- [x] 4.2 `openspec/config.yaml`: (a) Read-Only Invariant: fixture seeding in `scripts/kafka_integration_tests.sh` writes only to the disposable compose broker, is test infrastructure rather than an entry point, and is not a gate exception. (b) Code Quality: a broker-dependent Rust test lives in `kafkalyzer-kafka`, is `#[ignore]`d with the reason naming the script, asserts something, and reads only fixtures that the script creates and shape-checks. (c) Verification: add the step "when `rust/kafkalyzer-kafka` changed, `bash scripts/kafka_integration_tests.sh` (needs Docker)". `openspec validate --specs` still passes
- [x] 4.3 `design/code-quality-refactoring-backlog.md`: correct the Q-11 evidence (7 broker tests, fixtures not in compose, `duplicate_fingerprint.rs` is a core benchmark, CI ran 35 of 319 Rust tests) and mark Q-11 implemented in the §3 table and §8 list

## 5. Verification

- [x] 5.1 Every step exits 0: `cargo fmt --all --check`, `cargo clippy --workspace --all-targets`, `cargo test --manifest-path rust/Cargo.toml --workspace`, `bash scripts/kafka_integration_tests.sh`, `flutter analyze`, `flutter test`, `scripts/check_read_only.sh`, `KAFKALYZER_BASE_REF=origin/main bash scripts/quality_gates.sh`, `openspec validate ci-kafka-integration-tests --strict`
- [ ] 5.2 After push (needs a human): the PR run shows `kafka-integration` green, the `run-tests` log lists all workspace crates, and the build jobs waited for `kafka-integration`

## Workflow follow-up

- Archive `ci-kafka-integration-tests` and sync `kafka-integration-verification` into `openspec/specs/`.
