# Tasks

Prerequisite: change `mcp-profile-export` is implemented (crate `kafkalyzer-profiles` exists).

## 1. Spikes

- [x] 1.1 Create a minimal `rust/kafkalyzer-mcp` binary with `rmcp` and `schemars` that answers the handshake and
      lists one dummy tool over stdio; build it in the Linux, macOS and Windows jobs on a branch and verify all
      three succeed, or switch to the hand-written fallback of design D6 and record the result in `design.md`
- [x] 1.2 Pack an AppImage with the `--mcp` dispatch in `AppRun` and verify that an MCP client (or a script
      piping the handshake) gets the tool list through `<AppImage> --mcp`; record start-up time in `design.md`
- [x] 1.3 On macOS, check the architectures of the packaged app (`lipo -archs`) and build the server for the same
      set; verify the result runs on the runner and record the build commands in `design.md`
- [x] 1.4 On macOS and Windows, write a keyring entry with the app-side code of `kafkalyzer-profiles` and read it
      from the spike binary; verify it is readable, and record any prompt or denial in `design.md`

## 2. Bounded collectors in `kafkalyzer-kafka`

- [x] 2.1 Turn the sentinel prefixes in `kafka_consumer.rs` into public constants used by the senders; verify
      `cargo test -p kafkalyzer-kafka` passes and the emitted strings are unchanged (existing tests)
- [x] 2.2 Implement `bounded::collect_messages` with message limit, deadline, cancel flag and text cap at
      receipt; verify with unit tests on a fed channel: sentinel records are not returned as messages, `Complete`
      only on the end sentinel, cut values keep their original size and whole characters
- [x] 2.3 Implement `bounded::collect_topic_analysis` with deadline and cancel; verify with a unit test on a fed
      channel that the last partial report is returned and marked partial
- [x] 2.4 Add a fixture with one record above 32 KB to `scripts/kafka_integration_tests.sh` (seed and shape
      check) and ignored broker tests for the collectors: message limit, deadline on a non-matching filter,
      cancel, empty topic, `spike-tx-12` completes, oversized record is cut; verify
      `bash scripts/kafka_integration_tests.sh` passes
- [x] 2.5 Run `cargo fmt --all`, `cargo clippy --workspace --all-targets`, `cargo test --workspace` and
      `scripts/check_read_only.sh`; verify all pass

## 3. Crate `kafkalyzer-mcp`: pure parts and allowlist

- [x] 3.1 Set up the crate (library and binary target, dependencies from the spike, no `rdkafka`, `reqwest` or
      `flutter_rust_bridge`), add it to the workspace; verify `cargo build --workspace` and
      `scripts/check_read_only.sh` pass
- [x] 3.2 Implement `limits` (defaults, ceilings, clamping with "reduced" report); verify with unit tests for
      every limit of design D3
- [x] 3.3 Implement `shape` (output structs, text cap, 1 MB result budget, redaction); verify with unit tests
      including multi-byte text at the cut and a secret inside an error text
- [x] 3.4 Implement `clusters` (shared profiles read per call, `--cluster` restriction, default cluster, internal
      topic rule); verify with unit tests using a temp file and the in-memory secret store: unshared and excluded
      clusters give the same error, missing secret is an error, unreadable file is an error, missing file lists
      nothing

## 4. Tool handlers

- [x] 4.1 Implement `kafka_list_clusters` and `kafka_test_connection`; verify with unit tests that the cluster
      output has exactly the documented attributes
- [x] 4.2 Implement `kafka_list_topics`, `kafka_list_consumer_groups`, `kafka_get_consumer_lag` and
      `kafka_calculate_partition`; verify with unit tests on mapped fixtures: list cap with total, internal topics
      counted and left out, "not readable" topics kept, lag total incomplete with unknown partitions
- [x] 4.3 Implement `kafka_consume_messages` and `kafka_search_messages` (shared deadline and budget over topics,
      pattern check before I/O); verify with unit tests for the position mapping, the invalid pattern error and
      the per-topic scan state
- [x] 4.4 Implement `kafka_inspect_lagging_message` as in design D5; verify with unit tests for `no_commit`,
      `unknown` and caught-up inputs that no read is started
- [x] 4.5 Implement `kafka_analyze_topic`, `kafka_list_schemas` and `kafka_get_schema`; verify with unit tests
      that samples and schema text are capped and registry error kinds map to distinct errors
- [x] 4.6 Add ignored end-to-end tests calling each handler against the compose broker and extend
      `scripts/kafka_integration_tests.sh` to run `-p kafkalyzer-mcp -- --ignored`; verify the script passes,
      including its before/after comparison, and that the tests assert: no marker secret in any output, no value
      above its cap, internal topic refused, lagging message found on `lag-spike`

## 5. Server and binary

- [x] 5.1 Register the twelve tools with descriptions (data flow statement, default limits and ceilings) and
      derived input schemas; verify with unit tests that every description contains the statement and that no
      schema has a tailing or write parameter
- [x] 5.2 Implement dispatch with the parallelism limit, blocking execution and cancellation; verify with a unit
      test that a cancelled call sets the handler's flag and that a third concurrent call waits
- [x] 5.3 Implement `main.rs` (`--cluster`, `--version`, `--help`, stderr logging, exit on closed stdin); verify
      with a protocol test that spawns the binary, performs handshake, tool list and `kafka_list_clusters`, closes
      stdin and sees the process exit, and that an unknown argument exits with code 2
- [x] 5.4 Run `cargo fmt --all`, `cargo clippy --workspace --all-targets` and `cargo test --workspace`; verify all
      pass

## 6. Packaging, rules and documentation

- [x] 6.1 Build the server in the Linux, macOS and Windows jobs of `build.yml` with `KAFKALYZER_VERSION` set and
      copy it next to the app executable before packaging, failing the step when the binary is missing; verify
      with a manual workflow run that each package contains it
- [x] 6.2 Add the `--mcp` dispatch to the Linux `AppRun` in `build.yml`; verify on the built AppImage that
      `<AppImage> --mcp --version` prints the server version
- [x] 6.3 Add a README section "MCP server" (connecting a client with the snippet from the app, tool list, limits
      and ceilings, data flow to the model provider, read-only service account as a prerequisite, keyring
      preconditions per platform); verify every tool name and limit matches the code
- [x] 6.4 Extend the broker-test rule in `openspec/config.yaml` to name `kafkalyzer-mcp` for handler end-to-end
      tests, and mark §5.17 as implemented in the roadmap; verify `openspec validate mcp-stdio-server --strict`
      passes

## 7. Verification

- [x] 7.1 Run `scripts/quality_gates.sh`, `cargo fmt --all`, `cargo clippy --workspace --all-targets`,
      `cargo test --workspace`, `flutter analyze`, `flutter test`, `scripts/check_read_only.sh`,
      `bash scripts/test_check_read_only.sh` and `bash scripts/kafka_integration_tests.sh`; verify all pass
- [x] 7.2 With an installed package on one platform, share a test cluster in the app, paste the snippet into an
      MCP client, and verify the client lists the tools, reads messages under the default limits, and gets "not
      available" after sharing is switched off
- [x] 7.3 Run the server against a broker whose service account has only read and describe permissions and
      verify every tool works (acceptance item of roadmap §6.4, phase 4); record the result in the README section
