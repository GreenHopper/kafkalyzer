# Tasks

Prerequisite: `harden-local-storage-and-imports` is merged (secret-free cluster export with `includeSecrets`, shared
include-credentials dialog, safe ZIP import planner, merge-with-conflict import). Run Rust commands in `rust/`.

## 1. Spike S1: `age` dependency on all platforms (design D2)

- [x] 1.1 On a spike branch add `age = { version = "0.12", default-features = false }` to
      `rust/kafkalyzer-core/Cargo.toml` plus a throwaway test that encrypts and decrypts 1 KiB with a passphrase;
      verify `cargo build --workspace` and `cargo test -p kafkalyzer-core` pass locally on Linux
- [x] 1.2 Record the footprint: `cargo tree -p kafkalyzer-core -e normal | wc -l` and the release size of
      `librust_lib_kafkalyzer` before/after; repeat with `age = "0.11"`; pick the version (prefer the newest unless
      0.12's post-quantum deps add clearly more size or build time) and write the numbers into this change's
      `design.md` D2
- [x] 1.3 Verify `cargo tree -p kafkalyzer-core -i rdkafka`, `-i reqwest` and `-i flutter_rust_bridge` print nothing
      and `scripts/check_read_only.sh` passes unchanged
- [x] 1.4 Trigger `build.yml` via `workflow_dispatch` on the spike branch (non-tag ref, so `create-release` skips);
      verify `build-linux`, `build-macos` and `build-windows` succeed; if one fails and no feature/version pin fixes
      it, stop and report (E6 must be revisited, no home-made fallback)
- [x] 1.5 Measure in a release build on each runner (spike test with `--nocapture`): encrypt/decrypt time at the
      calibrated work factor, and decrypt time of a file encrypted with work factor 18 on the slowest runner; confirm
      it stays below the default max work factor (target + 4) or note the result in design Risks
- [x] 1.6 Record which `DecryptError` variant a wrong passphrase, a flipped header byte, a truncated payload and an
      X25519-recipient file produce; adjust the error mapping in design D1 if it differs
- [x] 1.7 Verify frb v2.11.1 generates a thrown Dart exception type for `Result<Vec<u8>, BundleCryptoError>` with an
      enum error (generate on the spike branch, inspect `lib/src/rust/api/`); if not, switch D3 to a result DTO and
      note it in the design

## 2. Core: `kafkalyzer_core::profile_crypto`

- [x] 2.1 Add the chosen `age` version to `rust/kafkalyzer-core/Cargo.toml` (default features off) and create
      `rust/kafkalyzer-core/src/profile_crypto.rs` with `encrypt_with_passphrase`, `decrypt_with_passphrase`,
      `is_age_encrypted`, `MIN_PASSPHRASE_CHARS = 12` and `ProfileCryptoError` (design D1), registered in `lib.rs`;
      passphrase wrapped in `SecretString` immediately; verify `cargo build -p kafkalyzer-core`
- [x] 2.2 Unit tests in `profile_crypto.rs` (use `scrypt::Recipient::set_work_factor` with a low factor through a
      test-only helper to keep tests fast): round trip of empty, 1 byte and 1 MiB input; output starts with
      `age-encryption.org/v1\n`; wrong passphrase → `WrongPassphrase`; flipped header byte → `Corrupt`; truncated
      payload → `Corrupt`; non-age bytes → `Corrupt`; X25519-encrypted file → `NotPassphraseEncrypted`; 11-character
      passphrase → `PassphraseTooShort`; 12-character multi-byte passphrase accepted; verify
      `cargo test -p kafkalyzer-core profile_crypto`
- [x] 2.3 Interop fixture: add `rust/kafkalyzer-core/tests/fixtures/age_cli_passphrase.age` created with the `age`
      CLI (`age -p -o ... plain.txt`, passphrase documented in the test) and a test that decrypts it to the known
      plaintext; verify `cargo test -p kafkalyzer-core`

## 3. Bridge

- [x] 3.1 Add `rust/src/api/profile_crypto.rs` with `encrypt_bundle_with_passphrase` and
      `decrypt_bundle_with_passphrase` (`Vec<u8>` in/out) and the bridge enum `BundleCryptoError` mapped from
      `ProfileCryptoError` (design D3); register in `rust/src/api/mod.rs`; no existing signature changes; verify
      `cargo build` and a bridge-crate unit test that maps every core variant
- [x] 3.2 Run `flutter_rust_bridge_codegen generate` and `dart run build_runner build`; verify the new functions
      appear in `lib/src/rust/api/profile_crypto.dart` and in `test/src/rust/api/rust_mocks.mocks.dart`, and
      `flutter analyze` reports no new issues

## 4. Dart: encrypted bundle helper

- [x] 4.1 Create `lib/src/services/encrypted_bundle.dart` with `isAgeEncrypted`, `PassphrasePrompt`,
      `decryptIfEncrypted` (retry on `WrongPassphrase`, `null` on cancel) and `EncryptedBundleException`
      (`corrupt`, `unsupported`, `tooExpensive`) (design D6); verify `test/src/services/encrypted_bundle_test.dart`
      with the mocked bridge: plain ZIP/JSON bytes pass through without prompting; encrypted bytes prompt; wrong then
      correct passphrase prompts twice with `previousAttemptFailed` true the second time; cancel returns `null`;
      `Corrupt` → exception without a second prompt

## 5. Dart: export paths

- [x] 5.1 `SettingsService.exportConfiguration({String? encryptionPassphrase})` replaces
      `includeSensitiveCredentials`: `null` keeps the secret-free `.zip`; non-null includes secrets, encrypts via the
      bridge and saves as `kafkalyzer_config.zip.age` (extension `age`); a bridge error writes nothing and rethrows;
      verify in `test/src/services/settings_service_test.dart`: default export has no secret and is a ZIP; encrypted
      export passes the plaintext ZIP containing all six secret fields to the mocked encrypt call and writes only the
      returned bytes; encrypt failure → no file written
- [x] 5.2 `ClusterListController.exportClustersZip(clusters, {String? encryptionPassphrase})` replaces the
      prerequisite's `includeSecrets`; `exportClusters` (JSON) always serializes `sanitized()`; verify with controller
      tests: default ZIP without secrets; with passphrase the mocked encrypt receives a ZIP whose `clusters.json`
      holds SASL password, OAuth token, PEM key password and Schema Registry password, and the result is the
      encrypted bytes; JSON export never contains secrets
- [x] 5.3 Extend the shared include-credentials export dialog (design D5): passphrase + confirmation fields (obscured,
      show/hide toggle with tooltip and semantic label, no suggestions/autocorrect), minimum 12 code points, match
      check, not-recoverable warning (icon + text), Export disabled until valid; return the passphrase or `null`;
      wire both the configuration export and the cluster export in `settings_view.dart` (`.zip.age` file name and
      suffix enforcement, progress indicator while encrypting); update `settings_view_test.dart` mocks
      (`encryptionPassphrase:`); verify with widget tests: 11 characters → error and disabled button; mismatch →
      error; valid → service called with the passphrase; unchecked → called with `null`
- [x] 5.4 ARB keys (en + de) for the export dialog: `exportPassphraseLabel`, `exportPassphraseConfirmLabel`,
      `exportPassphraseTooShort` (placeholder `min`), `exportPassphraseMismatch`, `exportPassphraseNotRecoverable`,
      `showPassphrase`, `hidePassphrase`, `encryptingBundle`; change `includeCredentialsWarning` (en + de) so it no
      longer says "unencrypted"; verify `flutter gen-l10n` and that no new hard-coded string exists in the dialog

## 6. Dart: import paths

- [x] 6.1 `PassphrasePromptDialog` (material_ui, obscured field, show/hide toggle, inline wrong-passphrase error,
      progress while decrypting, cancel) with ARB keys `importPassphraseTitle`, `importPassphraseLabel`,
      `importPassphraseWrong`, `importEncryptedCorrupt`, `importEncryptedUnsupported`, `importEncryptedTooExpensive`
      (en + de); verify with a widget test for first prompt, retry state and cancel
- [x] 6.2 `SettingsService.importConfiguration` takes a `PassphrasePrompt`, accepts `zip` and `age` in the picker,
      runs `decryptIfEncrypted` before any extraction, and returns a result that distinguishes cancel; verify in
      `settings_service_test.dart`: encrypted bundle + correct passphrase imports profiles and writes secrets to the
      keyring mock; wrong passphrase then cancel → preferences, profiles and keyring mock untouched and no success;
      corrupt → `EncryptedBundleException` and nothing written; a legacy plaintext bundle with credentials (fixture
      built like the old exporter) still imports without a prompt
- [x] 6.3 Cluster import in `settings_view.dart`: picker accepts `json`, `zip`, `age`; read bytes, run
      `decryptIfEncrypted`, dispatch by content (ZIP magic → `importClustersZip`, else `importClusters`); show the
      mapped error messages via SnackBar and no success message on cancel; verify with widget/controller tests for an
      encrypted ZIP, a renamed encrypted file with `.zip` extension, a legacy JSON import and the cancel path

## 7. Secrets never logged or persisted

- [x] 7.1 Review all touched Dart code for log calls that could include the passphrase or decrypted content; add a
      test that overrides `debugPrint` (and the app `Logger` output) during encrypted export, successful import,
      wrong-passphrase import and failed encryption, and asserts the test passphrase never appears; assert
      `SharedPreferences` and the keyring mock contain no passphrase afterwards; verify `flutter test` on that file

## 8. Acceptance: interoperability with the `age` CLI

- [x] 8.1 Manual check on Linux with the `age` CLI installed: export configuration and clusters with credentials,
      run `age -d -o out.zip kafkalyzer_config.zip.age` with the passphrase, verify `unzip -l out.zip` lists
      `preferences.json` (and `clusters.json` for the cluster export) and that the app imports `out.zip` unchanged;
      encrypt a valid bundle with `age -p` and verify the app imports it after asking for the passphrase; note the
      result in the PR description

## 9. Final verification

- [x] 9.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets` (no new warnings), `cargo test
      --workspace` green
- [x] 9.2 Re-run `flutter_rust_bridge_codegen generate` and `dart run build_runner build`; verify `git status` shows
      no further changes in `lib/src/rust/` and the mocks
- [x] 9.3 `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze` with no new issues,
      `flutter test` all green
- [x] 9.4 `scripts/check_read_only.sh` passes unchanged (no new Kafka or Schema Registry calls, dependency allowlist
      green with `age`)
- [x] 9.5 Manual smoke on Linux: default export opens without a passphrase and contains no secrets; credential
      export refuses an 11-character passphrase; encrypted import with a wrong passphrase leaves the profile list and
      keyring unchanged; correct passphrase imports with the conflict dialog from the prerequisite
