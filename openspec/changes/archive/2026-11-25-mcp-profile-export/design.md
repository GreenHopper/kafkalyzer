# Design

## Context

See `proposal.md` for motivation. Observed state that shapes the approach:

- Every profile save funnels through `ClusterService.saveClusters` (`lib/src/services/cluster_service.dart`): it
  writes secrets to `flutter_secure_storage` (keys `cluster_<name>_<field>`), deletes secrets of removed or renamed
  profiles, then writes secret-free JSON to `shared_preferences`. The profiles passed in carry their secrets in
  memory.
- The bridge DTO `ClusterProfile` (`rust/src/api/kafka_types.rs`) is the persistence format
  (`serialize_cluster_profile` / `deserialize_cluster_profile` in `rust/src/api/json_path.rs`, camelCase, serde
  defaults). `to_domain()` maps it to `kafkalyzer_core::kafka_types::ClusterProfile` (snake_case serde), which is
  what `kafkalyzer-kafka` consumes.
- Dart builds `ClusterProfile(...)` in 186 places across 80 files. A new non-nullable DTO field would become a
  `required` constructor parameter in the generated class and touch all of them.
- All three import paths (JSON, cluster zip, configuration bundle) pass through `mergeImportedProfiles`.
- The six secret fields are fixed in `SecureStorageService.secretFields`.
- The read-only gate rejects `rdkafka`/`reqwest` outside `kafkalyzer-kafka` and `flutter_rust_bridge` outside
  `rust/Cargo.toml`; it does not restrict a new sibling crate.

## Goals / Non-Goals

**Goals:**

- One file format and one keyring access path, written by the app and read by `kafkalyzer-mcp` with the same code.
- One sync call site in Dart; no per-action bookkeeping for rename, delete or import.
- Fail closed: a profile is listed only when its secrets are stored; nothing is shared by default or by import.

**Non-Goals:**

- Reading the shared file from Dart, or showing its content in the UI.
- A migration: nothing is shared before the user opts in, so there is no previous state.
- Locking against a concurrently running second app instance (single-instance use is assumed, as for
  `shared_preferences`).

## Decisions

### D1 — New crate `rust/kafkalyzer-profiles`

Layering as fixed in roadmap §4.2: `kafkalyzer-profiles ← core` (serde, keyring; no rdkafka, no frb). It is added to
the workspace `members` and as a path dependency of the bridge crate. Contents:

- `SharedProfile { profile: kafkalyzer_core::kafka_types::ClusterProfile, environment_label: Option<String>,
  secret_fields: Vec<SecretField> }` and the file envelope `{ "version": 1, "profiles": [...] }`.
- `SecretField` enum with the six secrets and one explicit `take`/`put` pair on the domain profile (no macro).
- `trait SecretStore { set, get, delete }` with a `keyring` implementation and an in-memory implementation for
  tests.
- `default_path()`, `write_shared(path, store, profiles) -> SyncReport`, `read_shared(path, store) ->
  Vec<Result<SharedProfile, ProfileReadError>>`.

Why not `kafkalyzer-core`: file and keyring access are I/O, and core is pure computation. Why not
`kafkalyzer-kafka`: `kafkalyzer-mcp` would work, but the crate is "Kafka and registry I/O" and the roadmap fixes a
separate crate. The pure parts (envelope, secret split) stay in the new crate rather than core because only this
crate uses them — moving them to core has no second caller.

The domain `ClusterProfile` is reused as the stored shape instead of a third profile struct: it already derives
serde and is exactly what `kafkalyzer-kafka` needs. The writer sets every secret field to `None` before
serializing and lists the removed ones in `secret_fields`.

### D2 — File location without a new dependency

`default_path()` resolves `<config dir>/kafkalyzer/shared-profiles.json`:

| Platform | Config dir |
|---|---|
| Linux | `$XDG_CONFIG_HOME` if set and absolute, else `$HOME/.config` |
| macOS | `$HOME/Library/Application Support` |
| Windows | `%APPDATA%` |

About 15 lines over `std::env`, written as a function of an environment lookup so each branch is unit-tested on
every platform. The `dirs` crate does the same and was rejected only because it is a dependency for those lines.
A missing `HOME`/`APPDATA` is an error ("configuration directory unknown"), never a relative fallback.

The file is written to a temporary sibling and renamed over the target, so a reader never sees a half-written
file. On Unix the temporary file is created with mode `0600` and the directory with `0700`.

### D3 — Keyring layout

Service name `kafkalyzer-shared-profiles`; account `<profile name>/<field>` with the snake_case field name (for
example `orders-test/sasl_password`). One entry per secret rather than one JSON blob per profile: Windows
Credential Manager limits a credential blob to 2560 bytes, which a bundle of six secrets reaches sooner than a
single one. A single secret above the limit (long OAuth bearer token) still fails; that profile is reported and
left out (spec scenario "Secret too large for the keyring").

New dependency `keyring` (v3) with features `apple-native`, `windows-native`, `sync-secret-service` and
`crypto-rust`. Justification: it is the only maintained crate covering Keychain, Credential Manager and Secret
Service behind one API; decision E4 names it. `sync-secret-service` links `libdbus`; whether that builds in the
three CI jobs without new system packages is not known (roadmap §8) and is spike task 1.1. Fallback if it does not:
feature `async-secret-service` with `tokio` (pure Rust `zbus`), driven through a blocking call on the bridge
crate's existing runtime.

**Spike results (2026-11-24):**

- Feature set kept: `apple-native`, `windows-native`, `sync-secret-service`, `crypto-rust` (no fallback).
- Linux local: `cargo build -p kafkalyzer-keyring-spike` succeeds with the existing CI apt set (`libgtk-3-dev`
  already pulls `libdbus-1`); no new system package required.
- Linux Secret Service round-trip (write / read / delete) succeeds against a running user session bus.
- No Secret Service (fake `DBUS_SESSION_BUS_ADDRESS`):
  `PlatformFailure(Dbus(D-Bus error: Failed to connect to socket …: No such file or directory
  (org.freedesktop.DBus.Error.FileNotFound)))`.
- macOS / Windows / Linux CI: `cargo build -p kafkalyzer-keyring-spike` passed on all three OS jobs
  with no new system packages.

### D4 — Sync algorithm (`write_shared`)

Input: the profiles that are currently shared, with secrets. Steps:

1. Read the existing file for the previous set of names and their `secret_fields` (unreadable file: log a warning
   and treat as empty — the file is derived data, the app store is the source of truth).
2. For each input profile: write every non-empty secret; delete the entries of fields that are now empty. If any
   write fails, record the profile in `SyncReport.failed` with a reason kind (`KeyringUnavailable`,
   `SecretRejected`) and exclude it from the file.
3. Write the file atomically with the profiles that succeeded.
4. Only after the file is written: delete keyring entries of names that were in the previous file and are not in
   the new one (rename, delete, unshare).

Order matters: secrets first, file second, cleanup last. A crash between steps leaves either unused keyring entries
or the old file with still-valid secrets — never a listed profile without secrets. `SyncReport { written,
failed: Vec<(name, kind)>, file_error: Option<String> }`; error texts name fields, never values.

### D5 — Where the sharing state lives

One additive field on the bridge DTO: `headless_shared: Option<bool>` (`None` and `false` both mean not shared).
`Option` keeps the generated Dart constructor parameter optional, so the 186 existing constructions compile
unchanged; a plain `bool` would be `required`. Stored JSON without the key deserializes to `None` through the
existing serde default.

Alternatives considered:

- A separate preference holding shared names: rename and delete would need their own bookkeeping, and the
  configuration bundle (which exports `preferences.json`) would carry the list to another machine.
- The shared file itself as the source of truth: a rename is indistinguishable from delete-plus-add in
  `saveClusters`, so sharing would silently drop on rename.

Consequences handled explicitly:

- `sanitized()`, `withSecrets()` and `copyWith()` in `cluster_service.dart` list fields by hand; each passes
  `headlessShared` through. A unit test asserts the round trip so a dropped field fails a test.
- `mergeImportedProfiles` clears the field on every imported item before merging (one place for all three import
  paths; covers Replace as well).
- The duplicate action in `settings_cluster_section.dart` clears it on the copy it hands to the dialog.
- The field is not mapped in `to_domain()`; the domain type stays unchanged.

### D6 — Bridge

New file `rust/src/api/headless_profiles.rs`:

- `sync_shared_profiles(request: SharedProfilesSyncRequest) -> SharedProfilesSyncResult` — the request holds
  `profiles: Vec<ClusterProfile>`; the function keeps those with `headless_shared == Some(true)`, maps each with the
  existing `to_domain()` plus `environment_label`, and calls `write_shared(default_path(), keyring store, ..)`.
  Result DTO: `failed: Vec<SharedProfileFailure { name, kind }>`, `file_error: Option<String>`, `file_path`.
- `mcp_server_launch() -> McpServerLaunch { command, leading_args, exists }`:
  - Default: `command` is the directory of `std::env::current_exe()` joined with `kafkalyzer-mcp` (`.exe` on
    Windows; on macOS that is `Contents/MacOS/` inside the bundle), `leading_args` is empty, `exists` reports
    whether the file is there. Change `mcp-stdio-server` installs the binary; until then the dialog says it was
    not found.
  - Linux AppImage (the Velopack package built in `build.yml`): `current_exe()` lies inside a temporary mount that
    changes on every start, so it cannot be put into a client configuration. When the environment variable
    `APPIMAGE` is set, `command` is that AppImage path and `leading_args` is `["--mcp"]`; the AppImage's `AppRun`
    dispatches that argument to the bundled server (added by `mcp-stdio-server`). `exists` is the existence of
    the AppImage file; whether it already contains the dispatcher cannot be checked from inside.

Sending all profiles and filtering in Rust keeps the Dart side to one call with no selection logic. Secrets cross
the bridge exactly as they already do on every connect.

### D7 — Dart state flow

- `ClusterService.saveClusters`: after the preferences write, call `syncSharedProfiles` with the same `clusters`
  list; store the result in a `ValueNotifier<SharedProfilesStatus>` on the service (`ok` or failed names plus
  reason). A bridge error is caught and becomes a failed status; it does not change the return value or throw, so
  the app's own save semantics are untouched. `discardUnreadable()` syncs an empty list.
- `ClusterListController` exposes the status and `retrySharedProfilesSync()` (calls `saveClusters` with the current
  list). Both are session-wide objects already registered in `getIt`; no new registration.
- New `McpSharingDialog` (`lib/src/features/cluster/presentation/widgets/mcp_sharing_dialog.dart`, one public
  widget, view-owned state): profile name with environment tag, warning with icon, `SwitchListTile`, snippet in a
  selectable monospace box, copy button with tooltip and semantic label, "program not found" hint. Toggling calls
  `clusterController.updateCluster(index, profile.copyWith(headlessShared: value))`, shows a progress indicator
  while the save runs, and a SnackBar on failure. It receives the controller through a constructor parameter that
  defaults to `getIt<ClusterListController>()`.
- `settings_cluster_section.dart` (560 lines, limit 800): one more `IconButton` per row opening the dialog, a badge
  "Shared with MCP" (icon + text) or "Sharing failed" (error icon + text, colours from the colour scheme), and an
  inline error with a retry action above the list when the status is failed. No other existing UI is modified.
- The snippet is built in Dart with `jsonEncode` (correct escaping for any profile name):
  `{"mcpServers":{"kafkalyzer":{"command":"<command>","args":[<leading_args>,"--cluster","<name>"]}}}`,
  pretty-printed. The `--cluster` argument and the AppImage `--mcp` dispatch are contracts that `mcp-stdio-server`
  implements.
- `copyWith(headlessShared: false)` must work: the existing `copyWith` uses `??`, which is fine for a bool.

Module boundaries: `features/settings` already imports `features/cluster` (dialog, badge); the new dialog stays in
`features/cluster` and imports no other feature. `lib/src/services/` gains no feature import.

### D8 — Tests

- `kafkalyzer-profiles`: unit tests with the in-memory store and a temp directory — file has no secret values,
  `secret_fields` is correct, rename/delete/unshare cleanup, failing store excludes only the affected profile,
  missing secret at read time is an error, unreadable previous file is replaced, path resolution per platform,
  Unix mode `0600`.
- Bridge: `headless_shared` survives the codec; legacy JSON yields `None`.
- Dart: `saveClusters` calls the sync once with the saved list (mocked bridge), failure sets the status without
  failing the save; `mergeImportedProfiles` clears the field; duplicate clears it; widget test for the dialog
  (warning visible, copy disabled when not shared, snippet is valid JSON for a name with quotes).

## Risks / Trade-offs

- [`keyring` does not build or link on one CI platform] → spike 1.1 first; fallback feature set in D3.
- [Linux without a Secret Service, or the strict snap, cannot share] → reported as "keyring unavailable"; the app's
  own secret storage already has the same precondition. The snap gets no new plug in this change.
- [macOS: the keychain entry is created by the app and read by a different binary] → the user may get a keychain
  access prompt on first read by `kafkalyzer-mcp`, or access may be denied for an unsigned build. Verified in
  `mcp-stdio-server` (its spike), since the reader does not exist yet; documented in the README.
- [Unreadable shared file hides the previous set of names] → keyring entries of profiles unshared in the same save
  stay behind unused. Accepted: they are not reachable through the file, and the next unshare of the same name
  removes them.
- [Shared file reveals host names and user names to other processes of the same user] → owner-only permissions on
  Unix; on Windows the per-user `%APPDATA%` ACL applies.
- [The snippet path changes when the app is updated or moved] → Velopack keeps a stable `current` directory on
  Windows and replaces the AppImage in place on Linux; the README says to copy the snippet again after moving the
  app.
- [An AppImage released with this change but before `mcp-stdio-server` has no `--mcp` dispatcher, and the dialog
  cannot detect that] → both changes ship in the same release (roadmap phase 4); the README names the minimum
  version.
- [Second kafkalyzer instance saving at the same time] → last writer wins, same as the profile store today.

## Open Questions

None that change specs or tasks.
