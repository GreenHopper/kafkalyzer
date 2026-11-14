# Design

## Context

See proposal.md (Why) and `specs/tls-verification/spec.md` for the behaviour contract. Observed state of the code:

- `kafkalyzer-kafka/src/kafka_utils.rs::create_config` (line ~149) sets `ssl.endpoint.identification.algorithm=none`
  and `enable.ssl.certificate.verification=false` for every profile. It then sets `ssl.ca.location`/`ssl.ca.pem` from
  the truststore (PEM path, or PKCS#12 converted to PEM; a parse failure is only written to the temp debug log) and,
  when no CA is configured, falls back to `cacert.pem` next to the executable on **every** platform (only the Windows
  release bundles that file, `.github/workflows/build.yml:379`). `create_config` returns `ClientConfig` and has no
  tests. `rdkafka-sys =4.7.0` (librdkafka 2.3.x) already defaults to verification on, so the bypass lines are the
  only thing disabling it.
- The Schema Registry is reached through two duplicated `reqwest::Client::builder()` blocks:
  `schema_registry.rs::build_schema_registry_client` and `kafka_consumer.rs::create_sr_settings` (decoder path via
  `schema_registry_converter`). Neither disables verification; `reqwest` uses its default `native-tls` backend
  (SChannel on Windows, Security.framework on macOS, OpenSSL on Linux), so the registry is already verified today.
- `ClusterProfile` exists twice: domain type in `kafkalyzer-core/src/kafka_types.rs` (plain serde) and the bridge
  DTO in `rust/src/api/kafka_types.rs` with `#[serde(rename_all = "camelCase", default)]`. Profiles are persisted
  as the DTO's serde JSON (`serialize_cluster_profile`/`deserialize_cluster_profile`), but Dart rebuilds profiles
  field by field in `ClusterService` (`sanitized`, `withSecrets`, `copyWith`), so a new field is silently dropped
  unless those helpers carry it.
- `ClusterService.loadClusters` already runs a one-time migration guarded by the prefs flag
  `credentials_migrated_to_keyring_v1`; `ActiveConnectionController.connect` validates via `validateConnection`
  (skipped when topics are cached for the session).
- Platform OpenSSL differs: Windows links vcpkg OpenSSL, macOS uses `openssl`/`ssl-vendored` (compiled-in default
  CA paths that may not exist on user machines), Linux uses the system OpenSSL.

## Goals / Non-Goals

**Goals:**
- One place decides the TLS policy for Kafka (`create_config`) and one for the Schema Registry (a shared client
  builder); both read the same profile flag.
- The persisted per-profile state distinguishes "never reviewed" from "enabled" so legacy and imported profiles are
  detectable without a global list of names.
- Regression protection through Rust unit tests on `create_config` and the registry client.
- Windows/macOS trust-anchor handling decided from spike evidence, not assumed.

**Non-Goals:**
- Staged diagnostics, debug-log cleanup, gate patterns, unique profile names (see proposal Non-Goals).
- Changing the PKCS#12 truststore parsing beyond what verification needs.
- Showing the undecided state in the UI (it behaves exactly like "enabled" for connections).

## Decisions

### D1 — Persisted state: enum on the bridge DTO, boolean in the domain

Bridge DTO `ClusterProfile` gains `tls_verification: TlsVerification` with
`enum TlsVerification { #[default] Unreviewed, Enabled, Disabled }` and `#[serde(rename_all = "camelCase")]`
(stored as `"tlsVerification": "enabled"`). Profiles stored before this change have no key and deserialize as
`Unreviewed` via the existing struct-level `default`. The domain `ClusterProfile` in `kafkalyzer-core` gains only
`ssl_verification_disabled: bool`; `to_domain()` maps `Disabled → true`, everything else → `false`.

- Why: the I/O crate can never see "unreviewed" and so cannot accidentally treat it as insecure; the lifecycle state
  travels with export/import, so an old exported bundle re-enters the transition (spec scenario "Imported profile").
- frb generates a non-`Option` enum field as a `required` Dart constructor parameter, which forces every
  construction site (dialog, `ClusterService` helpers, tests) to choose a value — intended.
- Alternatives: `Option<bool>` (opaque tri-state, `null` easily produced by forgetting the field); a separate
  prefs list of reviewed profile names (breaks on rename/import, A7); a single global flag (cannot express the
  per-profile deferral of E13).

### D2 — `create_config` sets both keys explicitly from the flag

Remove the two bypass lines. Always set `enable.ssl.certificate.verification` (`true`/`false`) and
`ssl.endpoint.identification.algorithm` (`https`/`none`) from `profile.ssl_verification_disabled`, so the test can
assert the effective values instead of relying on librdkafka defaults. The effective security protocol logic
(explicit protocol, else `SASL_SSL` when a SASL user is set, else `PLAINTEXT`) moves into a pure
`kafkalyzer_core` helper reused by the probe (D4) so "is this a TLS profile" has one definition.

### D3 — One Schema Registry client builder

Extract `pub(crate) fn schema_registry_client_builder(profile) -> reqwest::ClientBuilder` in `schema_registry.rs`
holding the existing truststore/identity logic plus, only when `ssl_verification_disabled`,
`danger_accept_invalid_certs(true)` and `danger_accept_invalid_hostnames(true)`. `build_schema_registry_client` and
`create_sr_settings` both use it. Alternative (patch both copies) rejected: two places is how the policy diverges.
Test: a `#[cfg(test)]` HTTPS server on `127.0.0.1` built with the already-present `openssl` crate and a generated
self-signed certificate; a GET fails with verification on and succeeds with the flag set. No new dependency.

### D4 — Read-only probe with classification

New `kafkalyzer_kafka::kafka_metadata::probe_tls_verification(profile) -> TlsProbe` :
- Returns `NoTls` without network I/O for non-TLS profiles (core helper from D2).
- Otherwise clones the profile with `ssl_verification_disabled = false`, creates a `BaseConsumer` with a small
  `ClientContext` that records librdkafka `error`/`log` messages into a bounded buffer (last 20 lines), and calls
  `fetch_metadata(None, 10 s)` — the same single metadata request `validate_connection` makes.
- Success → `Verified`. Failure → pure core function `kafkalyzer_core::tls::classify_tls_failure(&[String])`
  returns `CertificateRejected(message)` when a line matches certificate/hostname verification patterns
  (e.g. `certificate verify failed`, `Hostname mismatch`, `self-signed certificate`,
  `unable to get local issuer certificate`) and `Inconclusive(message)` otherwise.
- Classifier lives in `kafkalyzer-core` because it is pure string logic, unit-testable without a broker and will be
  reused by 5.3 `connection-diagnostics`.
- Bridge: `probe_tls_verification(profile: ClusterProfile) -> TlsProbeResult { outcome: TlsProbeOutcome, message:
  Option<String> }` in `rust/src/api/kafka_metadata.rs`; `validate_connection` stays unchanged (L3). Messages are
  librdkafka texts (broker host:port, OpenSSL reason) and contain no credentials.
- Alternative: classify inside Dart from the `validateConnection` exception string — rejected, the exception only
  carries the generic "all brokers down"/timeout error, the SSL reason is only in the error/log callbacks.

### D5 — Transition orchestration in Dart

New `TlsTransitionController` (ChangeNotifier, getIt singleton) in
`lib/src/features/cluster/presentation/controllers/`. It takes the probe function as a constructor parameter
(default: bridge `probeTlsVerification`), so the ten existing `KafkaMetadataService` test fakes stay untouched.

- `runStartupSweep()`: called once after `ClusterListController.loadClusters` completes; skipped when prefs flag
  `tls_verification_transition_v1` is set. Sequentially, for each `unreviewed` profile: `NoTls` → `enabled`;
  `Verified` → `enabled`; `CertificateRejected` → enqueue a decision; `Inconclusive` → leave `unreviewed`. Sets the
  flag after the loop, so a crash mid-sweep re-runs it for still-unreviewed profiles only.
- `resolveBeforeConnect(profile)`: used by `ActiveConnectionController.connect` for `unreviewed` profiles; runs the
  probe (or awaits an in-flight probe for the same profile), applies the same mapping, and for a rejection waits for
  the user's decision. Returns the updated profile, or signals "do not connect" with the verification error.
- Decisions are a FIFO queue of `(profile, message, Completer<TlsVerification?>)`; `MainLayout` listens and shows
  `TlsTransitionDialog` for the head, one at a time. Dismiss → `null` → stays `unreviewed`.
- Persistence through `ClusterListController.updateCluster` after looking the profile up by name at write time; if it
  was deleted or renamed meanwhile, the result is dropped.
- After any successful `validateConnection` of an `unreviewed` profile (probe was inconclusive but the verified
  connect worked) the controller marks it `enabled`.
- Headless script runs never call the controller: `unreviewed` connects with verification and the state is unchanged.
- Alternative: run the sweep inside `ClusterService.loadClusters` like the keyring migration — rejected, it would
  block profile loading on network timeouts and the service has no way to show dialogs.

### D6 — UI

- Shared `InsecureTlsBadge` widget (icon + localized label + tooltip + semantics label; colours from
  `colorScheme.errorContainer`/`onErrorContainer`) used in the Settings cluster tile, the `ClusterConfigDialog`
  header (next to `ReadOnlySecurityBadge`) and `_buildTabItemContent` in `explorer_view.dart` (next to
  `record.profile.name`).
- `ClusterSslForm` gets a switch "Disable certificate and hostname verification (insecure)" plus inline warning,
  shown only for `SSL`/`SASL_SSL`. `ClusterConfigDialog` maps it: on → `disabled`; off → `enabled`, except that an
  untouched `unreviewed` profile keeps `unreviewed`. New profiles start `enabled`. "Test Connection" uses the
  candidate's value.
- All widgets from `package:material_ui/material_ui.dart`; all strings via `AppLocalizations` (en + de).

### D7 — Trust anchors on Windows/macOS: conditional on the spike

Today the `cacert.pem` fallback shadows any OS store (librdkafka only consults `ssl.ca.certificate.stores` on Windows
when `ssl.ca.location` is unset). Decision rule, applied after spike task 1:
- If librdkafka on Windows verifies a public-CA broker using the Windows Root store with `ssl.ca.location` unset →
  stop setting the bundled CA on Windows by default (corporate CAs in the Windows store then work); keep the bundle
  only as the fallback when the store yields no certificates.
- If not → keep the bundled `cacert.pem` fallback, restricted to `cfg(windows)`, and document that private CAs need a
  truststore.
- macOS (vendored OpenSSL): if verification without truststore fails against a public CA, set
  `ssl.ca.location=probe` when no CA is configured.
- Schema Registry: no bundle unless the spike shows `native-tls` cannot verify with the OS store.
The README section is written from the result.

### D8 — Regression tests instead of gate patterns

`#[cfg(test)]` tests in `kafka_utils.rs`: default/`SSL`/`SASL_SSL` profiles yield `true`/`https`; only
`ssl_verification_disabled = true` yields `false`/`none`; a profile with truststore still verifies. Bridge tests:
legacy JSON → `Unreviewed`, round trip keeps `tlsVerification`, `to_domain` maps only `Disabled` to `true`.
The gate is owned by `harden-read-only-gate` and is not changed here.

## Risks / Trade-offs

- [Clusters with a private CA that is not installed fail after the upgrade] → transition dialog names the error and
  offers the explicit, flagged opt-out; README explains how to configure a truststore.
- [Classifier misses a platform-specific verification message] → result is `Inconclusive`: profile stays
  `unreviewed`, connects only with verification and shows the raw error (fails safe). Spike captures real strings on
  all three platforms as test fixtures.
- [Classifier labels a non-certificate TLS failure as rejected] → dialog shows the raw message; disabling does not
  make an insecure connection succeed silently, the profile is flagged either way.
- [macOS vendored OpenSSL has no usable default CA path] → covered by the spike and D7.
- [Profile names are not unique (A7)] → lookup by name updates the first match; same limitation as all existing
  profile operations, fixed by 5.22.
- [Startup sweep costs up to 10 s per unreachable profile] → runs in the background, sequentially, once.
- [Registry now honours the opt-out and accepts invalid certificates for insecure profiles] → intended by the
  roadmap (same setting for both); only for profiles visibly flagged insecure.
- [A6 debug log still written by `create_config`] → unchanged here, owned by 5.25; no new log content.

## Migration Plan

1. Deploy: stored profiles load as `unreviewed`; the sweep runs on first start; non-TLS profiles become `enabled`
   silently.
2. Rollback to an older build: the old DTO ignores the unknown `tlsVerification` key (no `deny_unknown_fields`) and
   loads; on re-save the key is dropped, so a later upgrade treats profiles as `unreviewed` again and resolves them
   at their next connect (the prefs flag prevents a second startup sweep). Verification is off again in the old build
   — inherent to rolling back.

## Open Questions

1. **Windows CA spike** (task 1): Why do Windows debug runs need `cacert.pem` although verification is disabled
   today (hypothesis: librdkafka/OpenSSL fails building the SSL context or loading CA defaults, independent of
   verification)? Does librdkafka 2.3 with vcpkg OpenSSL load the Windows Root store when `ssl.ca.location` is unset?
   Does the `reqwest`/`native-tls` registry client verify against the Windows store without a bundle? Same check for
   the macOS vendored OpenSSL default paths. Outcome selects the D7 branch; specs and tasks stay the same.
2. **Exact librdkafka verification messages** per platform (chain failure, hostname mismatch, expired) for the
   classifier fixtures — captured during the spike.
