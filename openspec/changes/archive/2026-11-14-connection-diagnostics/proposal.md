# Proposal

## Why

The "Test Connection" button in the cluster dialog only reports success or the raw text of one librdkafka error
(`validate_connection`, `kafka_metadata.rs:53-59`: one 5 s `fetch_metadata`; the dialog prints
`connectionFailed(e.toString())`). A typo in a hostname, a closed port, an untrusted CA, a wrong SASL password and a
missing ACL all end in the same generic "all brokers down"/timeout text, and TLS/SASL misconfiguration is the most
common hurdle when onboarding a cluster. This is change 5.3 `connection-diagnostics` of
`design/kafkalyzer_verbesserungskonzept_und_roadmap.md` (§5, Phase 1). It builds on 5.21
`restore-tls-verification`: only with verification active does a TLS stage mean anything.

## What Changes

- "Test Connection" in `ClusterConfigDialog` runs a staged diagnosis of the entered (unsaved) profile and shows one
  result per stage:
  1. **Network** — DNS resolution and TCP reachability per bootstrap server, checked without librdkafka
     (tokio, per-step timeout, connection closed without sending bytes).
  2. **TLS** — handshake and certificate verification (profiles using `SSL`/`SASL_SSL`).
  3. **Authentication** — SASL (profiles with a SASL mechanism or user).
  4. **Metadata** — the cluster metadata request (the same single request `validate_connection` issues today).
  5. **Schema Registry** — one read-only `GET /subjects` with timeout, only if a registry URL is configured.
- Each stage reports *ok*, *failed* or *not checked* (an earlier stage it depends on failed, or the time budget ran
  out). Stages a profile does not use are shown as *not applicable*. A failed stage carries a localized hint plus the
  raw error.
- Stages 2–4 are derived only from evidence in librdkafka's error codes and error/log callback lines. Without a clear
  attribution the result is "connection failed, stage unknown" with the raw error, and stages 2–4 are shown as
  *undetermined* — never a guessed stage.
- Secrets of the profile (passwords, key passwords, OAuth token) never appear in results or logs; the diagnosis
  has an overall time budget.
- New bridge function `diagnose_connection(profile)` with report DTOs. `validate_connection` and its callers
  (connect flow, scripts) stay unchanged.
- Pure stage logic (evidence classification, stage derivation, redaction) lives in `kafkalyzer-core` and reuses the
  certificate classifier `kafkalyzer_core::tls::classify_tls_failure` from `restore-tls-verification`.
- Spike first: capture the real librdkafka 2.3.0 error codes and callback lines for SSL vs SASL vs transport
  failures, so the classifier rules and fixtures come from observation.

## Capabilities

### New Capabilities

- `connection-diagnostics`: Staged, read-only diagnosis of a cluster profile (network, TLS, authentication,
  metadata, Schema Registry): stage states and dependencies, evidence-based attribution with the unknown-stage rule,
  localized hints with raw errors, secret redaction and the overall time budget.

### Modified Capabilities

- `ergonomic-settings-and-cluster-onboarding`: MODIFIED *Live Broker Connection Test in Cluster Configuration
  Dialog* — the test shows per-stage results instead of a single success/error message.

Not modified (checked):
- `cluster-connection-progress` — covers the connect flow (`ActiveConnectionController.connect`), which keeps using
  `validate_connection`; nothing changes there.
- `schema-registry-auth`, `enterprise-sasl-auth`, `pem-mtls-config` — the diagnosis uses their existing profile
  fields through the existing config builders; no requirement changes.
- `tls-verification` (added by `restore-tls-verification`) — the diagnosis honours the profile's verification
  setting via `create_config` and the shared registry client builder; its scenario "Connection test uses the entered
  setting" stays true.

## Impact

- **Rust:** `kafkalyzer-core` new module `connection_diagnostics` (types, evidence classifier, stage derivation,
  redaction). `kafkalyzer-kafka` new module `connection_diagnostics` (network probe with tokio, librdkafka probe
  with a capturing `ClientContext`, registry probe). Bridge `rust/src/api/connection_diagnostics.rs` (new function
  and non-persisted DTOs). Generated bridge code and the checked-in mocks are regenerated.
- **Dart:** new `ConnectionDiagnosticsService` (thin bridge facade, registered in `getIt`), new
  `ConnectionDiagnosticsPanel` widget, `ClusterConfigDialog._handleTestConnection` and its result area; en + de ARB
  keys.
- **Read-only impact:** no new kind of Kafka call. Added calls: plain TCP connects to the bootstrap addresses that
  are closed without sending data; one Kafka metadata request (as `validate_connection`); one Schema Registry
  `GET /subjects`. No group membership, assignment, consume, commit or registry write. The registry GET carries the
  existing per-line `allow_read_only_exception` marker convention on `.send(` like every other registry GET;
  `scripts/check_read_only.sh` passes unchanged, no new exception class.
- **Dependencies:** none new (`tokio`, `rdkafka`, `reqwest` are already in `kafkalyzer-kafka`).
- **Prerequisites (implemented first):** `restore-tls-verification` (verification on by default, classifier
  `classify_tls_failure`, the capturing `ClientContext` of its probe, the shared registry client builder, the
  Windows-CA spike — not repeated here). `harden-read-only-gate` (gate patterns the new code must pass).
- **Sibling coordination:** the bootstrap grammar `kafkalyzer_core::bootstrap::parse_bootstrap_servers` is defined
  by 5.26 `cluster-profile-ergonomics` (its D4, naming this change as second caller). Whichever change lands first
  creates the module exactly as specified there; the other reuses it.

## Non-Goals

- Network scanning (port ranges, subnets, other hosts than the configured bootstrap servers and registry URL).
- Kerberos ticket management or `kinit` handling; GSSAPI failures are reported, not repaired.
- Checking advertised broker listeners beyond the bootstrap servers, proxy/SOCKS support.
- Changing `validate_connection`, the connect flow, the startup TLS transition of 5.21, or headless script runs.
- Live per-stage streaming while the test runs (one spinner, then the full report).
- Repeating the Windows-CA spike (done in 5.21); librdkafka `debug` contexts as a profile property (5.26) or an app
  log viewer (5.25).
- A Schema Registry request timeout for the rest of the app (5.35); only the diagnosis request gets one.
