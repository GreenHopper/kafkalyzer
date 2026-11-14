# Proposal: harden-read-only-gate

Source: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md`, §5.1 (change id `harden-read-only-gate`), motivated
by §2.3 Nr. 1, with the crate rules of §4.2 and the three-layer model of §4.5.

## Why

The read-only CI gate (`scripts/check_read_only.sh`) only greps for producer types, commits, `subscribe(`, auto-commit
and `.send(`. It does not catch mutating `AdminClient` calls (although `AdminClient` is used in `kafka_metadata.rs` and
`kafka_analyzer.rs`), offset stores, mutating Schema Registry HTTP methods, or an `rdkafka`/`flutter_rust_bridge`
dependency added to the wrong crate. Upcoming headless entry points (MCP, Phase 4) must inherit the same assurance, so
the gate has to cover these paths first.

## What Changes

- The gate fails on mutating admin calls: `create_topics`, `delete_topics`, `create_partitions`, `alter_configs`,
  `incremental_alter_configs`, `delete_records`, `delete_groups`, and on the offset-store calls `store_offset`,
  `store_offsets`, `store_offset_from_message`. No exception marker applies to these.
- The gate fails on HTTP write methods `.put(`, `.delete(`, `.patch(` and on `Method::POST|PUT|PATCH|DELETE` in Rust
  sources, and allows `.post(` only on a line carrying an exception marker with a written reason. The HTTP checks
  scan Rust files only, because Dart uses unrelated `.delete(` methods (secure storage, directories).
- The gate fails when `rdkafka`, `rdkafka-sys` or `reqwest` is declared in any `Cargo.toml` under `rust/` other than
  `rust/kafkalyzer-kafka/Cargo.toml`, or `flutter_rust_bridge` in any other than `rust/Cargo.toml`.
- `scripts/test_check_read_only.sh` gets one positive (rejected) and one negative (accepted) case per new pattern.
- The CI job `read-only-gate` also runs `scripts/test_check_read_only.sh`, so a broken gate cannot pass silently.
- The one existing Schema Registry `POST` (`/compatibility`, `schema_registry.rs`) gets the reasoned exception marker
  on its `.post(` line. This is a comment-only edit; the call itself is unchanged.
- `.insecure_curlrc` is deleted from the repository (checked in, used by no workflow or script). No spec delta.

Exception statement: the only accepted HTTP write exception is the existing `POST` to
`/compatibility/subjects/{subject}/versions/{version|latest}`. It only checks compatibility and stores nothing. It is
already allowed by the project's read-only rules. This change makes the exception visible to the gate; it adds no
new exception.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `read-only-invariants-enforcement`: new gate requirements for mutating admin and offset-store calls, HTTP write
  methods in Rust, the crate dependency allowlist, and positive/negative regression cases per pattern. The CI
  requirement now also runs the gate's regression test script.

## Impact

- Code: `scripts/check_read_only.sh`, `scripts/test_check_read_only.sh`, `.github/workflows/build.yml` (job
  `read-only-gate`), a one-line comment in `rust/kafkalyzer-kafka/src/schema_registry.rs`, deletion of
  `.insecure_curlrc`. `scripts/build_linux.sh` calls the gate unchanged and inherits the new checks.
- Read-only impact: no new Kafka or Schema Registry calls. No behavior change in the app, no bridge or Dart change.
- Dependencies: none added.
- Prerequisites: none. This change is Phase 0 and is a prerequisite for `mcp-stdio-server` (§5.17).
- Non-goals:
  - TLS verification patterns. TLS enforcement belongs to `restore-tls-verification` (§5.21) and is covered by its
    own unit tests, not by this gate.
  - Scanning the vendored plugin `packages/velopack_flutter`. It legitimately depends on `flutter_rust_bridge` and is
    outside the app workspace.
  - A semantic (AST or type-based) analysis. The gate stays a grep-based check and is not described as a guarantee:
    read-only is enforced by CI gate, crate layering and broker ACLs.
  - Documentation corrections of the "guaranteed read-only" wording (§5.2, done without an OpenSpec change).
