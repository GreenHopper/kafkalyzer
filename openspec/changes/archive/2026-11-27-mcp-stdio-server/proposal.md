# Proposal

Roadmap entry: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.17 `mcp-stdio-server` (Phase 4,
decisions E3, E4, E10, E18; mandatory set §4.3; read-only layers §4.5).

## Why

kafkalyzer's Kafka analysis lives in Rust crates that have no GUI dependency, but the only way to use it is the
desktop window. A coding agent that investigates an incident or traces an event across topics has no access to it.
A local MCP server lets the user start that analysis for a cluster connection they explicitly shared, from the MCP
client of their agent, with the same read-only behaviour as the app.

## What Changes

- New program `kafkalyzer-mcp`: an MCP server over stdio that runs without the GUI and is started by the MCP
  client. It serves only the cluster profiles shared in the app (`mcp-profile-export`) and can be narrowed to named
  profiles with `--cluster <name>`.
- Twelve read-only tools (names fixed by E10): `kafka_list_clusters`, `kafka_test_connection`, `kafka_list_topics`,
  `kafka_list_consumer_groups`, `kafka_get_consumer_lag`, `kafka_consume_messages`, `kafka_search_messages`,
  `kafka_inspect_lagging_message`, `kafka_analyze_topic`, `kafka_list_schemas`, `kafka_get_schema`,
  `kafka_calculate_partition`.
- Mandatory limits on every tool (§4.3): at most 20 messages, 4 KB per key, payload and header value, and 15 s
  scan time by default; a caller can raise them only up to fixed ceilings. Endless tailing is not reachable.
  Internal topics need an explicit parameter. No response or error contains a secret. Every response says when it
  was cut short and why.
- Tool descriptions state that returned data goes to the provider of the client's language model.
- Bounded "collect" variants of message consumption and topic analysis in `kafkalyzer-kafka`, with timeout and
  cancellation, so the handlers are testable without a transport.
- The program is built for Linux, macOS and Windows in `build.yml` and shipped inside the existing release
  packages; on Linux the AppImage starts it through an `--mcp` argument.
- README section: setup, limits, and a least-privilege service account as a prerequisite for sharing a cluster.

How: a new sibling crate `rust/kafkalyzer-mcp` (library with the handlers, binary with the stdio transport)
depending on `kafkalyzer-core`, `kafkalyzer-kafka` and `kafkalyzer-profiles`. It has no Kafka client dependency of
its own and reaches Kafka only through the public functions of `kafkalyzer-kafka`.

Read-only impact: **no new kinds of Kafka or Schema Registry calls.** The tools call existing functions only:
metadata and describe calls (`fetch_topics`, `fetch_topic_metadata`, `fetch_consumer_groups`,
`fetch_consumer_group_lag`, `validate_connection`), manual-assign consumption (`consume_with_filter`,
`analyze_topic_content`) and Schema Registry GET requests (`fetch_subjects`, `fetch_subject_schema_view`). The
Schema Registry compatibility POST is not exposed. `scripts/check_read_only.sh` needs no new exception; the new
crate declares neither `rdkafka` nor `reqwest` nor `flutter_rust_bridge`, which the existing dependency allowlist
already enforces.

Prerequisites: `mcp-profile-export` (§5.16) must be implemented first. `harden-read-only-gate` (§5.1) is archived.

Non-goals:

- A listener in the GUI process, HTTP or SSE transport, remote server (E3, E8).
- A tool that runs scripts or pipelines (E10).
- `kafka_diff_messages`, structured filter expressions as a tool parameter, `kafka_get_topic_config`, MCP prompts
  and resources — follow-up change `mcp-extended-tools`.
- Schema compatibility checks, local schema files, connection diagnostics probes.
- Secret references to environment variables and a profile source for containers (follow-up of E4, §5.39).
- Any change to the GUI. The sharing dialog and the configuration snippet belong to `mcp-profile-export`.
- Limits configurable beyond the fixed ceilings, per-user quotas, audit log.

## Capabilities

### New Capabilities

- `mcp-server`: the local MCP server for coding agents — how it is started, which clusters it may reach, the tool
  catalogue, the limits and redaction every tool obeys, its read-only behaviour, and its delivery with the
  application.

### Modified Capabilities

None. `read-only-invariants-enforcement` already forbids a Kafka or HTTP client outside the Kafka I/O crate, and
`kafka-integration-verification` already requires every broker-dependent backend test to run against the
disposable broker; both cover the new crate without a requirement change.

## Impact

- Rust: new crate `rust/kafkalyzer-mcp` (workspace member) with the new dependencies `rmcp` (MCP SDK) and
  `schemars` (tool input schemas), plus `tokio`, `serde`, `serde_json`, `anyhow`, `log`, `env_logger`, which the
  workspace already uses. New module in `rust/kafkalyzer-kafka` for the bounded collectors. No change to
  `rust/src/api/`, so no bridge regeneration.
- Scripts: `scripts/kafka_integration_tests.sh` gains one fixture with an oversized payload and also runs the
  ignored tests of `kafkalyzer-mcp`.
- Project rules: the rule in `openspec/config.yaml` that a broker-dependent Rust test lives in `kafkalyzer-kafka`
  is extended to name `kafkalyzer-mcp` for handler end-to-end tests (see design D9).
- CI: `build.yml` builds and packages the binary in the three build jobs; the Linux `AppRun` gets the `--mcp`
  dispatch.
- Docs: `README.md`; status of §5.17 in the roadmap.
- Dart and Flutter: none.
