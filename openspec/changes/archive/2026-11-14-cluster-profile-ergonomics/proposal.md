# Proposal: cluster-profile-ergonomics

Source: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md`, §5.26 (change id `cluster-profile-ergonomics`),
decision E15, finding B13 (§2.4) and gap "Profile" (§2.4 C), under the guardrails L1, L2, L3 and L5 (§1).

## Why

Mixing up DEV and PROD is expensive even for a read-only tool, because it leads to a wrong diagnosis. Today a cluster
profile can only be created, edited and deleted. Nothing marks its environment. There is no way to copy a profile,
filter the list or disconnect. Bootstrap typos only show up as a librdkafka timeout. Existing `client.properties`
files cannot be reused, and connection tuning (timeouts, `client.id`, address family) is impossible. Finding B13
(verified in `active_connection_controller.dart:298-310`): the tab session saved for the active cluster contains the
open tabs of every cluster.

## What Changes

- **Duplicate profile:** a "Duplicate" action in the Settings cluster list opens the cluster dialog with a copy of
  the profile under a unique suggested name ("<name> (copy)"). The copy includes all secrets. On save, the secrets
  are written to the keyring under the new name. The source profile and its keyring entries stay unchanged.
- **Environment tag:** a profile can carry an optional environment label (free text, suggestions DEV/TEST/STAGE/PROD)
  and a colour from a fixed palette. The tag is shown as a labelled chip, not by colour alone. It appears on the
  Explorer sidebar cluster tile, the Settings cluster tile, the cluster dropdowns of Consumer Lag and Scripts, every
  Explorer tab of that profile, and as a banner at the top of the Explorer for the active cluster.
- **Cluster list filter:** a text filter (name, environment label, bootstrap servers) for the Settings cluster list
  and the Explorer sidebar cluster list. In the sidebar it is shown when more than five profiles exist.
- **Disconnect:** the active cluster in the Explorer sidebar gets a "Disconnect" action. It closes only that
  cluster's tabs and asks for confirmation if a search or analysis is running. The saved tab session of the cluster is
  kept.
- **Bootstrap validation:** every comma-separated bootstrap entry must be `host:port` (hostname, IPv4 or bracketed
  IPv6, port 1–65535). The check runs in the cluster dialog (Save and Test Connection) and again before `connect`.
  An invalid stored profile fails with a message that names the entry, and no broker is contacted.
  **BREAKING** for stored profiles whose entries have no port (librdkafka defaults to 9092 today) or carry a
  `PROTOCOL://` prefix: they must be edited once.
- **Prefill from `client.properties`:** the dialog for a new profile can read a Kafka `client.properties` file. Known
  keys are mapped (`bootstrap.servers`, `security.protocol`, `sasl.mechanism`, `sasl.jaas.config` for PLAIN/SCRAM
  username/password and Kerberos keytab/principal, `sasl.*`/`ssl.*` locations and passwords, `schema.registry.url`,
  `basic.auth.user.info`). Allowlisted client properties become extra properties. All other keys are listed and not
  applied. This includes values with `${…}` config-provider placeholders and attempts to disable hostname verification.
  The form is only prefilled. Secrets are stored in the keyring when the user saves, and the file itself is not
  copied or stored.
- **Allowlisted extra properties (E15):** a profile can carry additional librdkafka properties as `key=value` lines.
  Only keys in a positive allowlist in `kafkalyzer-core` are accepted: connection and socket timeouts, `client.id`,
  `client.rack`, address family and DNS lookup, reconnect/retry backoff, metadata refresh, fetch tuning not set by the
  consumers, and the debug contexts that log no payload or configuration. Each value is checked against its type and
  range. The dialog rejects any other key. `create_config` applies only entries that pass the same check, so keys
  that could write, commit, join a group, enable transactions or idempotence, auto-create topics, execute commands,
  load plugins, or change TLS/SASL settings cannot reach librdkafka.
- **Per-cluster tab sessions (B13):** the session of a cluster contains only that cluster's tabs. A change to a tab
  of a non-active cluster updates that cluster's session. Tabs whose topic no longer exists or is not visible are
  reported after restore ("2 tabs could not be restored: a, b") and are not silently dropped.

Read-only impact: **no new Kafka or Schema Registry calls.** Extra properties only reach librdkafka through a
positive allowlist that has no write-, commit-, group-, transaction- or TLS-relevant key, and Rust unit tests pin
that list. `scripts/check_read_only.sh` must pass unchanged. No exception is requested.

## Capabilities

### New Capabilities

None. The roadmap assigns all requirements to existing capabilities.

### Modified Capabilities

- `ergonomic-settings-and-cluster-onboarding`: ADDED environment tag in the dialog, environment tag visible wherever
  a cluster is shown, filterable cluster lists, disconnect action, bootstrap server validation, prefill from
  `client.properties`, additional-properties editor.
- `cluster-profile-persistence`: ADDED duplicate profile including secrets (action and keyring behaviour); ADDED
  allowlisted additional client properties (what reaches the Kafka client). New fields need no delta for persistence: *Complete Cluster Profile Round Trip* already requires
  every field to survive restart and export/import.
- `topic-search-tabs`: MODIFIED *Tab Session State Persistence and Restoration*. The existing text already requires
  sessions "per cluster", so the B13 mixing is a fix. The change adds scenarios for filtering by cluster, for
  reporting (then dropping) tabs that cannot be restored and for keeping the session on disconnect.

## Impact

- **Rust:** `kafkalyzer-core`: new pure modules for the extra-property allowlist and validation, the bootstrap
  parser (also intended for the stage-1 probe of 5.3 `connection-diagnostics`), and the `client.properties` parser
  and mapper. The domain `ClusterProfile` gets an additive `extra_properties` field. `kafkalyzer-kafka`:
  `create_config` applies the allowlisted extras. Bridge `rust/src/api/`: the DTO `ClusterProfile` gets
  `environment_label`, `environment_color` and `extra_properties` (`Option<String>`, serde default), plus sync
  validation functions and an async `parse_client_properties`. Existing signatures stay unchanged (L3).
- **Dart:** `ClusterService` helpers (`sanitized`, `withSecrets`, `copyWith`), `ClusterListController`,
  `ActiveConnectionController` (sessions, disconnect, bootstrap guard), cluster config dialog and forms,
  `settings_view.dart`, `explorer_view.dart`, `cluster_dropdown.dart`, new shared widgets (environment chip,
  filter field), en + de ARB, regenerated bridge code and mocks.
- **Dependencies:** none new.
- **Prerequisites (implemented first):** `harden-local-storage-and-imports` (unique names via
  `normalizeProfileName`, rename keeps secrets, import conflict dialog, keyring status) and `restore-tls-verification`
  (`tlsVerification` DTO field, insecure marker, `ClusterSslForm` switch). This change builds on their DTO fields,
  helpers and widgets.
- **Known limitation (documented, not changed):** `create_config` sets `KRB5_CONFIG` process-wide
  (`kafka_utils.rs:192`). Two GSSAPI profiles with different `krb5.conf` paths cannot be used side by side in one
  process. A duplicated Kerberos profile shares the path, so it is unaffected.

## Non-goals

- Several simultaneously active clusters or multiple windows (§7).
- Native OS window title: the app has no window plugin. The roadmap's "Fensterkopf" (window header) is implemented as
  the Explorer header banner. A native title can follow once 5.31 `appearance-window-and-update-settings` adds a
  window plugin.
- Free (denylist-based) librdkafka properties, `sasl.kerberos.kinit.cmd`, `plugin.library.paths`, interceptors, or
  any TLS/SASL override through extra properties (E15).
- Per-profile `krb5.conf` isolation (needs a process model change).
- Migrating name-keyed data (sessions, recent topics, saved searches) on rename or duplicate.
- The TLS "insecure" marker (owned by `restore-tls-verification`; shown next to the environment chip). Connection
  stage diagnostics (5.3). Encrypted export (5.7). Leftover hard-coded strings outside the new UI (5.32).
- Import of Java JKS stores. JKS paths are flagged in the prefill preview as unsupported.
