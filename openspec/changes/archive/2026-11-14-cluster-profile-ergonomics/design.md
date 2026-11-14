# Design: cluster-profile-ergonomics

## Context

Motivation: see `proposal.md`. Required behaviour: see the three delta specs. The state below was read in the code,
not executed.

- **Profile model.** `ClusterProfile` exists twice. The domain type is in `kafkalyzer-core/src/kafka_types.rs:6`. The
  bridge DTO is in `rust/src/api/kafka_types.rs:6` with `#[serde(rename_all = "camelCase", default)]` and
  `to_domain()`. Profiles are stored as DTO serde JSON (`serialize_cluster_profile`/`deserialize_cluster_profile` in
  `rust/src/api/json_path.rs:34-40`). Dart rebuilds profiles field by field in `ClusterService` (`sanitized`,
  `withSecrets`, `copyWith`, `cluster_service.dart:120-260`) and in `ClusterConfigDialog._buildCandidateProfile`.
  A new field that one of these misses is lost silently. `importClustersZip` and `exportClustersZip` use `copyWith`.
- **Prerequisites in flight.** `restore-tls-verification` adds `tls_verification` (enum, DTO) /
  `ssl_verification_disabled` (domain), `InsecureTlsBadge`, and a switch in `ClusterSslForm`.
  `harden-local-storage-and-imports` adds `normalizeProfileName`, `existingNames` on `ClusterBasicInfoForm`, the
  import conflict dialog, keyring status and rename-safe secret handling. Both land first, and this design assumes
  their names.
- **`create_config`** (`kafka_utils.rs:149`) builds the base `ClientConfig`. Callers then set read-only consumer keys:
  `group.id`, `enable.auto.commit=false`, `enable.auto.offset.store=false`, `auto.offset.reset`,
  `fetch.wait.max.ms`, `fetch.message.max.bytes`, `queued.min.messages`, `queued.max.messages.kbytes` and
  `enable.partition.eof` (`kafka_consumer.rs:305-329`, `kafka_analyzer.rs:1062-1082`, and `group.id` in
  `kafka_metadata.rs:377,569`). librdkafka is 2.3.0 (`rdkafka-sys =4.7.0`). An unknown key makes client creation
  fail.
- **`KRB5_CONFIG`.** `create_config` calls `std::env::set_var("KRB5_CONFIG", …)` (`kafka_utils.rs:192`). This
  setting is process-wide. Every GSSAPI client in the process, including tabs of other profiles and parallel lag
  queries, uses the path of the most recently created config. librdkafka has no per-client krb5 property. The
  in-process GSSAPI library and the `kinit` subprocess both read the environment. Setting environment variables
  while other threads run is also unsound on some platforms. A real fix needs process isolation, which is out of
  scope. A duplicated profile shares the path and is not affected. Windows (SSPI) ignores it.
- **Sessions (B13, confirmed).** `_saveSessionTabs` (`active_connection_controller.dart:298`) writes
  `_openTopics.map((t) => t.topic.name)` for the active profile only. Tabs of other clusters stay open after a
  cluster switch (`connect` does not clear them), so they leak into the session. `_restoreSessionTabs` (`:312`)
  skips missing topics silently. It also looks up the active tab by topic name only, and each `openTopic` call
  during restore saves again.
- **Disconnect.** `ActiveConnectionController.disconnect()` (`:409`) exists. Only the Settings delete action calls it,
  and it clears all tabs of all clusters. No UI exposes it.
- **No window plugin** in `pubspec.yaml`, so the native window title cannot be set without new platform code.
- **Cluster lists:** Explorer sidebar (`explorer_view.dart:329-427`, `LimitedBox(maxHeight: 200)`), Settings list
  (`settings_view.dart:492-680`), and `ClusterDropdown` (Consumer Lag, Scripts).

## Goals / Non-Goals

**Goals:** one definition each of the allowlist, the bootstrap grammar and the properties parser (Rust core,
unit-tested without a broker). The allowlist is enforced at the last point before librdkafka, whatever the profile's
source. New profile fields cannot be dropped by the Dart helpers. Session handling is keyed by the tab's own cluster.

**Non-Goals:** a generic profile-editing framework, a list editor widget for properties, process-isolated Kerberos,
validating bootstrap values inside `validate_connection` or `create_config` (signatures stay unchanged, L3), and
headless script runs (they keep today's librdkafka error for a malformed bootstrap value).

## Decisions

### D1 Data model: three optional strings on the DTO, one list on the domain type

Bridge DTO `ClusterProfile` gets:

- `environment_label: Option<String>`: trimmed, at most 16 characters (checked in the dialog).
- `environment_color: Option<String>`: a palette key (`red`, `orange`, `yellow`, `green`, `blue`, `purple`, `grey`).
- `extra_properties: Option<String>`: the additional properties as text, one `key=value` per line.

Domain `ClusterProfile` gets only `extra_properties: Vec<(String, String)>`. `to_domain()` fills it with
`kafkalyzer_core::client_properties::parse_lines` and keeps only syntactically valid lines. Validation happens later
(D3). The environment tag stays off the domain type, because no Rust code reads it.

- Old stored JSON has no keys and loads as `None` through the struct-level `default`. Older builds ignore the
  unknown keys and drop them on re-save, which is the same rollback behaviour as `tlsVerification`.
- All Dart sites that rebuild a profile field by field must carry the three fields: `ClusterService.sanitized` (not
  secrets, so kept), `withSecrets`, `copyWith`, and `_buildCandidateProfile`. A Dart test builds a profile with every
  field set and asserts that `sanitized()`, `withSecrets({})` and `copyWith()` keep each non-secret field. This
  catches the next forgotten field as well.
- Alternatives rejected:
  - `Vec<ExtraProperty>`: frb generates `==` on the Dart class with list identity, which breaks profile equality.
    It would also need a row-editor widget.
  - An enum for the colour: an unknown value written by a newer build would fail serde and make the whole stored
    profile unreadable.
  - ARGB int: it does not adapt to the light and dark themes.

### D2 Allowlist in `kafkalyzer-core` (E15)

New module `kafkalyzer_core::client_properties`:

- `parse_lines(text) -> Vec<Line>`: a Java-properties subset. It handles `#`/`!` comments, `=` or `:` as the
  separator, trimming, backslash line continuation, and the escapes `\\`, `\=`, `\:`, `\n`, `\t` and `\uXXXX`. Each
  line yields `Entry { line_no, key, value }` or `Syntax { line_no }`. The client.properties import (D5) uses the
  same parser.
- `ALLOWED: &[AllowedProperty { key, kind }]` with `kind` one of `Int { min, max }`, `Bool`, `Enum(&[&str])`,
  `Text { max_len }` (printable ASCII) and `DebugContexts(&[&str])`. The initial list (librdkafka 2.3 names; the spike
  in task 1 confirms each key and range):

| Group | Keys |
|---|---|
| Identity | `client.id` (Text 255), `client.rack` (Text 255) |
| Socket / connection | `socket.timeout.ms` (10–300000), `socket.connection.setup.timeout.ms` (1000–3600000), `socket.keepalive.enable`, `socket.nagle.disable` (Bool), `socket.send.buffer.bytes`, `socket.receive.buffer.bytes` (0–100000000), `connections.max.idle.ms` (0–2147483647) |
| Address / DNS | `broker.address.family` (`any`/`v4`/`v6`), `broker.address.ttl` (0–86400000), `client.dns.lookup` (`use_all_dns_ips`/`resolve_canonical_bootstrap_servers_only`) |
| Backoff / metadata | `reconnect.backoff.ms` (0–10000; librdkafka requires `<= reconnect.backoff.max.ms`, default 10000), `reconnect.backoff.max.ms` (100–3600000; librdkafka requires `>= reconnect.backoff.ms`, default 100), `retry.backoff.ms`, `retry.backoff.max.ms` (1–300000), `metadata.max.age.ms` (1–86400000), `topic.metadata.refresh.interval.ms` (-1–3600000), `api.version.request.timeout.ms` (1–300000) |
| Fetch (not set by callers) | `fetch.min.bytes` (1–100000000), `fetch.max.bytes` (1000000–2147483135; librdkafka requires `>= message.max.bytes`, default 1000000), `fetch.error.backoff.ms` (0–300000) |
| Debug | `debug`: comma list of `generic`, `broker`, `topic`, `metadata`, `feature`, `queue`, `protocol`, `security`, `fetch`, `consumer`, `cgrp`. `all`, `msg` and `conf` are excluded because they can log payload metadata or configuration values. |

- `validate(text) -> Vec<Issue { line_no, key, kind }>`, where `kind` is `Syntax`, `NotAllowed`, `InvalidValue`
  (with range text) or `Duplicate`.
- `effective(entries) -> Vec<(&str, String)>`: only allowlisted keys with valid values, first occurrence wins.

The list is positive. Nothing outside it can pass, so there is no denylist to maintain (E15). It contains no
`group.*`, `enable.auto.*`, `auto.*`, `transactional.*`, `enable.idempotence`, `acks`, `allow.auto.create.topics`,
`isolation.level`, `ssl.*`, `sasl.*` (including `sasl.kerberos.kinit.cmd`, which runs a command), `security.protocol`,
`bootstrap.servers`, `plugin.library.paths` or `interceptor.*`. It also contains none of the keys the callers set
(Context), so caller settings cannot be overridden.

### D3 Enforcement in `create_config`

At the end of `create_config`: `for (k, v) in effective(&profile.extra_properties) { config.set(k, v) }`. This is the
single choke point for GUI, scripts and the future MCP binary. Unit tests in `kafka_utils.rs`:

- A forbidden sample (`group.id`, `group.instance.id`, `enable.auto.commit`, `transactional.id`,
  `enable.idempotence`, `allow.auto.create.topics`, `enable.ssl.certificate.verification`,
  `ssl.endpoint.identification.algorithm`, `sasl.kerberos.kinit.cmd`, `plugin.library.paths`) is never set, or keeps
  the value `create_config` set itself. Test values must not put `enable.auto.commit` and the literal `"true"` on one
  line, because the read-only gate pattern would match. Use the value `x`: the allowlist rejects by key first.
- An allowed key with a valid value is set. An invalid value is not set.
- Disjointness: no allowlisted key is in the list of keys set by `create_config` or by the callers (constant in the
  test, mirrors Context).
- Spike test (task 1): for each allowlisted key, set its min and max sample and create a `BaseConsumer`. This works
  offline. It proves that librdkafka 2.3.0 knows the key and accepts the range.

Alternative rejected: validating only in the dialog. Stored or imported data would bypass it.

### D4 Bootstrap grammar in `kafkalyzer-core`

New `kafkalyzer_core::bootstrap::parse_bootstrap_servers(&str) -> Result<Vec<HostPort>, Vec<BootstrapIssue>>`.
Entries are split on `,`, trimmed, and empty entries are skipped, but at least one must remain. Each entry is
`host:port` with a bracketed IPv6 address or a host of `[A-Za-z0-9._-]` (no whitespace, no `/`, `@` or `://`) and a
port of 1–65535. Issue kinds: `NoEntries`, `MissingPort`, `InvalidPort`, `InvalidHost`, `SchemeNotAllowed`.
`host.9092` is reported as `MissingPort` with the entry text, so the message can hint at `:`. The parser is in core
because 5.3 `connection-diagnostics` needs the same entries for its DNS/TCP stage in Rust (second caller).

- Dialog: the `ClusterBasicInfoForm` validator calls the sync bridge function (D7) and maps the issue kind to an ARB
  message that names the entry. `_handleTestConnection` already runs `validate()` first.
- Connect: `ActiveConnectionController.connect` validates before setting `_connectingProfile`. On issues it sets
  `_error` to the localized message and returns, so no broker is contacted.

### D5 `client.properties` mapping in `kafkalyzer-core`

`kafkalyzer_core::client_properties::map_client_properties(text) -> ClientPropertiesMapping { fields, extras,
skipped }`. Values of skipped keys are never echoed, because they may be secrets.

| Source key(s) | Target |
|---|---|
| `bootstrap.servers` | bootstrap servers |
| `security.protocol` (uppercased; one of the four) | protocol |
| `sasl.mechanism`, `sasl.mechanisms` | mechanism (`PLAIN`, `SCRAM-SHA-256/512`, `GSSAPI`, `OAUTHBEARER`, `AWS_MSK_IAM`) |
| `sasl.jaas.config` with `PlainLoginModule` / `ScramLoginModule` | `username`, `password` |
| `sasl.jaas.config` with `Krb5LoginModule` | `keyTab`, `principal` (`serviceName` if present) |
| `sasl.username`, `sasl.password`, `sasl.kerberos.service.name/.keytab/.principal` | same fields |
| `ssl.truststore.location/.password`, `ssl.ca.location` | truststore |
| `ssl.keystore.location/.password` | keystore |
| `ssl.certificate.location`, `ssl.key.location`, `ssl.key.password` (only with `ssl.key.location`) | PEM fields |
| `schema.registry.url`, `basic.auth.user.info` / `schema.registry.basic.auth.user.info` (`user:pass`) | Schema Registry |
| `ssl.truststore.type`/`ssl.keystore.type` `PKCS12`/`PEM`, `basic.auth.credentials.source=USER_INFO`, `ssl.endpoint.identification.algorithm=https` | consumed (no field) |
| allowlisted key with a valid value | extras |

Skip reasons: `NotAllowed` (unknown or not allowlisted), `Unsupported` (JKS type or `.jks` path, other JAAS
modules, `ssl.key.password` without a PEM key), `Placeholder` (value contains `${`), `VerificationOverride`
(`ssl.endpoint.identification.algorithm` empty or `none`, `enable.ssl.certificate.verification=false`) and
`InvalidValue`.

The JAAS value is tokenised by hand: the module class, `required`/`optional`, then `k=v` or `k="v"` pairs up to `;`.
No regex is needed. The TLS verification state is never set from the file. It stays with the dialog switch from
`restore-tls-verification`.

Dart reads the file through `file_picker` and refuses files over 1 MiB or with invalid UTF-8. It then calls the
async bridge `parse_client_properties`. A preview dialog lists mapped fields (secrets as `••••`), extras and skipped
keys with reasons. "Apply" writes only mapped non-empty values into the dialog's controllers and appends the extras
to the extras text. Nothing is saved until the user saves the dialog, which then stores the secrets in the keyring
through `ClusterService.saveClusters`. The action exists only in the "add" mode of the dialog.

### D6 Environment tag UI (Dart only)

- `EnvironmentPalette` maps each key to container and on-container colours for light and dark themes. `red` uses
  `colorScheme.errorContainer`/`onErrorContainer`. Unknown keys and `None` use the neutral `grey` entry, and the raw
  stored value is kept until the user picks a colour.
- `EnvironmentTagChip(profile)` shows the label text with a `Semantics` label "Environment: <label>". It is used in
  the sidebar tile, the Settings tile, `ClusterDropdown` items, `_buildTabItemContent` (next to the cluster name,
  alongside `InsecureTlsBadge`) and an `EnvironmentBanner` above the Explorer tab bar for the active profile.
- Tabs and the banner resolve the profile by name from `ClusterListController` at build time (fall back to
  `record.profile`). An edit is then visible without reopening, as the spec requires.
- Dialog: an `Autocomplete` label field (suggestions DEV, TEST, STAGE, PROD; picking one preselects green, blue,
  orange or red unless the user already picked a colour) plus a row of `ChoiceChip`s with colour dot and name.
- Alternative rejected: an app-wide banner in `MainLayout`. Consumer Lag and Scripts select their own cluster, so a
  global banner would show the wrong environment there. Those views get the chip in their dropdown instead.

### D7 Bridge surface

New module `rust/src/api/profile_tools.rs` (registered in `api/mod.rs`):

- `#[frb(sync)] validate_bootstrap_servers(value: String) -> Vec<BootstrapServerIssue { entry, kind }>`
- `#[frb(sync)] validate_extra_properties(text: String) -> Vec<ExtraPropertyIssue { line, key, kind, allowed }>`
- `#[frb(sync)] allowed_extra_properties() -> Vec<AllowedExtraProperty { key, value_hint }>`
- `parse_client_properties(content: String) -> ClientPropertiesPreview { profile: ClusterProfile, extra_properties:
  String, skipped: Vec<SkippedProperty { key, reason }> }`

These are local DTOs with enums for the kinds, mapped from the core types (L3). Form validators must be synchronous,
which is why the first three are sync. They are pure and microsecond-cheap, and never run per message. Dart wraps
them in a small `ClusterProfileTools` service registered in `getIt`, so widget tests can register a fake instead of
mocking the bridge. Existing functions keep their signatures.

### D8 Sessions keyed by the tab's cluster (B13)

- `_saveSessionTabs(String clusterName)` writes the tabs with `profile.name == clusterName`. The active topic is the
  active tab if it belongs to that cluster. Otherwise it is the cluster's last active tab, tracked in an in-memory
  `Map<String, String> _lastActiveTopicByCluster`.
- Callers pass the affected cluster. `openTopic` passes `p.name`. `closeTopicTab` and `setActiveTabId` read the
  record's profile before removal. `clearOpenTopics` saves for each cluster that had tabs.
- Restore runs with a `_restoring` flag that suppresses saves. It collects topic names missing from the topic list
  and then saves once (spec: the session afterwards holds only the restored tabs). It exposes
  `unrestoredTopics` (cluster and names). `ExplorerView` shows a SnackBar once per restore and acknowledges it. The
  active tab lookup matches topic and profile.
- Guard: if `TopicController.getTopics(profile)` is `null` (a failed fetch leaves no cache entry today, see
  `topic_controller.dart:27-33`; `fix-result-view-defects` may add an explicit error state that must be treated the
  same way), restore is skipped entirely. The session is neither reported nor rewritten, because a failed fetch must
  not look like "all topics gone".
- `disconnect()` never saves, so the session survives (spec scenario).

### D9 Disconnect

`disconnect()` becomes cluster-scoped. It disposes the controllers of the active cluster's tabs, removes those tabs,
calls `TopicController.clearCache(profile)` (so the cached check mark disappears and the next connect revalidates),
clears the active profile, filter and error, and does not touch other clusters' tabs. `hasRunningOperations(name)`
backs the confirmation dialog (new ARB texts; same `AlertDialog` pattern as `confirmCloseTab`). The Settings delete
flow keeps calling `disconnect()` and now leaves other clusters' tabs open. The sidebar shows an `IconButton`
(`Icons.link_off`, tooltip and semantics "Disconnect") as the trailing widget of the active, non-connecting tile.

### D10 Duplicate and filter

- `suggestCopyName(name, existing)` (pure Dart, uses `normalizeProfileName` from the prerequisite) returns
  "<name> (copy)", then "(copy 2)" and so on. `ClusterConfigDialog` gets `isDuplicate`: the title is "Duplicate
  cluster", the button is "Add", and the uniqueness check treats the dialog as a new profile. The result goes to
  `addCluster`, so `saveClusters` writes the secrets under the new name. `tlsVerification` is copied unchanged (an
  `unreviewed` source stays `unreviewed`). Sessions, recent topics and saved searches are not copied.
- `matchesClusterFilter(profile, query)` (pure Dart) does a case-insensitive substring match on name, label and
  bootstrap servers. A `ClusterFilterField` is used in Settings (always) and in the sidebar (more than five
  profiles). Filter state is local widget state. This is view logic with no second caller, so it stays in Dart.

### Layer summary

| Logic | Layer | Why |
|---|---|---|
| Allowlist, value checks, properties parser, client.properties mapping, bootstrap grammar | `kafkalyzer-core` | Pure. Shared by `create_config`, the dialog and 5.3/MCP. |
| Applying extras | `kafkalyzer-kafka::create_config` | Last point before librdkafka |
| DTO fields, sync validators, preview DTO | bridge `rust/src/api` | L3 |
| Palette, chips, banner, filter, duplicate naming, sessions, disconnect, file reading | Dart | View state and UI |

## Risks / Trade-offs

- **[BREAKING] Stored bootstrap entries without a port, or with a `PROTOCOL://` prefix (librdkafka accepted both),
  no longer connect.** → The error names the entry and asks for an edit. The fix is one edit per profile and is
  called out in the proposal.
- **[An allowlisted key or range is wrong for librdkafka 2.3.0]** → The spike test creates a real client per key
  and range. Keys that fail are removed from the list before the UI is built.
- **[The `debug` property produces output nobody sees]** → librdkafka logs go through the Rust `log` facade. Until
  5.25 routes them into the app log, `debug` has no visible effect. The contexts are restricted to ones without
  payload or configuration content.
- **[`KRB5_CONFIG` stays process-wide]** → Documented (Context). Not made worse: duplicate copies the same path.
- **[A forgotten field in a Dart rebuild site drops data]** → Round-trip test over every field (D1).
- **[Restore after a failed topic fetch]** → Guard in D8. Nothing is reported or rewritten.
- **[Topics hidden by missing ACLs look like deleted ones in the restore report]** → The message says "no longer
  in the topic list (deleted or not visible)" and does not claim deletion.
- **[A colour palette that relies on hue]** → The chip always carries the text label, and the banner shows label and
  cluster name.
- **[Disconnect now leaves other clusters' tabs open, including after a delete from Settings]** → Intended. Those
  tabs use their own profile snapshot and keep working as they do after a cluster switch today.

## Migration Plan

No data migration. The new DTO keys are optional and absent in old data. Rollback to an older build drops the
three keys on the next save, so tags and extras are lost and the profiles still load. Sessions keep their storage key
and format. Mixed sessions written by older builds are corrected on the next tab change of each cluster.

## Open Questions

- Final allowlist ranges for `fetch.max.bytes` and the existence of `retry.backoff.max.ms` in librdkafka 2.3.0 are
  answered by the spike test (task 1). Either outcome only removes or narrows an entry.
