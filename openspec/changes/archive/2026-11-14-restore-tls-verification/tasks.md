# Tasks

## 1. Spike: trust anchors on Windows (and macOS) — resolves design Open Questions

- [ ] 1.1 On a Windows debug build of the current code (verification still bypassed), delete `cacert.pem` next to the executable and connect to a TLS broker (temporary local broker with a self-signed CA, not committed); record whether the failure happens at client creation or at the handshake and the verbatim librdkafka error, answering "why do debug runs need `cacert.pem` although verification is off". Verify: findings appended to design.md Open Question 1.
- [ ] 1.2 With the two bypass lines removed locally and `ssl.ca.location` unset, run on Windows with `debug=security` against (a) a public-CA broker and (b) a private-CA broker whose CA is installed in the Windows Root store; record whether librdkafka loads the Windows store (`ssl.ca.certificate.stores`) and verifies both. Verify: result recorded in design.md.
- [ ] 1.3 On Windows, call the Schema Registry client (`fetch_subjects`) against an HTTPS registry whose CA is only in the Windows store, without any bundle; record whether `reqwest`/`native-tls` verifies it. Verify: result recorded in design.md.
- [ ] 1.4 Repeat 1.2 on macOS (vendored OpenSSL, with and without `ssl.ca.location=probe`) and once on Linux as a baseline. Verify: result recorded in design.md.
- [ ] 1.5 Capture verbatim librdkafka error/log lines for untrusted CA, hostname mismatch and expired certificate on each platform as classifier fixtures; choose the D7 branch and rewrite design.md D7 to the chosen behaviour. Verify: design.md D7 states one branch and lists the fixture strings.

## 2. kafkalyzer-core

- [x] 2.1 Add `ssl_verification_disabled: bool` (default `false`) to the domain `ClusterProfile` in `rust/kafkalyzer-core/src/kafka_types.rs` and fix all struct literals in the workspace. Verify: `cargo build --workspace` succeeds.
- [x] 2.2 Add a pure helper returning the effective security protocol of a profile (explicit protocol, else `SASL_SSL` with SASL user, else `PLAINTEXT`) and whether it uses TLS, with unit tests for each branch and case-insensitive `ssl`/`sasl_ssl`. Verify: `cargo test -p kafkalyzer-core` passes.
- [x] 2.3 Add module `kafkalyzer_core::tls` with `classify_tls_failure(lines) -> CertificateRejected(msg) | Inconclusive(msg)`; unit tests use the fixture strings from 1.5 (verification failures → rejected; connection refused, timeout, SASL auth failure, empty input → inconclusive). Verify: `cargo test -p kafkalyzer-core` passes.

## 3. kafkalyzer-kafka

- [x] 3.1 In `create_config` remove the unconditional `ssl.endpoint.identification.algorithm=none` / `enable.ssl.certificate.verification=false`, set both keys explicitly from `ssl_verification_disabled` (`https`/`true` vs `none`/`false`) and use the core protocol helper from 2.2. Verify: `cargo build -p kafkalyzer-kafka` succeeds.
- [x] 3.2 Add `#[cfg(test)]` tests in `kafka_utils.rs`: default, `SSL`, `SASL_SSL` and truststore profiles yield `true`/`https`; only `ssl_verification_disabled = true` yields `false`/`none`. Verify: `cargo test -p kafkalyzer-kafka kafka_utils` passes and fails if a bypass line is re-added (check once locally).
- [x] 3.3 Apply the spike-selected CA fallback (design D7): either keep the `cacert.pem` fallback restricted to `cfg(windows)` or stop shadowing the Windows store; on macOS set `ssl.ca.location=probe` if 1.4 requires it. Extend the 3.2 tests for the non-platform-specific part. Verify: `cargo test -p kafkalyzer-kafka` passes; spike scenario from 1.2/1.4 re-run succeeds on the affected platform.
- [x] 3.4 Extract `schema_registry_client_builder(profile)` in `schema_registry.rs` (existing truststore/identity logic + `danger_accept_invalid_certs`/`danger_accept_invalid_hostnames` only when the flag is set) and use it from both `build_schema_registry_client` and `kafka_consumer.rs::create_sr_settings`. Verify: `grep -n "reqwest::Client::builder" rust/kafkalyzer-kafka/src` shows exactly one occurrence.
- [x] 3.5 Add a `#[cfg(test)]` HTTPS server on `127.0.0.1` with an `openssl`-generated self-signed certificate; assert a GET through the shared builder fails with verification on and succeeds with the flag set. Verify: `cargo test -p kafkalyzer-kafka schema_registry` passes on Linux CI.
- [x] 3.6 Implement `probe_tls_verification(profile) -> TlsProbe { NoTls | Verified | CertificateRejected(msg) | Inconclusive(msg) }` in `kafka_metadata.rs`: no I/O for non-TLS profiles; otherwise force verification on, capture librdkafka error/log lines in a bounded buffer (≤ 20) through a custom `ClientContext`, single `fetch_metadata(None, 10 s)`, classify with 2.3. Unit-test the non-TLS path and the classification wiring without a broker. Verify: `cargo test -p kafkalyzer-kafka` passes and the probe source contains no subscribe/assign/commit calls.

## 4. Bridge crate (`rust/src/api/`)

- [x] 4.1 Add `enum TlsVerification { #[default] Unreviewed, Enabled, Disabled }` (`#[serde(rename_all = "camelCase")]`) and field `tls_verification` to the bridge `ClusterProfile`; map only `Disabled` to `ssl_verification_disabled = true` in `to_domain()`. Verify: `cargo build` in `rust/` succeeds.
- [x] 4.2 Extend the tests in `rust/src/api/json_path.rs`: legacy JSON without the key → `Unreviewed`; full round trip keeps `tlsVerification`; stored value is camelCase; `to_domain` mapping for all three variants. Verify: `cargo test -p rust_lib_kafkalyzer` passes.
- [x] 4.3 Add bridge function `probe_tls_verification(profile) -> TlsProbeResult { outcome: TlsProbeOutcome, message: Option<String> }` in `rust/src/api/kafka_metadata.rs`, leaving `validate_connection` unchanged. Verify: `cargo test --workspace` and `cargo clippy --workspace --all-targets` pass.

## 5. Bridge regeneration

- [x] 5.1 Run `flutter_rust_bridge_codegen generate`. Verify: `lib/src/rust/api/kafka_types.dart` contains `TlsVerification` and a `required tlsVerification` parameter, and `probeTlsVerification` is generated.
- [x] 5.2 Run `dart run build_runner build` to regenerate `test/src/rust/api/rust_mocks.mocks.dart`. Verify: the mock contains `crateApiKafkaMetadataProbeTlsVerification` and the command exits 0.

## 6. Dart: profile persistence

- [x] 6.1 Carry `tlsVerification` through `sanitized`, `withSecrets` and `copyWith` in `lib/src/services/cluster_service.dart`, and pass it in every `ClusterProfile(...)` construction under `lib/` and `test/` (new profiles: `enabled`; test fixtures: `enabled` unless the test needs another value). Verify: `flutter analyze` reports no errors.
- [x] 6.2 Add `ClusterService` tests: a legacy stored profile loads as `unreviewed`; save/load keeps `disabled`; ZIP export/import in `ClusterListController` keeps the value. Verify: `flutter test test/src/services` passes.

## 7. Dart: transition controller and connect flow

- [x] 7.1 Create `TlsTransitionController` (design D5) with injectable probe function, prefs flag `tls_verification_transition_v1`, sequential `runStartupSweep()`, `resolveBeforeConnect()`, in-flight de-duplication per profile, FIFO decision queue, persistence via `ClusterListController.updateCluster` by name lookup; register in `dependency_injection.dart` and start the sweep after clusters are loaded. Verify: unit tests cover NoTls/Verified → `enabled`, Rejected → queued decision, Inconclusive → `unreviewed`, flag set → no second sweep, deleted profile → result dropped.
- [x] 7.2 Integrate into `ActiveConnectionController.connect`: resolve `unreviewed` profiles first; on "keep on" or a still-rejected result show the verification error and do not connect; on `disabled` connect with the updated profile; after a successful verified connect of an `unreviewed` profile mark it `enabled`. Verify: extended `active_connection_controller_test.dart` covers each branch and asserts that `validateConnection` is never called with `disabled` unless the user chose it.
- [x] 7.3 Confirm the headless script runner path does not use the controller and leaves `unreviewed` profiles unchanged. Verify: a `script_runner_test.dart` case with an `unreviewed` profile asserts the stored state is unchanged.

## 8. en + de ARB keys

- [x] 8.1 Add keys to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`: insecure badge label and tooltip, SSL-form switch label and warning, transition dialog title/body (with profile name and error placeholders) and both action labels, "verification failed" connect error. Verify: `flutter gen-l10n` succeeds and both ARB files contain the same key set (the UI tasks in group 9 consume these keys, so this group is done before them).

## 9. Dart: UI

- [x] 9.1 Create `InsecureTlsBadge` (icon + localized label + tooltip + semantics label, `colorScheme.errorContainer`/`onErrorContainer`, `package:material_ui/material_ui.dart`). Verify: widget test finds the label text and the semantics label.
- [x] 9.2 Show the badge in the `SettingsView` cluster tile for `disabled` profiles only. Verify: widget test for `disabled` (badge shown) and `enabled`/`unreviewed` (not shown).
- [x] 9.3 Add the verification switch with warning to `ClusterSslForm` (only for `SSL`/`SASL_SSL`), map it in `ClusterConfigDialog._buildCandidateProfile` per design D6 (new → `enabled`, untouched `unreviewed` stays), and show the badge in the dialog header for `disabled`. Verify: widget tests for hidden-on-PLAINTEXT, new profile saved as `enabled`, toggling to `disabled` and back.
- [x] 9.4 Show the badge in `_buildTabItemContent` of `explorer_view.dart` next to `record.profile.name` for `disabled` profiles. Verify: `explorer_view_test.dart` case asserts the badge on a tab of a `disabled` profile and its absence otherwise.
- [x] 9.5 Create `TlsTransitionDialog` (profile name, verbatim error, "Keep verification on" / "Disable verification (insecure)", dismiss = undecided) and host it in `MainLayout`, showing queued decisions one at a time. Verify: widget tests for both choices, dismissal, and two queued profiles shown sequentially; `main_layout_test.dart` still passes.

## 10. README

- [x] 10.1 Rewrite "⚠️ Windows SSL Requirements" in `README.md` from the spike result (drop the "fails even if disabled" sentence) and add a short "TLS verification" section: on by default, per-profile insecure opt-out with badge, one-time upgrade transition, how to configure a truststore for a private CA. Verify: README contains no claim that verification is disabled and matches design D7.

## 11. Final verification

- [x] 11.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets`, `cargo test --workspace`. Verify: all exit 0 with no new clippy warnings.
- [x] 11.2 `flutter analyze` and `flutter test`. Verify: both exit 0.
- [x] 11.3 `scripts/check_read_only.sh`. Verify: passes unchanged (no new exception).
- [ ] 11.4 Manual check against a TLS broker: legacy profile with untrusted CA shows the transition dialog once; "disable" flags it insecure in list, dialog and tab; restart shows no dialog; an unreachable legacy profile is resolved at the next connect. Verify: observations noted in the change's PR description.
