# Design

## Context

See proposal.md (Why) and `specs/connection-diagnostics/spec.md` for the contract. Observed state:

- `kafkalyzer-kafka/src/kafka_metadata.rs::validate_connection` (lines 53-59): `create_config` → `BaseConsumer`
  with `DefaultClientContext` → `fetch_metadata(None, 5 s)` → `Ok(true)`. It never returns `Ok(false)`; the dialog's
  "check returned false" branch is dead. Errors arrive in Dart as one string.
- `ClusterConfigDialog._handleTestConnection` (`cluster_config_dialog.dart:200-236`) validates the form, builds the
  candidate profile and shows one status row with hard-coded `Colors.green`/`Colors.red`.
- rdkafka 0.36.2 / librdkafka 2.3.0 (`rdkafka-sys 4.7.0+2.3.0`). `ClientContext` offers
  `error(&self, KafkaError, reason: &str)` (global errors, `KafkaError::Global(RDKafkaErrorCode)`) and
  `log(&self, level, fac, msg)`. Relevant codes exist in `rdkafka-sys` `types.rs`: `SSL = -181`,
  `Authentication = -169`, `SaslAuthenticationFailed = 58`, `BrokerTransportFailure = -195`, `Resolve = -193`,
  `AllBrokersDown = -187`; `fetch_metadata` itself fails with `KafkaError::MetadataFetch(code)`. Which of these
  librdkafka emits for which misconfiguration is not documented reliably → spike (task 1).
- The Schema Registry client builder (`schema_registry.rs::build_schema_registry_client`) sets no timeout;
  `restore-tls-verification` (D3) replaces it with a shared `schema_registry_client_builder(profile)` that applies
  the verification flag.
- `kafka_consumer.rs` already has `pub(crate) fn shared_runtime() -> &'static Runtime` (tokio, `full` features).
- After `restore-tls-verification`: `create_config` honours `ssl_verification_disabled`; core has
  `kafkalyzer_core::tls::classify_tls_failure(&[String]) -> CertificateRejected(msg) | Inconclusive(msg)` and a pure
  "effective security protocol / uses TLS" helper; `kafka_metadata.rs` has a probe with a `ClientContext` that records
  error/log lines in a bounded buffer (≤ 20).
- Sibling 5.26 plans `kafkalyzer_core::bootstrap::parse_bootstrap_servers(&str) -> Result<Vec<HostPort>,
  Vec<BootstrapIssue>>` (host:port, bracketed IPv6, port 1-65535, no `scheme://`).
- Five Dart test fakes `implements KafkaMetadataService` without `noSuchMethod`.

## Goals / Non-Goals

**Goals:** all decision logic pure and unit-tested in `kafkalyzer-core` from captured fixtures; I/O probes thin;
one result value the UI renders without further interpretation; no change to existing signatures.

**Non-Goals:** progress streaming per stage, reuse by the connect flow or scripts (possible later through the same
bridge function), any change to the 5.21 TLS transition.

## Decisions

### D1 — Layering

| Piece | Layer | Why |
|---|---|---|
| Report types, evidence classifier, stage derivation, redaction, budget arithmetic | `kafkalyzer-core::connection_diagnostics` | Pure; fixture-tested without a broker |
| Bootstrap parsing | `kafkalyzer-core::bootstrap` (5.26 D4) | One grammar for dialog, connect check and stage 1 |
| DNS/TCP probe, librdkafka probe, registry probe, orchestration | `kafkalyzer-kafka::connection_diagnostics` | Network I/O, rdkafka, reqwest (L2) |
| DTOs + `diagnose_connection` | `rust/src/api/connection_diagnostics.rs` | L3, orphan rule; not persisted → no serde |
| Hint texts, rendering | Dart `ConnectionDiagnosticsPanel` + ARB | Localization is Dart-only |

Rust returns hint **codes**, never prose; Dart maps codes to ARB strings. Alternative (English strings from Rust)
rejected: not localizable (L5).

### D2 — Report model (core)

```text
DiagnosisReport { outcome: Ok | Failed | FailedStageUnknown, stages: [StageResult; 5],
                  unattributed: Vec<String> /* raw lines for FailedStageUnknown */, elapsed_ms }
StageResult     { stage: Network|Tls|Authentication|Metadata|SchemaRegistry, state, hint: Option<Hint>,
                  raw: Option<String>, servers: Vec<ServerCheck> /* Network only */ }
ServerCheck     { entry, dns: StepState, addresses: Vec<String>, tcp: StepState, connected_address, hint, raw }
state           = Ok | Failed | NotChecked(reason: PreviousStageFailed | BudgetExhausted) | NotApplicable | Undetermined
Hint            = InvalidEntry | HostUnknown | ConnectionRefused | ConnectTimeout | CertificateRejected
                | TlsHandshakeFailed | ProtocolMismatch | AuthenticationFailed | MechanismRejected
                | NotAuthorized | RequestTimeout | RegistryUnreachable | RegistryUnauthorized
                | RegistryHttpError(status) | Generic
```

`NotApplicable` and `Undetermined` go beyond the roadmap's three states (ok/failed/not checked): "not checked because
a predecessor failed" would be false for a PLAINTEXT profile's TLS stage, and for the unknown-stage case. The final
hint set is trimmed to what the spike can actually distinguish (task 1.4).

### D3 — Stage 1: network probe without librdkafka

- Parse with `parse_bootstrap_servers`; issues → `ServerCheck { dns: Failed, hint: InvalidEntry }`, no I/O.
- Per valid entry, concurrently on `shared_runtime()`: `tokio::net::lookup_host` under `tokio::time::timeout(5 s)`;
  then `TcpStream::connect` to each resolved address in order (librdkafka also tries all), each attempt bounded by
  the remaining 5 s step budget; first success wins, stream dropped immediately (no bytes written).
- Stage state: Ok if every entry is ok; Failed otherwise. Stages 2-4 run when **at least one** entry connected
  (librdkafka would use it); otherwise they are `NotChecked(PreviousStageFailed)`.
- `std::net::ToSocketAddrs` rejected: blocking with no timeout. If 5.26 extras set `broker.address.family=v4|v6`,
  resolved addresses are filtered the same way (else stage 1 could pass on an address librdkafka never uses).

### D4 — Stages 2-4: one metadata request with captured evidence

- Config: `create_config(&profile)` unchanged — the probe sees exactly what a real connect sees, including the
  profile's own verification setting (unlike the 5.21 probe, which forces verification on).
- Context: reuse the 5.21 capturing `ClientContext` (move it to `pub(crate)` in `kafkalyzer-kafka` if it is private),
  extended to keep the `RDKafkaErrorCode` of `error()` callbacks next to the text. It does not forward lines to the
  `log` crate, so nothing unredacted reaches a log.
- `consumer.fetch_metadata(None, min(10 s, remaining budget))`, run via `spawn_blocking`, followed by `consumer.poll(Duration::from_millis(10))` to drain queued `error()` callbacks (spike finding: `BaseConsumer::fetch_metadata` leaves `error()` callbacks on the main event queue until `poll()` runs); the client is dropped afterwards (measured drop time: 0–2 ms). `debug=security,broker` is **not** set on the probe client: all SSL/SASL/protocol-mismatch cases already emit distinguishing `error()` codes/reasons without `debug`, and `debug=security,broker` adds only file-path noise without distinguishing silent packet drops.
- Evidence classifier (core, pure): input = list of `(Option<code>, text)` plus the `MetadataFetch` result; output =
  set of evidence tags `{Tls(CertificateRejected|Handshake|ProtocolMismatch), Auth(Failed|Mechanism),
  Authorization, None}`. Certificate tagging delegates to `tls::classify_tls_failure` (no second pattern list);
  the other rules (code `-181` → TLS, `-169`/`58` → Auth, authorization codes on `MetadataFetch` → metadata,
  protocol-mismatch log texts) are fixed by spike fixtures.
- Derivation (core, pure), with `uses_tls`/`uses_sasl` from the 5.21 protocol helper:
  - metadata ok → TLS ok|n/a, auth ok|n/a, metadata ok.
  - exactly one stage tagged → that stage Failed; earlier stages ok|n/a (auth after TLS implies a completed
    handshake); later stages `NotChecked(PreviousStageFailed)`.
  - zero or several stages tagged → `FailedStageUnknown`, stages 2-4 `Undetermined`, all raw lines kept.
  - ProtocolMismatch on a non-TLS profile still marks the TLS stage Failed (the mismatch *is* the transport
    security question).
- Alternative rejected: parsing the single `validate_connection` error string — it only carries
  `AllBrokersDown`/timeout; the SSL/SASL reason exists only in callbacks (same finding as 5.21 D4).
- Alternative rejected: picking the earliest tagged stage on conflicting evidence — a guess the roadmap forbids.

### D5 — Stage 5: Schema Registry

Only if `schema_registry_url` is non-empty, else `NotApplicable`. Shared builder from 5.21 D3 + per-request
`.timeout(min(10 s, remaining))`, `GET {url}/subjects` with basic auth as in `fetch_subjects`, body discarded.
Runs concurrently with stages 1-4 (independent host) so the worst case stays inside the budget. Mapping: 2xx → Ok;
401/403 → RegistryUnauthorized; other status → RegistryHttpError(status); `reqwest::Error::is_timeout` →
RequestTimeout; connect error whose source chain is classified as certificate by `classify_tls_failure` →
CertificateRejected; other connect errors → RegistryUnreachable. `GET /subjects` chosen over `/config` because it is
the request the app needs anyway and its permission is what matters. The `.send(` line carries the existing
`// allow_read_only_exception` marker.

### D6 — Budget

Constants in core: total 25 s; DNS 5 s; TCP 5 s per entry; metadata 10 s; registry 10 s. A deadline is computed once;
each step uses `min(step, deadline - now)`; a step that would start with ≤ 0 remaining is
`NotChecked(BudgetExhausted)`. Worst case Kafka chain ≈ 20 s, registry in parallel ≤ 10 s. Risk: librdkafka
`destroy` on drop may block briefly while connections close — measured in the spike.

### D7 — Redaction

`redact(text, secrets: &[&str]) -> String` in core replaces every non-empty secret value of the profile (SASL
password, keystore/truststore/PEM key passwords, OAuth token, registry password) with `[redacted]`. Applied by the
kafka crate to every raw string before it enters the report. Value-based on purpose: complements the pattern-based
Dart log redaction of 5.25. Secrets shorter than 4 characters are still replaced (correctness over readability).

### D8 — Bridge and Dart

- Bridge: `pub fn diagnose_connection(profile: ClusterProfile) -> Result<ConnectionDiagnosis>` (frb async by
  default) in new `rust/src/api/connection_diagnostics.rs`, DTO enums/structs mirroring D2 with `From` mappings.
  `Err` only for internal failures (e.g. runtime); every network outcome is data.
- Dart: new `ConnectionDiagnosticsService` (one method, `getIt` lazy singleton) instead of a new method on
  `KafkaMetadataService`, so the five `implements` fakes stay untouched.
- `ClusterConfigDialog`: `_handleTestConnection` calls the service; state = `ConnectionDiagnosis?` + `_isTesting`;
  the button stays disabled while running (existing); `mounted` check discards late results.
  The result area becomes `ConnectionDiagnosticsPanel` (`lib/src/features/cluster/presentation/widgets/config_dialog/`):
  overall line (success / failed at stage X / stage unknown) and one row per stage — icon + localized state label +
  stage name, hint text and `SelectableText` raw error; network row expands to one line per server. Colours from
  `colorScheme` (`primary`/`error`/`outline`), not `Colors.green/red`. Widgets from
  `package:material_ui/material_ui.dart`.
- `validateConnection` and its Dart callers stay as they are.

## Risks / Trade-offs

- [librdkafka emits only generic `AllBrokersDown`/timeouts for some failures] → unknown-stage result with raw lines;
  spike lists which cases end up there; honest rather than precise.
- [Messages differ per platform/OpenSSL build] → fixtures from Linux in CI; Windows/macOS lines captured in the
  5.21 spike are added as fixtures when available; unmatched text falls back to unknown stage.
- [Stage 1 passes but librdkafka fails to resolve or route (e.g. different resolver, advertised listeners)] →
  metadata stage evidence or unknown stage; advertised-listener checks are a non-goal.
- [Firewall/IDS sees an extra TCP connect] → one connect per resolved address, no payload; same hosts the client
  contacts anyway.
- [debug log contexts could reveal configuration] → only `security`/`broker` if the spike needs them, never `conf`;
  every line redacted; lines never forwarded to `log`.
- [Budget ~20 s with a spinner only] → acceptable for a manual test; per-stage streaming is a non-goal.
- [5.26 not merged when this is implemented] → this change creates `bootstrap.rs` exactly per 5.26 D4 (task 2.1).

## Migration Plan

Additive only: new bridge function and DTOs, no persisted data. Rollback = revert; `validate_connection` was never
changed.

## Open Questions

1. Resolved by spike (see "Spike results" below).
2. Resolved by spike: `debug=security,broker` is not set; `consumer.poll(Duration::from_millis(10))` is called after `fetch_metadata` to drain `error()` callbacks.

## Spike results

Captured against temporary local `confluentinc/cp-kafka:7.6.0` (KRaft, `PLAINTEXT`, `SSL`, `SASL_SSL`, `MTLS`, `StandardAuthorizer`):

| Case | `fetch_metadata` | Captured `error()` code + reason | Classifier Tag |
|---|---|---|---|
| SSL → PLAINTEXT | `Err(MetadataFetch(BrokerTransportFailure))` | `-195` `SSL handshake failed: Disconnected: connecting to a PLAINTEXT broker listener?` | `Tls(ProtocolMismatch)` |
| PLAINTEXT → SSL | `Err(MetadataFetch(BrokerTransportFailure))` | `-195` `Disconnected while requesting ApiVersion: might be caused by incorrect security.protocol configuration (connecting to a SSL listener?)` | `Tls(ProtocolMismatch)` |
| Untrusted CA | `Err(MetadataFetch(BrokerTransportFailure))` | `-181` `SSL handshake failed: error:0A000086:SSL routines::certificate verify failed: ...` | `Tls(CertificateRejected)` |
| Hostname mismatch | `Err(MetadataFetch(BrokerTransportFailure))` | `-181` `SSL handshake failed: error:0A000086:SSL routines::certificate verify failed: ...` | `Tls(CertificateRejected)` |
| mTLS client cert rejected | `Err(MetadataFetch(BrokerTransportFailure))` | `-195` `Receive failed: error:0A000416:SSL routines::ssl/tls alert certificate unknown: SSL alert number 46` | `Tls(Handshake)` |
| Wrong PLAIN password | `Err(MetadataFetch(BrokerTransportFailure))` | `-169` `SASL authentication error: Authentication failed: Invalid username or password` | `Auth(Failed)` |
| Wrong SCRAM password | `Err(MetadataFetch(BrokerTransportFailure))` | `-169` `SASL authentication error: Authentication failed during authentication due to invalid credentials with SASL mechanism SCRAM-SHA-256` | `Auth(Failed)` |
| Unsupported mechanism | `Err(MetadataFetch(BrokerTransportFailure))` | `-169` `SASL SCRAM-SHA-512 mechanism handshake failed: Broker: Unsupported SASL mechanism: ...` | `Auth(Mechanism)` |
| SASL → non-SASL listener | `Err(MetadataFetch(BrokerTransportFailure))` | `-169` `SASL PLAIN mechanism handshake failed: Broker: Request not valid in current SASL state: ...` | `Auth(Mechanism)` |
| User without topic DESCRIBE ACL | `Ok(brokers=1, topics=0)` (or `ClusterAuthorizationFailed` / `TopicAuthorizationFailed` on `MetadataFetch`) | none (or authorization error on `MetadataFetch`) | `Authorization` when `MetadataFetch` returns auth error |
| Closed port | `Err(MetadataFetch(BrokerTransportFailure))` | `-195` `Connect to ... failed: Connection refused` (caught in Stage 1) | `None` |
| Filtered port (`192.0.2.1`) | `Err(MetadataFetch(BrokerTransportFailure))` | none (silent timeout) | `None` → `FailedStageUnknown` |

Drop time after failed `fetch_metadata`: `0–2 ms`. No secrets appeared in any `error()` or `debug=security,broker` line.
Fixtures saved under `rust/kafkalyzer-core/tests/fixtures/connection_diagnostics/`.
