# Tasks

## 1. Spike

- [x] 1.1 Add a scratch workspace crate depending on `keyring` v3 (`apple-native`, `windows-native`,
      `sync-secret-service`, `crypto-rust`) and build it in the Linux, macOS and Windows jobs of `build.yml` on a
      branch; verify all three builds pass without new system packages, or switch to the fallback feature set of
      design D3 and record the result in `design.md`
- [x] 1.2 On Linux, write, read and delete one entry through the crate against a running Secret Service and
      verify the value round-trips; record the observed error for "no Secret Service" in `design.md`

## 2. Crate `kafkalyzer-profiles`

- [x] 2.1 Create `rust/kafkalyzer-profiles` (deps: `kafkalyzer-core`, `serde`, `serde_json`, `anyhow`, `log`,
      `keyring`), add it to the workspace members, and verify `cargo build --workspace` and
      `scripts/check_read_only.sh` pass
- [x] 2.2 Implement `SecretField`, `SharedProfile`, the versioned file envelope and the explicit secret split on
      the domain `ClusterProfile`; verify with unit tests that a serialized profile contains no secret value and
      lists the right `secret_fields`
- [x] 2.3 Implement `default_path()` over an injectable environment lookup; verify with unit tests for Linux (with
      and without `XDG_CONFIG_HOME`), macOS, Windows and the "directory unknown" error
- [x] 2.4 Implement `SecretStore` with the keyring and in-memory implementations; verify the in-memory one with
      unit tests and the keyring one with an `#[ignore]`d test whose reason names the need for an OS keyring
- [x] 2.5 Implement `write_shared` (secrets, atomic file, cleanup in that order, owner-only mode on Unix) returning
      `SyncReport`; verify with unit tests for add, edit, rename, delete, unshare, a store that fails for one
      profile, an unreadable previous file, an unwritable directory and the Unix file mode
- [x] 2.6 Implement `read_shared`; verify with unit tests that secrets are restored, that a missing recorded secret
      is an error naming profile and field, and that an unknown file version is an error
- [x] 2.7 Run `cargo fmt --all`, `cargo clippy --workspace --all-targets` and `cargo test --workspace`; verify all
      pass

## 3. Bridge

- [x] 3.1 Add `headless_shared: Option<bool>` to the bridge `ClusterProfile`; verify with unit tests in
      `rust/src/api/json_path.rs` that it round-trips, that legacy JSON yields `None`, and that `to_domain()` is
      unchanged
- [x] 3.2 Add `rust/src/api/headless_profiles.rs` with `sync_shared_profiles` (request and result structs) and
      `mcp_server_launch`; verify with a unit test that only profiles with `Some(true)` are passed on and
      that failure kinds map one to one
- [x] 3.3 Run `flutter_rust_bridge_codegen generate` and `dart run build_runner build`; verify `flutter analyze`
      passes and the regenerated bindings and `rust_mocks.mocks.dart` are part of the change

## 4. Dart service and controller

- [x] 4.1 Pass `headlessShared` through `sanitized()`, `withSecrets()` and `copyWith()`; verify with a unit test
      that save and load keep the value
- [x] 4.2 Clear `headlessShared` on every item in `mergeImportedProfiles`; verify with unit tests for a new
      imported profile and for Replace of a shared profile
- [x] 4.3 Call the sync in `ClusterService.saveClusters` and `discardUnreadable`, expose the status notifier;
      verify with unit tests (mocked bridge) that the sync receives the saved list, that a failed or throwing sync
      sets the failed status and leaves the save result unchanged
- [x] 4.4 Expose the status and `retrySharedProfilesSync()` on `ClusterListController`; verify with a unit test
      that retry saves the current list again

## 5. Dart UI

- [x] 5.1 Add the en and de ARB keys (dialog title, switch label, data-flow warning, snippet label, copy action,
      copied confirmation, share-first hint, program-not-found hint, shared badge, sharing-failed badge, failure
      reasons, retry) and regenerate localizations; verify `flutter analyze` passes
- [x] 5.2 Implement `McpSharingDialog` with `package:material_ui/material_ui.dart`; verify with widget tests that
      the warning is visible before toggling, the copy action is disabled when not shared, the copied snippet is
      valid JSON for a name with quotes and non-ASCII characters, the program-not-found hint appears, and a failed
      toggle shows an error
- [x] 5.3 Add the row action, the shared and sharing-failed badges and the inline error with retry to
      `settings_cluster_section.dart`, and clear `headlessShared` in the duplicate action; verify with widget tests
      for both badges, the retry action and the duplicated copy
- [x] 5.4 Add a README section "Sharing a cluster with an MCP client" (what is written where, keyring
      precondition on Linux, data flow to the LLM provider, copy the snippet again after moving the app); verify
      the described file path matches `default_path()` on each platform

## 6. Verification

- [x] 6.1 Run `cargo fmt --all`, `cargo clippy --workspace --all-targets`, `cargo test --workspace`,
      `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`,
      `scripts/check_read_only.sh` and `scripts/quality_gates.sh`; verify all pass
- [x] 6.2 Manually on one desktop: share a SASL profile, confirm the file has no secret, rename it, unshare it and
      confirm the file entry and the dedicated keyring entries are gone
