# Tasks

## 1. Spike: librdkafka failure evidence (resolves design Open Questions 1-2)

- [x] 1.1 Confirm the prerequisites are merged: `restore-tls-verification` (`kafkalyzer_core::tls::classify_tls_failure`, protocol helper, capturing `ClientContext`, `schema_registry_client_builder`) and `harden-read-only-gate`. Verify: `grep -rn "classify_tls_failure\|schema_registry_client_builder" rust/` finds both, and `scripts/check_read_only.sh` passes on the base branch.
- [x] 1.2 Write a throw-away example binary (not committed) that creates a `BaseConsumer` from `create_config` with a context printing every `error()` code + reason and every `log()` line, then calls `fetch_metadata(None, 10 s)`. Run it against a temporary local broker (docker, SSL + SASL_SSL listeners with SCRAM and PLAIN, self-signed CA; not committed) for: SSL→PLAINTEXT listener, PLAINTEXT→SSL listener, untrusted CA, hostname mismatch, mTLS client cert rejected, wrong PLAIN password, wrong SCRAM password, unsupported mechanism, SASL→non-SASL listener, user without `DESCRIBE` ACL, closed port, filtered port (iptables DROP). Verify: verbatim codes/lines per case appended to design.md under "Spike results".
- [x] 1.3 Repeat the ambiguous cases from 1.2 with `debug=security,broker` on the probe client; record whether it adds distinguishing lines, whether any line contains a secret, and how long the client drop takes after a failed fetch. Verify: design.md D4 states whether the probe sets `debug` and lists the measured drop time.
- [x] 1.4 From 1.2/1.3 fix the classifier rule table (code/pattern → evidence tag) and trim the D2 hint list to the distinguishable cases; save the captured lines as fixtures under `rust/kafkalyzer-core/tests/fixtures/connection_diagnostics/` (secrets replaced). Verify: design.md D2/D4 updated, fixture files exist.

## 2. kafkalyzer-core

- [x] 2.1 If 5.26 `cluster-profile-ergonomics` is not merged yet, add `kafkalyzer_core::bootstrap::parse_bootstrap_servers` exactly as specified in its design D4 (issue kinds, grammar) with its unit tests; otherwise reuse it unchanged. Verify: `cargo test -p kafkalyzer-core bootstrap` passes.
- [x] 2.2 Add module `connection_diagnostics` with the report types from design D2 (stages, states incl. `NotChecked(reason)`, `NotApplicable`, `Undetermined`, hints, server checks) and the budget constants/`remaining()` helper from D6. Verify: `cargo build -p kafkalyzer-core` succeeds; unit test for `remaining()` at, before and after the deadline.
- [x] 2.3 Implement `redact(text, secrets)` (D7) with tests: password inside a message replaced, several secrets, empty secrets ignored, username and host kept, short secret replaced. Verify: `cargo test -p kafkalyzer-core connection_diagnostics` passes.
- [x] 2.4 Implement the evidence classifier (D4) using the rule table from 1.4 and delegating certificate detection to `tls::classify_tls_failure`; tests run every fixture from 1.4 and assert its tag, plus empty input → no evidence. Verify: `cargo test -p kafkalyzer-core connection_diagnostics` passes.
- [x] 2.5 Implement the pure stage derivation (D3 aggregation + D4 rules + D5 status mapping) taking stage-1 results, metadata outcome + evidence, registry outcome, `uses_tls`/`uses_sasl`, registry configured; tests cover each spec scenario: all ok; PLAINTEXT n/a stages; no server reachable → 2-4 not checked; partly reachable → stage 1 failed and 2-4 run; certificate rejected; protocol mismatch on PLAINTEXT; SASL failure → TLS ok; authorization → metadata failed; timeout without evidence → stage unknown + undetermined; TLS+auth evidence → stage unknown; registry 401/403/500/timeout/unreachable with Kafka ok; budget exhausted → not checked. Verify: `cargo test -p kafkalyzer-core` passes.

## 3. kafkalyzer-kafka

- [x] 3.1 Add module `connection_diagnostics` with the stage-1 probe (D3): parse, then per entry concurrently on `shared_runtime()` `tokio::net::lookup_host` with 5 s timeout and `TcpStream::connect` per address within the step budget, dropping the stream without writing; honour `broker.address.family` from the profile's extra properties if 5.26 is merged. Tests: a `127.0.0.1` listener bound to port 0 → ok; a freshly closed port → refused; `invalid.invalid` → host unknown; malformed entry → no I/O. Verify: `cargo test -p kafkalyzer-kafka connection_diagnostics` passes offline.
- [x] 3.2 Make the 5.21 capturing `ClientContext` reusable (`pub(crate)`) and keep the `RDKafkaErrorCode` of `error()` callbacks; it must not forward lines to `log`. Verify: existing 5.21 probe tests still pass; a unit test calls `error()`/`log()` on the context and reads back code and text.
- [x] 3.3 Implement the stages 2-4 probe (D4): `create_config(&profile)` unchanged, `BaseConsumer` with the capturing context, optional `debug` per 1.3, `fetch_metadata(None, min(10 s, remaining))` in `spawn_blocking`, return outcome + captured lines. Verify: test against an unused local port returns a failed outcome with captured lines within the timeout; `grep -nE "subscribe|assign|commit|store_offset" rust/kafkalyzer-kafka/src/connection_diagnostics.rs` is empty.
- [x] 3.4 Implement the registry probe (D5) with the shared builder, per-request timeout, basic auth, `GET {url}/subjects` (`.send(` line marked `// allow_read_only_exception: Schema Registry GET`) and status/error mapping. Tests with a minimal `tokio` HTTP responder on `127.0.0.1` returning 200, 401 and a delayed answer (timeout); unreachable port. Verify: `cargo test -p kafkalyzer-kafka connection_diagnostics` passes.
- [x] 3.5 Implement `diagnose_connection(profile) -> DiagnosisReport`: one deadline (D6), registry probe concurrently with stages 1-4, stages 2-4 skipped when no server connected, redaction of every raw string with the profile's secrets (D7), core derivation. Test: a profile whose SASL user equals its password (so the client echoes it) against an unused port yields the password in no field of the report; a profile pointing at `192.0.2.1` (TEST-NET, dropped) returns within the total budget. Verify: `cargo test -p kafkalyzer-kafka` passes; `validate_connection` is unchanged (`git diff` shows no change in its body).

## 4. Bridge crate (`rust/src/api/`)

- [x] 4.1 Add `rust/src/api/connection_diagnostics.rs` (register in `mod.rs`) with DTOs mirroring D2 and `From` mappings from the core types, plus `pub fn diagnose_connection(profile: ClusterProfile) -> Result<ConnectionDiagnosis>` mapping via `to_domain()`. Add a mapping unit test for every state, reason and hint variant. Verify: `cargo test -p rust_lib_kafkalyzer` and `cargo clippy --workspace --all-targets` pass.

## 5. Bridge regeneration

- [x] 5.1 Run `flutter_rust_bridge_codegen generate`. Verify: `lib/src/rust/api/connection_diagnostics.dart` exists and exports `diagnoseConnection` and the DTO types.
- [x] 5.2 Run `dart run build_runner build` to regenerate `test/src/rust/api/rust_mocks.mocks.dart`. Verify: command exits 0 and the mock contains `crateApiConnectionDiagnosticsDiagnoseConnection`.

## 6. Dart: service

- [x] 6.1 Add `lib/src/services/connection_diagnostics_service.dart` (`Future<ConnectionDiagnosis> diagnose(ClusterProfile)`) and register it as lazy singleton in `dependency_injection.dart`. Verify: `flutter analyze` reports no errors; existing `KafkaMetadataService` fakes are untouched.

## 7. en + de ARB keys

- [x] 7.1 Add to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`: five stage names, five state labels, not-checked reasons (previous stage failed / time budget), overall lines (success / failed at stage {stage} / stage unknown), one hint text per hint code from the final D2 list, "Generic" hint, per-server labels (DNS, TCP, resolved addresses, connected to {address}), "raw error" label. Verify: `flutter gen-l10n` succeeds and both files contain the same key set.

## 8. Dart: UI

- [x] 8.1 Create `ConnectionDiagnosticsPanel` (design D8): overall line, one row per stage with icon + localized state text + stage name, hint and `SelectableText` raw error, expandable per-server rows for the network stage; colours from `colorScheme`, widgets from `package:material_ui/material_ui.dart`, semantics labels on icons. Verify: widget tests for all-ok, PLAINTEXT with not-applicable stages, failure with hint + raw error, stage unknown (no stage shown as failed), per-server rows.
- [x] 8.2 Rewire `ClusterConfigDialog._handleTestConnection` to call `ConnectionDiagnosticsService` with the candidate profile and render the panel instead of the single status row (remove the hard-coded green/red container); keep spinner, disabled button while running and the `mounted` guard. Verify: `cluster_config_dialog_test.dart` cases with a fake service: success shows the panel, failure keeps dialog open without saving, button disabled while running, closing the dialog during a pending test throws nothing; `ActiveConnectionController` still calls `validateConnection` (existing tests pass).

## 9. Final verification

- [x] 9.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets`, `cargo test --workspace`. Verify: all exit 0 without new warnings.
- [ ] 9.2 `dart format lib test`, `flutter analyze`, `flutter test`. Verify: all exit 0.
- [x] 9.3 `scripts/check_read_only.sh`. Verify: passes without a new exception class.
- [ ] 9.4 Manual run against the spike broker from 1.2: healthy SASL_SSL profile with registry, wrong password, untrusted CA, unreachable host, registry down. Verify: each shows the stage and hint expected by the spec and no secret appears in the dialog; observations noted in the PR description.
