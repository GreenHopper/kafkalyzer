# Proposal

## Why

Every Kafka connection kafkalyzer opens today skips TLS certificate and hostname verification:
`create_config` unconditionally sets `enable.ssl.certificate.verification=false` and
`ssl.endpoint.identification.algorithm=none` (left over as "TEMPORARY DEBUG" / "BYPASS"). A configured truststore
therefore protects nothing, and the UI never says so. This is finding A1 of
`design/kafkalyzer_verbesserungskonzept_und_roadmap.md` (§2.4), implemented according to decision E13 (§3) as change
5.21 `restore-tls-verification` — the highest-priority item of the roadmap (§6.3 rule 1) and a prerequisite for
5.3 `connection-diagnostics`.

Simply switching verification back on would silently break users whose clusters use a private CA that is not
distributed to their machine; keeping it off silently continues the insecure state. E13 resolves this with a
one-time, per-profile transition.

## What Changes

- Kafka connections of TLS profiles (`SSL`, `SASL_SSL`) verify the certificate chain and the hostname by default.
- A cluster profile gains an explicit, persisted TLS verification state: *unreviewed* (stored before this change),
  *enabled*, or *disabled*. Verification can only be turned off through an explicit per-profile option in the
  cluster dialog; no code path, setting or environment switch disables it globally. Unreviewed profiles connect
  **with** verification.
- The Schema Registry HTTP client follows the same per-profile setting (today it already verifies; it will accept
  invalid certificates/hostnames only for a profile with verification explicitly disabled).
- Profiles with disabled verification are flagged "insecure" in the Settings cluster list, in the cluster dialog
  and on every open Explorer tab of that profile.
- **Upgrade transition (E13):** on the first start after the upgrade the app tests every existing TLS profile with
  verification. Success → verification enabled. Certificate/hostname rejection → a per-profile transition dialog
  names the error and offers "keep verification on (fix the profile)" or "disable verification explicitly" (then
  flagged insecure). Unreachable or otherwise inconclusive → decision deferred to the next connect; until then no
  connection is made without verification. The decision is taken once per profile and persisted.
- New read-only bridge function that probes a profile with verification forced on and classifies the outcome
  (verified / certificate rejected / inconclusive).
- Rust unit tests pin `create_config`: verification on by default, off only when the profile flag is set.
- Windows CA spike first: clarify why Windows debug runs need `cacert.pem` although verification is off today,
  whether librdkafka on Windows can use the system certificate store, and whether the Schema Registry client needs
  the same; the bundled-CA fallback is decided from the spike result.
- README: rewrite the "Windows SSL Requirements" section (line 170 states verification fails "even if disabled") and
  document the default, the per-profile opt-out and the upgrade transition.

Not **BREAKING** for stored data: profiles written by older versions load unchanged and enter the transition. It is
a deliberate behaviour change for connections whose broker certificate cannot be verified; those are surfaced by the
transition dialog instead of failing silently.

## Capabilities

### New Capabilities

- `tls-verification`: Certificate and hostname verification for Kafka and Schema Registry connections, the explicit
  per-profile opt-out, the insecure marker on Explorer tabs, and the one-time upgrade transition for existing
  profiles (probe, transition dialog, deferral for unreachable clusters, persistence).

### Modified Capabilities

- `ergonomic-settings-and-cluster-onboarding`: ADDED requirements only — a TLS verification option in the cluster
  configuration dialog (with insecure marker in the dialog) and an insecure badge in the Settings cluster list.
  Existing requirements (protocol/Schema Registry badges, SSL mode selector, connection test) keep their text.

Not modified (checked):
- `read-only-security-guidance` — its requirements cover the read-only README section and ACL guidance, not TLS.
  Only README text changes, handled as a task without a spec delta (roadmap listed it as MOD "documentation").
- `cluster-profile-persistence` — "Complete Cluster Profile Round Trip" already requires every field, including
  the new one, to survive restart and export/import.
- `windows-ci` — the release bundle keeps `cacert.pem`; whether it is still needed is a spike output, and any
  removal would be a follow-up change.

## Impact

- **Rust:** `kafkalyzer-core` (`ClusterProfile` gains `ssl_verification_disabled`; pure classifier for
  certificate-verification errors), `kafkalyzer-kafka` (`create_config`, both Schema Registry `reqwest` client
  builders in `schema_registry.rs` and `kafka_consumer.rs`, new probe), bridge crate `rust/src/api/` (additive
  `tlsVerification` field on the persisted `ClusterProfile` DTO with `serde` default, new probe function and result
  DTO). Generated bridge code and checked-in mocks are regenerated.
- **Dart:** `ClusterService` profile helpers (`sanitized`, `withSecrets`, `copyWith`), `ClusterListController`,
  `ActiveConnectionController.connect`, `KafkaMetadataService` (+ test fakes), cluster config dialog / SSL form,
  Settings cluster list, Explorer tabs, a new transition controller and dialog hosted by the main layout, en + de ARB
  keys, `README.md`.
- **Read-only impact:** no new kind of Kafka or Schema Registry call. The probe issues one broker metadata request
  (the same call `validate_connection` already makes) with verification forced on; no group membership, no commit,
  no Schema Registry request. `scripts/check_read_only.sh` must pass unchanged; no new exception.
- **Dependencies:** none new (`openssl`, `reqwest` with native-tls and `rdkafka` are already in `kafkalyzer-kafka`).
- **Prerequisites:** none. Sibling changes `harden-local-storage-and-imports` (touches `ClusterService.loadClusters`)
  and `harden-read-only-gate` are independent; whichever lands second rebases. Follow-up: 5.3
  `connection-diagnostics` builds on the classifier and the spike result.

## Non-Goals

- Staged connection diagnostics (DNS/TCP/TLS/auth stages) — change 5.3.
- Removing or capping the temp-dir debug log in `create_config` (finding A6) — change 5.25.
- Enforcing "no global disable" through `scripts/check_read_only.sh` patterns — owned by `harden-read-only-gate`;
  this change protects itself with Rust unit tests.
- Unique profile names / import-overwrite confirmation (A7) — change 5.22.
- A global "disable verification" switch, certificate pinning, or a certificate viewer/trust-on-first-use flow.
- Changing the Windows release bundling of `cacert.pem` (`windows-ci`).
