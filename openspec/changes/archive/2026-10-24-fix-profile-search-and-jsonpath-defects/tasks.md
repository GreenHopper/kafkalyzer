# Tasks

## 1. JSON path resolver in `kafkalyzer-core`

- [x] 1.1 Add `rust/kafkalyzer-core/src/json_path.rs` with path normalization (`/` pointer verbatim, optional leading `$`, dot and `[n]` tokens converted to an RFC 6901 pointer) and `resolve(payload, path) -> Option<String>`, wire it into `lib.rs`, and verify `cargo test --manifest-path rust/Cargo.toml` passes vectors for `a.b.c`, `a.0.b`, `a[0].b`, `$.a.b`, `/a/b/c`, a missing path, a non-JSON payload, and keys containing `/` and `~`
- [x] 1.2 Add `resolve_batch(payloads, paths) -> Vec<Option<String>>` and verify a unit test returns one value per path per payload with `None` for unresolvable entries
- [x] 1.3 Document the accepted grammar in the module's Rust doc comment (including the returned form for objects and arrays) and verify `cargo fmt --check` and `cargo clippy` stay clean on the crate

## 2. Consumer-side filter uses the resolver in `kafkalyzer-kafka`

- [x] 2.1 Replace the `format!("/{}", field)` pointer construction in `matches_filter` (`kafka_consumer.rs:1417`) with the core resolver and verify a unit test where `order.trackingId`, `$.order.trackingId` and `/order/trackingId` select the same records while `order.trackingId` previously selected none
- [x] 2.2 Remove the per-message `Regex::new(term)` fallback and the substring fallback for an uncompilable pattern so only the pre-compiled set from `kafka_consumer.rs:638` is evaluated, and verify a unit test that an uncompilable term surfaces as a setup error instead of matching by substring
- [x] 2.3 Reduce the per-match `log_to_dart` diagnostic (`kafka_consumer.rs:1455`) to topic, partition, offset and matched term, and verify a test that the diagnostic line contains no payload or key bytes for a 200 KB payload
- [x] 2.4 Run `cargo test --manifest-path rust/Cargo.toml` and verify the existing consumer and analyzer tests still pass with the read-only invariants untouched (`BaseConsumer` and `describe_configs` only, no commit, no `subscribe()`)

## 3. Bridge surface in `rust_lib_kafkalyzer` and code generation

- [x] 3.1 Add `resolveJsonPath`, `resolveJsonPathBatch`, and `validateFilterPatterns(terms) -> Vec<String>` to `rust/src/api/` with bridge-local request/response types mapped to core types, and verify `cargo build --manifest-path rust/Cargo.toml` plus a Rust test that `orders[` is reported as invalid
- [x] 3.2 Add `#[serde(rename_all = "camelCase", default)]` to the bridge `ClusterProfile` plus `serializeClusterProfile` / `deserializeClusterProfile`, and verify a Rust round-trip test that writes all 21 fields and that a captured legacy 11-key JSON string deserializes with the missing fields as `None`
- [x] 3.3 Run `flutter_rust_bridge_codegen` with the existing `flutter_rust_bridge.yaml` and verify the regenerated Dart API exposes the new functions and `flutter analyze` reports no errors

## 4. Loss-less cluster profile persistence in Dart

- [x] 4.1 Switch `ClusterService.loadClusters` / `saveClusters` to the bridge serialize/deserialize functions and delete `ClusterProfileExtension.toJson` / `fromJson`, and verify `flutter test test/src/services/cluster_service_test.dart` passes a round trip that keeps Kerberos, OAuthBearer, PEM mTLS and Schema Registry credential values
- [x] 4.2 Add a regression test that loads a stored profile in the old 11-key camelCase shape and verifies the profile is usable, and verify an edit that changes only `bootstrapServers` keeps every other field after save and reload

## 5. Shared path semantics in the Dart UI and scripting

- [x] 5.1 Resolve projected column values in `messages_table_view.dart` through `resolveJsonPathBatch`, called once per message batch at the existing 60 ms append point in `message_stream_controller.dart`, keeping the per-row cache, and verify a Dart test that a 500-message batch with three projected columns produces one resolver call and correct cell values
- [x] 5.2 Replace the path logic in `extraction_utils.dart` and the private `_extractValue` in `script_runner.dart` with the bridge resolver, delete `lib/src/utils/json_path_extractor.dart`, and verify a Dart test where `items[0].sku` extracts the same value as the identically configured projected column
- [x] 5.3 Correct the path hint strings in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` to the accepted grammar and verify `flutter gen-l10n` succeeds, both files keep identical key counts, and the German hint renders in the extraction input

## 6. Filter pattern validation feedback

- [x] 6.1 Validate regex filter terms through `validateFilterPatterns` on scan start and debounced on change, and show a localized inline error at the input with `material_ui` widgets, and verify a widget test that entering `orders[` blocks the scan, shows the error, and starts the scan after the term is corrected
- [x] 6.2 Mark the collapsed advanced-filter chip as invalid when its pattern is rejected, and verify a widget test that the chip renders the invalid state and clears it once the term is valid

## 7. Integration verification

- [x] 7.1 Run `flutter test` and `cargo test --manifest-path rust/Cargo.toml` and verify both suites pass with no new failures
- [ ] 7.2 Against the `docker-compose.yaml` cluster, verify by observation: a profile using SASL/SSL keeps all settings across an app restart, the same path returns identical values in a projected column and in a field filter, an invalid regex is refused with a visible error, and a high-match scan over large payloads does not flood the log

## Workflow follow-up

- Archive the change with `/opsx-archive` after review, then confirm the four spec files landed in `openspec/specs/` (`cluster-profile-persistence`, `json-path-resolution` created; `topic-consumption`, `message-table-columns` modified).
- Update `design/feature-gap-analysis.md` to mark A1, A2, A3 and A5 as implemented.
