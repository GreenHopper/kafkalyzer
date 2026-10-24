# Proposal

## Why

Four confirmed defects from `design/feature-gap-analysis.md` (§3, A1/A2/A3/A5) corrupt results or throughput during production triage:

1. Saving a cluster profile drops every advanced authentication field (Kerberos, OAuthBearer/MSK, PEM mTLS, Schema Registry credentials), so a configured cluster silently reconnects with fewer settings after each restart.
2. An invalid regular expression in the filter falls back to substring matching inside the core; the scan returns plausible but wrong results with no indication that the pattern was rejected.
3. Every filter match emits a formatted log line containing the full matched payload across the Rust→Dart bridge, scaling linearly with payload size and match count.
4. Field-path extraction exists in four divergent implementations (Dart table projection, Dart script extraction, a private copy inside the script runner, and the Rust `filter_field` which only understands JSON Pointer). None of them accepts the syntax the UI advertises (`JSONPath (e.g. $.id)`), so documented paths resolve to nothing.

Unifying the path resolver now also removes the duplicated semantics that a later headless surface (CLI/MCP, see `design/mcp-server-feasibility.md` §9) would otherwise have to re-implement a third time.

## What Changes

- Cluster profile persistence performs a loss-less round trip for all profile fields, covered by a regression test. Existing stored profiles stay readable; fields that were previously dropped are now retained. No breaking change.
- Filter patterns are validated before a scan starts and on input change. An invalid pattern produces a localized inline error and the scan is refused; the core no longer substitutes substring matching for an uncompilable regex.
- Match diagnostics are reduced to partition, offset and filter term metadata. No payload content is streamed as a log record; the payload remains fully visible in the message table and inspector. No new user-facing setting is introduced.
- One canonical JSON path resolver in `kafkalyzer-core` becomes the single authority for field paths: dot notation (`customer.id`), array indices (`leistungen[0].transportId`), `$.`-prefixed paths and `/`-prefixed JSON Pointer. Message-table projection, script variable extraction and the consumer-side `filter_field` all delegate to it; the two duplicated Dart implementations are deleted.
- Localized hint text for path inputs (`extractionJsonPath`) is corrected to the syntax the resolver actually accepts, in English and German.

Explicitly out of scope: any Kafka write operation (the project is read-only by design), diff/JSON-diff relocation, and the headless CLI/MCP surface.

## Capabilities

### New Capabilities

- `cluster-profile-persistence`: loss-less save and restore of a cluster profile, including security and Schema Registry configuration.
- `json-path-resolution`: one canonical field-path semantics shared by table projection, script variable extraction and server-side message filtering.

### Modified Capabilities

- `topic-consumption`: "Pre-compiled Filter Evaluation" is modified to forbid the silent substring fallback for uncompilable patterns; added requirements for filter-pattern validation feedback and for match diagnostics that never echo payload content.
- `message-table-columns`: "Dynamic Projected Columns in Message Table View" is modified so projected column paths follow the canonical JSON path resolver instead of a table-local parser.

## Impact

**Rust**
- `rust/kafkalyzer-core/src/json_path.rs` (new module + unit tests), `rust/kafkalyzer-core/src/lib.rs`
- `rust/kafkalyzer-kafka/src/kafka_consumer.rs`: `filter_field` resolution, `matches_filter` (no per-message regex compilation, no payload echo in match logging), pre-compilation of patterns
- `rust/src/api/` bridge DTOs for path resolution results and filter validation, then `flutter_rust_bridge_codegen` regeneration (`rust/src/frb_generated*.rs`, `lib/src/rust/api/**`)

**Dart**
- `lib/src/services/cluster_service.dart` (complete profile serialization), `test/src/services/cluster_service_test.dart`
- `lib/src/utils/json_path_extractor.dart` and `lib/src/features/scripting/domain/extraction_utils.dart` and the private `_extractValue` in `lib/src/features/scripting/presentation/controllers/script_runner.dart` (replaced by the resolver)
- `lib/src/ui/messages/views/messages_table_view.dart` (projection uses the resolver), search configuration widgets in `lib/src/features/search/presentation/widgets/topic_search_bar.dart` (inline validation feedback)
- `lib/l10n/app_en.arb` / `lib/l10n/app_de.arb` (path-syntax hint correction, invalid-pattern message)

**Constraints**
- Read-only invariant stays untouched: no producer, no offset commit, no `subscribe()` against foreign consumer groups.
- Bridge boundary types stay declared in `rust_lib_kafkalyzer` (`rust/src/api/`) per the project's orphan rule; the resolver itself lives in `kafkalyzer-core` and is unit-testable without rdkafka.
- No new Dart or Rust dependencies; existing test suites (`flutter test`, `cargo test`) are the verification gate.
