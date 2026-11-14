# Tasks

Prerequisites: `harden-local-storage-and-imports` and `restore-tls-verification` are merged (names used below:
`normalizeProfileName`, `existingNames`, `tlsVerification`, `InsecureTlsBadge`, keyring status).

## 1. Spike: allowlist against librdkafka 2.3.0

- [ ] 1.1 In `rust/kafkalyzer-kafka/src/kafka_utils.rs`, add a `#[cfg(test)]` test that creates an offline
  `BaseConsumer` (bootstrap `127.0.0.1:1`) for each candidate key of design D2, once with its minimum sample and once
  with its maximum sample. Record the keys or ranges librdkafka rejects (expected doubts: `retry.backoff.max.ms`,
  `fetch.max.bytes`). Verify with `cargo test -p kafkalyzer-kafka allowlist_spike`.
- [ ] 1.2 Fix the final allowlist and ranges in design D2 (remove or narrow failing entries). Verify that the test
  from 1.1 passes for every remaining entry.

## 2. `kafkalyzer-core`: properties, allowlist, bootstrap, client.properties

- [ ] 2.1 Add the module `client_properties` with `parse_lines` (comments, `=`/`:`, continuation, escapes,
  `\uXXXX`) and unit tests for each syntax rule and the `Syntax` line result. Verify with
  `cargo test -p kafkalyzer-core client_properties`.
- [ ] 2.2 Add `ALLOWED`, `validate` (`NotAllowed`, `InvalidValue` with range, `Duplicate`, `Syntax`) and `effective`.
  Tests cover one valid and one invalid value per value kind, `debug` with `all`/`msg`/`conf` rejected, and a
  forbidden sample (design D3) rejected by key. Test values must not put `enable.auto.commit` and `"true"` on one
  line. Verify with `cargo test -p kafkalyzer-core`.
- [ ] 2.3 Add the module `bootstrap` with `parse_bootstrap_servers` and the issue kinds of design D4. Tests cover
  the spec examples (valid list with IPv6, missing port, `host.9092`, `http://`, whitespace inside, port 99999,
  trailing comma, empty value). Verify with `cargo test -p kafkalyzer-core bootstrap`.
- [ ] 2.4 Add `map_client_properties` with the mapping table and skip reasons of design D5, including a hand-written
  JAAS tokenizer. Tests cover PLAIN/SCRAM/Krb5 JAAS, librdkafka-style keys, JKS, `${…}` placeholder, verification
  override, `basic.auth.user.info`, an allowlisted key that goes to extras, and the rule that no skipped entry carries
  its value. Verify with `cargo test -p kafkalyzer-core`.
- [ ] 2.5 Add `extra_properties: Vec<(String, String)>` to the domain `ClusterProfile` (`kafka_types.rs`) and update
  every constructor in the workspace (`grep -rn "ClusterProfile {" rust/`). Verify with
  `cargo build --workspace --all-targets`.

## 3. `kafkalyzer-kafka`: enforcement in `create_config`

- [ ] 3.1 At the end of `create_config`, apply `client_properties::effective(&profile.extra_properties)`. Leave the
  `KRB5_CONFIG` handling unchanged and add a comment that it is process-wide (design Context). Verify that the
  tests from 3.2 pass.
- [ ] 3.2 Add unit tests from design D3: an allowed key is set, an invalid value is not set, the forbidden sample
  is never set or overridden, and the allowlist is disjoint from the keys that `create_config` and the consumers set.
  Verify with `cargo test -p kafkalyzer-kafka kafka_utils`.

## 4. Bridge crate and code generation

- [ ] 4.1 Add `environment_label`, `environment_color` and `extra_properties` (`Option<String>`) to the DTO
  `ClusterProfile` in `rust/src/api/kafka_types.rs`, and map `extra_properties` in `to_domain` via `parse_lines`.
  Extend the tests in `rust/src/api/json_path.rs`: legacy JSON loads with `None`, a round trip keeps all three keys,
  and `to_domain` drops syntax-error lines. Verify with `cargo test -p rust_lib_kafkalyzer`.
- [ ] 4.2 Add `rust/src/api/profile_tools.rs` (registered in `api/mod.rs`) with the three `#[frb(sync)]` validators
  and the async `parse_client_properties`, including local DTOs and enums (design D7). Add mapping tests for each
  enum. Verify with `cargo test -p rust_lib_kafkalyzer`.
- [ ] 4.3 Run `flutter_rust_bridge_codegen generate`, then `dart run build_runner build`. Verify that
  `lib/src/rust/api/profile_tools.dart` exists, `ClusterProfile` has the three optional fields, the mocks in
  `test/src/rust/api/rust_mocks.mocks.dart` are regenerated, and `flutter analyze` reports no new errors.

## 5. Dart model and services

- [ ] 5.1 Carry the three fields in `ClusterService` `sanitized`, `withSecrets` and `copyWith`. Add a test in
  `test/src/services/cluster_service_test.dart` that builds a profile with every non-secret field set and asserts
  that all three helpers keep each field. Verify with `flutter test test/src/services/cluster_service_test.dart`.
- [ ] 5.2 Add a `ClusterProfileTools` service (wraps the `profile_tools` bridge functions), register it in
  `dependency_injection.dart`, and provide a fake for widget tests. Verify that `flutter analyze` is clean.
- [ ] 5.3 Add the pure helpers `suggestCopyName` (uses `normalizeProfileName`) and `matchesClusterFilter`, with unit
  tests for "(copy)", "(copy 2)" and case-insensitive matching on name, label and bootstrap. Verify with
  `flutter test`.

## 6. Cluster dialog

- [ ] 6.1 Environment tag section in `ClusterConfigDialog`: an `Autocomplete` label field (max 16 characters),
  `ChoiceChip` palette with suggestion preselection, and the raw unknown colour kept unless the user changes it.
  Carry both fields in `_buildCandidateProfile`. Add en+de ARB keys. Widget tests cover the "Tagging a profile as
  production", "Removing a tag", "Overlong label rejected" and "Unknown stored colour" scenarios. Verify with
  `flutter test test/src/features/cluster/presentation/widgets/config_dialog/`.
- [ ] 6.2 Bootstrap validator in `ClusterBasicInfoForm` via `ClusterProfileTools`, with one ARB message per issue
  kind that names the entry (en+de). Widget tests: Save and Test Connection are blocked for the spec examples, and
  the valid list is accepted. Verify with `flutter test`.
- [ ] 6.3 Collapsible "Additional client properties" section: multiline field, inline issues per line, a list of
  allowed keys with value hints from `allowedExtraProperties`, and Save/Test blocked while issues exist. Carry the
  field in `_buildCandidateProfile`. Add en+de ARB keys. Widget tests cover the four scenarios of the spec
  requirement. Verify with `flutter test`.
- [ ] 6.4 "Import client.properties" action (add mode only): file pick, 1 MiB and UTF-8 checks, a preview dialog
  (mapped fields with masked secrets, extras, skipped keys with localized reasons), and Apply fills the controllers
  only. Add en+de ARB keys. Widget tests use a fake `ClusterProfileTools`: the SCRAM example, the unknown/unsupported
  keys, the verification override, the oversized file, and the case where nothing is saved before Save. Verify with
  `flutter test`.
- [ ] 6.5 `isDuplicate` mode (title, Add button, uniqueness treated as new) and the "Duplicate" `IconButton` with
  tooltip in the Settings tile, wired to `addCluster`. Tests: the copy keeps secrets, extras, tag and
  `tlsVerification`; cancel creates nothing; the source stays unchanged after the copy's password is edited
  (`cluster_list_controller_test.dart` with a fake secure storage). Verify with `flutter test`.

## 7. Environment markers, filter and disconnect

- [ ] 7.1 Add `EnvironmentPalette` and `EnvironmentTagChip` (semantics label, theme-aware colours) in `lib/src/ui/`.
  Use them in the Settings tile, the Explorer sidebar tile, `ClusterDropdown` items and `_buildTabItemContent`
  (resolved by name from `ClusterListController`, next to `InsecureTlsBadge`). Add `EnvironmentBanner` above the
  Explorer tab bar. Widget tests in `explorer_view_test.dart`, `settings_view_test.dart` and
  `cluster_dropdown_test.dart` cover each "Environment Tag Visible" scenario. Verify with `flutter test`.
- [ ] 7.2 Add `ClusterFilterField` to the Settings list (always) and the Explorer sidebar (more than five profiles),
  with a no-match message and a clear action (en+de ARB). Widget tests cover the four filter scenarios. Verify with
  `flutter test`.
- [ ] 7.3 Make `ActiveConnectionController.disconnect()` cluster-scoped (design D9). Add `hasRunningOperations`,
  the sidebar "Disconnect" `IconButton` with tooltip and semantics, and a confirmation dialog (en+de ARB). Controller
  tests: only the active cluster's tabs close, the topic cache is cleared, and the session is not written. A widget
  test covers the confirm and cancel paths with a running stream. Verify with `flutter test`.
- [ ] 7.4 Add the bootstrap guard in `connect` (before `_connectingProfile` is set), with the localized error.
  Controller test: an invalid stored profile never calls `validateConnection`. Verify with `flutter test`.

## 8. Per-cluster sessions (B13)

- [ ] 8.1 Change `_saveSessionTabs(clusterName)` and its callers as in design D8, using
  `_lastActiveTopicByCluster`. Tests in `active_connection_controller_test.dart` cover "Session contains only the
  tabs of its own cluster" and "Closing a tab of a non-active cluster updates that cluster's session". Verify with
  `flutter test test/src/features/cluster/presentation/controllers/active_connection_controller_test.dart`.
- [ ] 8.2 In restore: add the `_restoring` flag, a single save at the end, `unrestoredTopics`, active lookup by topic
  and profile, and the guard for a `null` topic list. `ExplorerView` shows a SnackBar (en+de ARB, plural-aware) and
  acknowledges it. Tests cover the "Tabs that cannot be restored are reported" scenario, the failed-fetch guard (the
  session is unchanged) and "Disconnect keeps the session". Verify with `flutter test`.

## 9. Localization completeness

- [ ] 9.1 Check that every key added in groups 6–8 exists in `lib/l10n/app_en.arb` (with `@` descriptions and
  placeholders) and in `lib/l10n/app_de.arb`, and that the new widgets contain no hard-coded user-facing strings.
  Verify with `flutter gen-l10n` (no untranslated-message warnings for the new keys) and
  `grep -n "Text('" <new widget files>`, which must return nothing.

## 10. Final verification

- [ ] 10.1 In `rust/`, run `cargo fmt --all`, `cargo clippy --workspace --all-targets -- -D warnings` and
  `cargo test --workspace`. Verify that all pass.
- [ ] 10.2 Run `dart format lib test`, `flutter analyze` and `flutter test`. Verify that all pass.
- [ ] 10.3 Run `scripts/check_read_only.sh` and verify that it passes unchanged with no new exception marker.
- [ ] 10.4 Manual check against a local broker: tag a profile PROD and see the chip in sidebar, tab and banner;
  duplicate it and restart the app, and the copy connects without re-entering the password; set `client.id` and see
  it in the broker's request log; disconnect and reconnect, and
  the tabs are restored. Record the result in the PR description.
