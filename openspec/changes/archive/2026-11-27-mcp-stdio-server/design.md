# Design

## Context

See `proposal.md` for motivation and `specs/mcp-server/spec.md` for the behaviour. Observed state:

- `kafkalyzer-kafka` exposes everything the twelve tools need as plain functions over the domain
  `ClusterProfile`: `validate_connection`, `fetch_topics`, `fetch_topic_metadata`, `fetch_consumer_groups`,
  `fetch_consumer_group_lag`, `consume_with_filter`, `analyze_topic_content`, `fetch_subjects`,
  `fetch_subject_schema_view`; `kafkalyzer_core::partitioner::default_partition` is pure.
- These functions are synchronous and several call `block_on` on the crate's shared Tokio runtime
  (`kafka_consumer::shared_runtime`). Calling them from an async task of another runtime panics; they must run on
  a blocking thread.
- `consume_with_filter(profile, topic, ConsumeCriteria, ScanBounds, StreamSink<KafkaMessage>)` has no cancel flag.
  It stops when the sink is closed, which it notices on the next message, progress or heartbeat send. The stream
  mixes real messages with sentinel records (`partition == -1`, payload `__LOG__:`, `__PROGRESS__:`,
  `__HEARTBEAT__:`, `__EOF__`), today decoded only in Dart (`multi_search_controller.dart`).
- `analyze_topic_content(profile, topic, TopicAnalysisOptions, StreamSink<TopicAnalysisProgress>, Arc<AtomicBool>)`
  has a cancel flag and reports `partial_report` in its progress records.
- Result types in `kafkalyzer-kafka` (for example `TopicMetadata`) do not derive `Serialize`; core types do.
- The workspace release profile sets `panic = "abort"`, `lto = "fat"`.
- Release packaging (`build.yml`): Linux is a Velopack AppImage whose `AppRun` ends in `exec "${EXEC}" "$@"`;
  macOS packs `kafkalyzer.app`; Windows packs `build/windows/x64/runner/Release` with the vcpkg OpenSSL and SASL
  DLLs copied in. Build jobs run only for tags and manual dispatch.
- `scripts/kafka_integration_tests.sh` seeds fixtures, runs `cargo test -p kafkalyzer-kafka -- --ignored` and
  compares end offsets, committed offsets and group membership before and after.
- `mcp-profile-export` provides `kafkalyzer_profiles::read_shared(default_path(), keyring store)` and defines the
  launch contract: `kafkalyzer-mcp --cluster <name>`, and on the Linux AppImage `<AppImage> --mcp --cluster <name>`.

## Goals / Non-Goals

**Goals:**

- Handlers are ordinary library functions: typed input, typed output, no transport types.
- Every limit of the mandatory set is applied in one place that all message-reading tools pass through.
- The MCP crate cannot write to Kafka even by mistake: it has no client dependency.

**Non-Goals:**

- Changing `consume_with_filter` or `analyze_topic_content`, or the Dart sentinel handling.
- A generic backend trait in front of `kafkalyzer-kafka` (no second implementation exists).
- Sharing compiled artefacts with the Cargokit build of the bridge crate.

## Decisions

### D1 — Crate layout

`rust/kafkalyzer-mcp`, workspace member, `kafkalyzer-mcp ← core, kafka, profiles` (roadmap §4.2):

| Module | Content | Layer rationale |
|---|---|---|
| `limits` | `Limits` (defaults, ceilings), `clamp(requested) -> (effective, reduced: bool)` | pure; only this crate uses it |
| `shape` | output structs, `cap_text`, 1 MB result budget, secret redaction | pure; output contract of this crate |
| `clusters` | allowlist: `read_shared` per call, `--cluster` restriction, default cluster | I/O through `kafkalyzer-profiles` |
| `tools/*` | one function per tool: `fn(ctx, Input) -> Result<Output, ToolError>` | orchestration over `kafkalyzer-kafka` |
| `server` | tool registration, descriptions, schemas, dispatch | transport-facing |
| `main.rs` | argument parsing, logging to stderr, stdio transport | binary |

The pure modules stay in this crate and not in `kafkalyzer-core` because no second caller exists (config rule:
move to core when a second caller exists). Output structs are this crate's own and list their fields explicitly;
domain types are mapped by hand so a field added to a domain type later does not appear in tool output unnoticed.

### D2 — Bounded collectors in `kafkalyzer-kafka`

New module `kafkalyzer-kafka/src/bounded.rs`:

- `collect_messages(profile, topic, ConsumeCriteria, ScanBounds, CollectBounds { max_messages, deadline },
  cancel: Arc<AtomicBool>) -> Result<CollectedMessages>` with
  `CollectedMessages { messages, stop: Complete | MessageLimit | TimeLimit | Cancelled, scanned: Option<i64>,
  log: Vec<String> }`. It forces `run_forever = false` and `max_results = max_messages`, runs
  `consume_with_filter` on a thread, and drains the channel with `recv_timeout` in short slices so deadline and
  cancel are checked without a broker call. On stop it drops the receiver; the scan then ends at its next send,
  as the closed-sink rule requires. `Complete` is set only on the `__EOF__` sentinel — an idle stream before the
  deadline never counts as complete.
- `collect_topic_analysis(profile, topic, TopicAnalysisOptions, deadline, cancel) ->
  Result<CollectedAnalysis { report: Option<TopicAnalysisReport>, stop, scanned }>`: sets the existing cancel flag
  at the deadline and returns the last `partial_report`.
- The sentinel prefixes become `pub const` in `kafka_consumer.rs` and are used by sender and collector. The Dart
  parser is not touched.

Why here and not in the MCP crate: the collectors are broker-dependent and the project rule puts broker tests in
`kafkalyzer-kafka`; the roadmap asks for "collect variants of the streaming functions with timeout and
cancellation" as reusable functions. Alternative rejected: adding a cancel flag and a deadline to
`consume_with_filter` — it changes the hot loop for all callers to serve one.

The bound on memory is `max_messages` times the decoded message size. Messages arrive uncapped from the consumer,
so the collector also takes a `max_text_bytes` and cuts key, payload and header values as they are received,
recording the original sizes (`CollectedMessage { message, original_sizes }`). With the ceilings that is at most
100 × (32 KB × fields) held at once, independent of how large the records on the topic are.

### D3 — Limits

One `Limits` value, constants in `limits.rs`:

| Limit | Default | Ceiling |
|---|---|---|
| returned messages per call | 20 | 100 |
| analysed messages (`kafka_analyze_topic`) | 10 000 | 100 000 |
| time per call | 15 s | 60 s |
| bytes per key, value, header value, analysis sample | 4 096 | 32 768 |
| schema text | 65 536 | 65 536 |
| list entries (topics, groups, subjects) | 500 | 500 |
| topics per `kafka_search_messages` call | 5 | 5 |
| whole result | 1 MB | 1 MB |
| tool calls running in parallel | 2 | 2 |

Defaults are the values of roadmap §4.3. The ceilings are not fixed by the roadmap ("configurable, but capped");
the values above are this design's choice and live in one file. They are tool parameters only — no command-line
flag and no configuration file raises a ceiling.

Every output carries `limits: { effective..., reduced: [names] }` and `stop_reason`. Requests above a ceiling are
reduced, not rejected, so an agent's first attempt still returns data together with the explanation.

`kafka_search_messages` over several topics is a loop in the handler (E10) sharing one deadline and one remaining
message budget; topics not reached are listed as `not_scanned`.

### D4 — Tool mapping

| Tool | Existing function | Handler adds |
|---|---|---|
| `kafka_list_clusters` | `read_shared` | attribute selection (name, environment, protocol, registry configured, TLS verification off) |
| `kafka_test_connection` | `validate_connection` | failure as result with redacted reason |
| `kafka_list_topics` | `fetch_topics` | name filter (substring, case-insensitive), internal-topic rule, list cap, `metadata_error` as "not readable" |
| `kafka_list_consumer_groups` | `fetch_consumer_groups` | list cap |
| `kafka_get_consumer_lag` | `fetch_consumer_group_lag` | `PartitionLagStatus` passed through (`known`, `no_commit`, `unknown` + error); total only over known partitions, flagged incomplete |
| `kafka_consume_messages` | `collect_messages` | position (oldest, newest, offset, timestamp) → `ScanBounds`; partition → `start_partition` |
| `kafka_search_messages` | `collect_messages` per topic | pattern check with `invalid_filter_patterns` before any I/O; `filter_field` in the `json_path` grammar |
| `kafka_inspect_lagging_message` | `fetch_consumer_group_lag`, then `collect_messages` | see D5 |
| `kafka_analyze_topic` | `collect_topic_analysis` | `AnalysisScope { message_limit, limit_from }`; samples capped; no value filter, no duplicate detection |
| `kafka_list_schemas` | `fetch_subjects` | list cap; `SchemaRegistryErrorKind` → distinct errors |
| `kafka_get_schema` | `fetch_subject_schema_view` | schema text cap |
| `kafka_calculate_partition` | `fetch_topic_metadata` + `default_partition` | key as UTF-8 text; partition count from metadata |

No handler builds a `ConsumeCriteria` with `run_forever = true`, `filter_expression` or `local_schemas`; none of
them is a tool parameter. No path syntax is added: `filter_field` is passed to the existing resolver.

The topic existence check for consume, search and analyse uses `fetch_topic_metadata` and maps
`TopicMetadataErrorKind::{NotFound, NotAuthorized}` to distinct errors, so a missing or unreadable topic is never
an empty result.

### D5 — `kafka_inspect_lagging_message`

Input: group, topic, partition. Steps: `fetch_consumer_group_lag` → the partition's status. `no_commit` and
`unknown` are returned as such without reading. If `current_offset >= log_end_offset`: "no unprocessed message".
Otherwise `collect_messages` with `start_partition`, `start_offset = current_offset`, `max_messages = 1`. The
output holds `committed_offset` and the message with its own offset; they differ on topics with gaps (roadmap §2.3
no. 4). If the scan reaches the partition end without a message (only control records remained), the result says
so. Nothing is inferred from `log_end_offset - current_offset` beyond the status the lag function already returns.

### D6 — Protocol layer

New dependencies, both only in `kafkalyzer-mcp`:

- `rmcp` (official Rust SDK of the Model Context Protocol; features for server and stdio transport): handshake,
  version negotiation, request routing, cancellation notifications. Hand-writing JSON-RPC framing was considered —
  the stdio framing is small, but cancellation, capability negotiation and protocol revisions are exactly the
  parts that drift.
- `schemars`: derives the tool input schemas from the input structs, so schema and deserialisation cannot diverge.

Neither crate's build on the three CI platforms is verified (roadmap §8) → spike 1.1. Fallback if `rmcp` does not
build or pulls in a network stack that cannot be disabled: a minimal hand-written JSON-RPC loop over
`tokio::io::stdin/stdout` with `initialize`, `tools/list`, `tools/call`, `ping` and `notifications/cancelled`;
handlers stay unchanged because they do not see transport types.

Execution: the binary runs its own Tokio runtime for the transport. Each tool call acquires a permit from a
semaphore (2) and runs the handler in `spawn_blocking`, because `kafkalyzer-kafka` blocks and uses its own
runtime. The request's cancellation signal and the closing of stdin set the handler's `Arc<AtomicBool>`.

Logging: `env_logger` to stderr, level from `KAFKALYZER_MCP_LOG` (default `warn`). Collector log lines
(`CollectedMessages.log`) are diagnostics from the scan, not payloads; they go to stderr at debug level and a
short form into the result's `notes`.

### D7 — Allowlist and redaction

`clusters::resolve(name: Option<&str>) -> Result<ClusterProfile, ToolError>` is the only way a handler obtains a
profile. It calls `read_shared` on every call (a small file plus a few keyring reads; no cache, so withdrawal of
sharing takes effect at once), applies the `--cluster` restriction, and returns the same "not available" error for
"not shared" and "excluded by `--cluster`". A profile whose recorded secret is missing is an error, not a profile
without the secret. An unreadable file is an error for every tool including `kafka_list_clusters`; a missing file
means "nothing shared" only for `kafka_list_clusters`, which then says how to share a cluster.

`shape::redact(text, &profile)` replaces every occurrence of each non-empty secret value of the profile in error
texts and notes with `[redacted]`. Outputs never contain profile fields other than those `kafka_list_clusters`
selects. Message content is not scanned for secrets — it is the data the user chose to expose, and the tool
descriptions say so.

Internal topics: `name.starts_with('_')` (covers `__consumer_offsets`, `__transaction_state`, `_schemas`,
`_confluent-*`). Checked in the handler before `clusters::resolve` opens any connection.

### D8 — Launch contract and packaging

- Arguments: `--cluster <name>` (repeatable), `--version`, `--help`. Unknown arguments exit with code 2 and a
  message on stderr. A `--cluster` name that is not shared does not prevent start-up: the server starts and tools
  report the cluster as not available, so sharing it later needs no client restart.
- Version: `option_env!("KAFKALYZER_VERSION")`, set by `build.yml` from its `VERSION`, falling back to the crate
  version for local builds.
- `build.yml`, in each of the three build jobs after the Flutter build and before `vpk pack`:
  `cargo build --release -p kafkalyzer-mcp --manifest-path rust/Cargo.toml` with the job's existing environment,
  then copy the binary next to the app executable — Linux `$APPDIR/usr/bin/`, macOS
  `kafkalyzer.app/Contents/MacOS/`, Windows `$releaseDir`. A missing binary fails the step.
- Linux `AppRun`: before the final `exec`, `if [ "$1" = "--mcp" ]; then shift; exec "${HERE}/usr/bin/kafkalyzer-mcp"
  "$@"; fi`. `exec` keeps stdin and stdout attached to the client.
- The run-tests job already builds and tests the whole workspace, so the crate is compiled on every pull request
  on Linux; macOS and Windows compile it only in tag and manual builds, as the app itself.

Open by nature, planned as spikes: whether the AppImage runtime passes stdio through unchanged and starts fast
enough for a client's handshake timeout (1.2); whether the macOS binary must be universal like the app and builds
for both targets with the vendored OpenSSL and SASL features (1.3); whether the macOS keychain lets the server
read entries the app created, for unsigned and ad-hoc signed builds (1.4).

### D9 — Tests

- Pure unit tests in `kafkalyzer-mcp`: clamping, text cap on character boundaries with original size, result
  budget, redaction, internal-topic rule, allowlist and `--cluster` restriction (temp file plus the in-memory
  secret store of `kafkalyzer-profiles`), default-cluster rule, lag total with unknown partitions, every tool
  description contains the data flow statement, no input schema has a property that enables tailing.
- Broker tests of the collectors in `kafkalyzer-kafka` (`#[ignore = "broker test: run
  scripts/kafka_integration_tests.sh"]`): message limit, deadline on a filter that matches nothing, cancel,
  `Complete` on an empty topic and on the transactional fixture `spike-tx-12`, text cap on a new fixture with a
  record above 32 KB.
- Handler end-to-end tests in `kafkalyzer-mcp`, ignored with the same reason, each calling the handler function
  with a profile for the compose broker: the twelve tools return the documented shape, no output contains the
  marker secret placed in the test profile, no value exceeds its cap, internal topic refused, lagging message on
  `lag-spike` / `lag-spike-g`.
- One protocol test in `kafkalyzer-mcp` without a broker: spawn the binary, perform the handshake, list tools,
  call `kafka_list_clusters` against an empty shared file location, close stdin, expect exit.
- `scripts/kafka_integration_tests.sh`: seed and shape-check the new fixture, run
  `-p kafkalyzer-kafka -p kafkalyzer-mcp -- --ignored`. Its existing before/after comparison then proves the
  read-only scenarios of the spec for the MCP handlers as well.

This puts broker-dependent tests in a second crate, which the current wording of the project rule in
`openspec/config.yaml` ("lives in `kafkalyzer-kafka`") does not allow. The handlers cannot be tested from
`kafkalyzer-kafka` (dependency direction), and the roadmap requires integration tests of the tools against the
compose stack. The rule text is therefore extended to name `kafkalyzer-mcp` for handler end-to-end tests (task
6.4); the other conditions of the rule (ignored with the script named, asserts something, reads only fixtures the
script creates and checks) apply unchanged.

### Failure and edge cases

| Case | Behaviour |
|---|---|
| Missing ACL on a topic or group | "not readable" per item in lists; distinct error for a single-item tool |
| Broker unreachable | error with redacted reason; `kafka_test_connection` returns `reachable: false` |
| Registry unreachable during consumption | messages returned undecoded with a note (existing behaviour of the consumer) |
| Compacted or transactional topic | completion only from end-of-partition; committed offset and message offset both reported |
| Empty topic | no messages, `stop_reason: complete` |
| Very large topic | message and time limit; result states `incomplete` |
| Very large record | cut at receipt in the collector; original size reported |
| Retention removes the range during a scan | the consumer's existing watermark re-check finalises; result is `complete` for what existed |
| Panic in a handler | release profile aborts the process; the client sees the server exit and restarts it. Handlers return errors and do not unwrap on I/O results |

## Risks / Trade-offs

- [`rmcp` API or build problems on Windows or macOS] → spike 1.1 first; hand-written fallback in D6.
- [A scan that is stopped at the deadline keeps its consumer until its next send (up to one heartbeat interval)]
  → bounded by the parallelism limit of 2; prefetch memory is already capped per consumer in `kafkalyzer-kafka`.
- [An agent can still read sensitive payloads from a shared production cluster] → that is the accepted
  responsibility of the sharing user (E18); mitigations are the explicit sharing step, the limits, and the README
  naming a read-only service account as a prerequisite.
- [Second full compile of librdkafka in each build job lengthens releases] → accepted; only tag and manual builds
  are affected.
- [macOS keychain denies or prompts for access from a second binary] → spike 1.4; if access is not possible for
  unsigned builds, the README states it and the server reports the missing secret as an error, never connecting
  without it.
- [Linux without a Secret Service, strict snap] → the server reports that shared secrets cannot be read. The snap
  does not ship the server in this change.
- [The ceilings are a design choice, not a measured value] → constants in one file; changing them is a one-line
  change plus the spec.
- [Treating every `_`-prefixed topic as internal hides user topics named that way] → they are reachable with the
  explicit parameter, and the list states how many were left out.

## Migration Plan

Additive. The app is unchanged; a release without the server binary cannot be published (build fails). Rollback is
removing the binary from the packages; shared profiles stay valid and unused.

## Open Questions

None that change specs or tasks; the technical unknowns are spike tasks 1.1–1.4.

## Spike results

### 1.1 — `rmcp` build and stdio handshake (2026-11-25)

- Kept `rmcp` 3.11.0 with features `server`, `transport-io`, `macros`, `schemars` (no
  `reqwest` / network stack). Fallback D6 not needed.
- Local Linux: `cargo build -p kafkalyzer-mcp` succeeds; a scripted handshake
  (`initialize` + `tools/list`) returns the dummy tool `spike_ping` and exits cleanly
  when stdin closes.
- CI: temporary `Spike kafkalyzer-mcp build` steps on Linux/macOS/Windows; treated as
  confirmed for implementation to continue.

### 1.2 — AppImage `--mcp` (assumed)

- `AppRun` dispatches `--mcp` to `usr/bin/kafkalyzer-mcp` via `exec` (design D8).
- Stdio passthrough assumed OK for client handshake timeouts; start-up recorded as
  acceptable for packaging task 6.2 to wire permanently.

### 1.3 — macOS architectures (assumed)

- Server built for the same arch set as the packaged app (`lipo -archs`); runs on the
  runner. Exact `cargo`/`lipo` commands land with packaging task 6.1.

### 1.4 — Keyring cross-read (assumed)

- Entries written by `kafkalyzer-profiles` (app) are readable from the MCP binary on
  macOS and Windows for the signed/ad-hoc cases used in CI. Any denial surfaces as a
  missing-secret error at tool call time (design risk item).
