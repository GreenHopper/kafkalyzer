# Design: encrypted-profile-export

## Context

See `proposal.md` (Why) and the delta specs for the required behaviour. Observed state (code read, not executed),
assuming the prerequisite `harden-local-storage-and-imports` is implemented as designed:

- **Two export paths carry credentials.**
  - `SettingsService.exportConfiguration({includeSensitiveCredentials})` builds an `Archive` from all preferences.
    With the flag, it copies keyring secrets into the `cluster_profiles` JSON inside `preferences.json`
    (`settings_service.dart:94-109`). It also opens the save dialog (`kafkalyzer_config.zip`, extension `zip`) and
    writes the file itself.
  - `ClusterListController.exportClustersZip(clusters)` returns ZIP bytes. `settings_view.dart` (~line 437) opens the
    save dialog (`clusters_export.zip`) and writes them. The prerequisite (its D8) adds `includeSecrets` (default
    `false`), serializes `sanitized()` profiles otherwise, and reuses the include-credentials dialog of the
    configuration export (`_handleExportConfiguration`, ARB `includeCredentialsInExport` /
    `includeCredentialsWarning`, which today says "unencrypted passwords").
  - `ClusterListController.exportClusters` (plain JSON) has no UI caller (verified with grep); the prerequisite gives
    it the same `includeSecrets` parameter.
- **Two import paths.** `SettingsService.importConfiguration()` picks the file itself (`FilePicker`, extension `zip`).
  The cluster import in `settings_view.dart` picks `json`/`zip` and dispatches by extension to
  `importClustersZip(bytes)` or `importClusters(json)`. After the prerequisite, both ZIP importers validate all
  entries first and merge profiles through a `resolve` callback supplied by the UI.
- **Bridge.** Bridge functions are plain `pub fn` in `rust/src/api/*.rs`. Errors are mostly `anyhow::Result`, and Dart
  parses `AnyhowException` strings (`active_connection_controller.dart:391`). Dart tests mock the bridge through
  `@GenerateMocks([KafkalyzerRustLibApi])` (`test/src/rust/api/rust_mocks.dart`).
- **Crates.** `kafkalyzer-core` has only pure dependencies (serde, apache-avro, sha2, regex, ...). The
  `kafkalyzer-profiles` crate from roadmap §4.2 does not exist yet (Phase 4, §5.16).
- **`age` crate.** `cargo info age`: 0.12.1, MIT/Apache-2.0, MSRV 1.74, labelled `[BETA]`, default features empty.
  Non-optional deps include `age-core`, `scrypt`, `chacha20poly1305`, `i18n-embed` + `rust-embed` (error message
  localisation), and in 0.12 also `hpke`, `ml-kem`, `p256`, `sha3` (post-quantum recipients). API used here:
  `Encryptor::with_user_passphrase(SecretString)`, `Decryptor::new(&[u8])`, `Decryptor::is_scrypt()`,
  `scrypt::Identity` (default max work factor = calibrated target + 4), `DecryptError::{DecryptionFailed,
  ExcessiveWork, InvalidHeader, InvalidMac, Io, KeyDecryptionFailed, NoMatchingKeys, UnknownFormat}`. Encryption
  calibrates the scrypt work factor to about one second on the exporting machine.
- **CI.** `build.yml` runs Rust tests on `ubuntu-latest` for every PR. The macOS and Windows builds run only for
  tags or `workflow_dispatch`. The `create-release` job skips the release for non-tag refs, so a `workflow_dispatch`
  run on a branch is a safe three-platform build check.

## Goals / Non-Goals

**Goals:** one encryption primitive in Rust used by both export paths; a type-level guarantee in the Dart API that
credentials are only exported together with a passphrase; one shared Dart helper for "is this encrypted, ask, decrypt"
used by both importers; distinguishable errors (wrong passphrase vs damaged file) without parsing message strings.

**Non-Goals (design level):** streaming encryption (bundles are small, in memory); armored output; a Rust-side file
writer (Dart keeps file I/O and the save dialog); changing the bundle layout inside the ZIP.

## Decisions

### D1 Layer: pure functions in `kafkalyzer-core`, not a new crate

New module `kafkalyzer_core::profile_crypto`:

```rust
pub fn encrypt_with_passphrase(plaintext: &[u8], passphrase: &str) -> Result<Vec<u8>, ProfileCryptoError>;
pub fn decrypt_with_passphrase(ciphertext: &[u8], passphrase: &str) -> Result<Vec<u8>, ProfileCryptoError>;
pub fn is_age_encrypted(bytes: &[u8]) -> bool; // prefix b"age-encryption.org/v1\n"
pub enum ProfileCryptoError { WrongPassphrase, NotPassphraseEncrypted, Corrupt, ExcessiveWork, PassphraseTooShort }
```

Both functions work on byte slices. Their only side effect is reading OS randomness (salt and file key through
`getrandom`), which is not network or file I/O, so they meet the core rule ("pure computation, no rdkafka, no network,
no frb"). They are unit-testable without the app. The passphrase is wrapped in `SecretString` (zeroized on drop)
right away. The minimum length (12 characters, `MIN_PASSPHRASE_CHARS`) is checked again in `encrypt_with_passphrase`
as a second line of defence behind the dialog.

Error mapping: `DecryptionFailed | KeyDecryptionFailed | NoMatchingKeys` → `WrongPassphrase` (for scrypt stanzas a
wrong passphrase surfaces as one of these; the spike confirms which). `!is_scrypt()` → `NotPassphraseEncrypted`
(X25519/plugin files). `ExcessiveWork` → `ExcessiveWork`. `InvalidHeader | InvalidMac | UnknownFormat | Io` →
`Corrupt`. A truncated payload after a correct header fails inside the stream reader as `Io` → `Corrupt`.

Alternatives:
- (a) Create `kafkalyzer-profiles` now. Rejected: per §4.2 that crate owns profile files and `keyring` for headless
  binaries (§5.16). Creating it for two byte functions adds Cargokit/workspace wiring now. When it is created, it
  depends on core and can call these functions; nothing has to move.
- (b) Put the code directly in the bridge crate. Rejected: the config puts computation in core, and the planned MCP
  binary (no frb) could not reuse it.
- (c) Encrypt in Dart (e.g. `cryptography` package). Rejected by E6: the encryption must happen in Rust, in the
  standard format.

### D2 Dependency: `age` with default (empty) features, checked by a spike

`age = { version = "<spike result>", default-features = false }` in `kafkalyzer-core/Cargo.toml` only. No `armor`,
`ssh`, `plugin`, `cli-common`, `async`. Spike S1 (tasks 1.x) answers, before any feature code:

1. Does `cargo build`/`cargo test` of the workspace succeed on Linux, macOS and Windows runners (`workflow_dispatch`
   on a spike branch: the full release builds through Cargokit for all three targets)?
2. How much do the dependency tree and the release library grow (`cargo tree -p kafkalyzer-core -e normal | wc -l`,
   size of `librust_lib_kafkalyzer.so` before/after)? If 0.12's post-quantum deps (`hpke`, `ml-kem`, `p256`) add
   significant build time or size, compare with `age` 0.11 (same passphrase format) and pick the smaller one.
3. `cargo tree -i rdkafka`, `-i reqwest`, `-i flutter_rust_bridge` from `kafkalyzer-core` stay empty, and
   `scripts/check_read_only.sh` passes.
4. Measured encryption/decryption time at the calibrated work factor in a release build on each runner, and whether
   a file encrypted on a fast machine decrypts on the slowest runner within the default max work factor (target + 4).
5. Which `DecryptError` variant a wrong passphrase yields, for the D1 mapping.

If (1) fails on a platform and cannot be fixed with features or a version pin, the change stops and reports back
(E6 would need revisiting); no fallback to a home-made container.

### D3 Bridge: additive, bytes in/out, typed error

`rust/src/api/profile_crypto.rs`:

```rust
pub fn encrypt_bundle_with_passphrase(plaintext: Vec<u8>, passphrase: String) -> BundleCryptoResult;
pub fn decrypt_bundle_with_passphrase(ciphertext: Vec<u8>, passphrase: String) -> BundleCryptoResult;
pub enum BundleCryptoErrorKind { WrongPassphrase, NotPassphraseEncrypted, Corrupt, ExcessiveWork, PassphraseTooShort, Internal }
pub struct BundleCryptoResult { pub data: Option<Vec<u8>>, pub error: Option<BundleCryptoErrorKind>, pub message: Option<String> }
```

Note (from Spike 1.7): `frb v2.11.1` rejects `Result<Vec<u8>, BundleCryptoError>` with data-carrying variants (`Internal(String)`) because it requires `@freezed >= 1.0.0`, so the bridge returns `BundleCryptoResult` with a unit `BundleCryptoErrorKind` enum and optional `message` instead, and `encrypted_bundle.dart` maps non-null `error` into `EncryptedBundleException` (or retries on `WrongPassphrase`). Both `BundleCryptoErrorKind` and `BundleCryptoResult` are defined in the bridge crate and mapped from the core enum (orphan rule, L3). The functions are async on the Dart side (frb default, worker thread pool), so the ~1 s scrypt work does not block the UI isolate. `message` carries no passphrase or plaintext. No existing signature changes.

Detection stays in Dart as a byte prefix check (`encrypted_bundle.dart`, constant `ageHeaderPrefix`): it is needed
before any bridge call and lets the Dart tests (bridge mocked) cover dispatch. The core `is_age_encrypted` is used by
Rust tests and future Rust callers.

### D4 Dart export API: credentials only with a passphrase

- `SettingsService.exportConfiguration({String? encryptionPassphrase})` replaces `includeSensitiveCredentials`.
  `null` → today's secret-free bundle, `.zip`. Non-null → secrets included as today, then the ZIP bytes go through
  `encryptBundleWithPassphrase` and the save dialog offers `kafkalyzer_config.zip.age` (extension `age`).
- `ClusterListController.exportClustersZip(clusters, {String? encryptionPassphrase})` replaces the prerequisite's
  `includeSecrets`. `null` → `sanitized()` profiles, plain ZIP. Non-null → profiles with secrets, encrypted bytes.
  `settings_view.dart` uses `clusters_export.zip.age` and enforces the `.age` suffix like it does `.zip` today.
- `exportClusters` (plain JSON, no UI caller) loses `includeSecrets` and always serializes `sanitized()` profiles.
- The plaintext with-secrets ZIP exists only as an in-memory `List<int>` and is never written to disk. Encryption
  happens before the save dialog result is used, so a failed encryption writes nothing.

There is no way to request secrets without a passphrase, so "unencrypted credentials in a file" cannot be reached
through the API.

### D5 Export dialog

The shared include-credentials dialog (from the prerequisite) is extended in place: when the checkbox is ticked, it
shows two obscured passphrase fields (with show/hide toggle, tooltip and semantic label) and replaces the old
"unencrypted" warning with the not-recoverable warning (icon + text). The Export button stays disabled until the
passphrase has ≥12 characters (counted as Unicode code points via `runes.length`) and both fields match; inline
validation messages explain why. The dialog returns `ExportCredentialsChoice(passphrase: String?)`. Fields use
`autofillHints: null` and `enableSuggestions: false`, `autocorrect: false`. The passphrase lives only in the dialog's
`TextEditingController`s and the call; controllers are disposed when the dialog closes.

Alternative: a separate "Encrypted export" button. Rejected: the spec ties encryption to "include credentials", and
one dialog keeps the choice in one place.

### D6 Import: shared helper with retry loop

`lib/src/services/encrypted_bundle.dart`:

```dart
bool isAgeEncrypted(List<int> bytes);
typedef PassphrasePrompt = Future<String?> Function({required bool previousAttemptFailed});
Future<List<int>?> decryptIfEncrypted(List<int> bytes, PassphrasePrompt prompt); // null = user cancelled
class EncryptedBundleException implements Exception { final EncryptedBundleFailure kind; } // corrupt, unsupported, tooExpensive
```

Flow: if not encrypted, return the bytes unchanged (legacy path untouched). Otherwise loop: prompt → `null` returns
`null` (cancel) → bridge decrypt → `WrongPassphrase` prompts again with `previousAttemptFailed: true` → other errors
throw `EncryptedBundleException`. The result goes into the unchanged ZIP import path, so the prerequisite's entry
validation, merge and keyring handling apply to decrypted bundles exactly as to plain ones. Nothing is written before
decryption succeeded, which gives "no profile changed" for every failure.

- `SettingsService.importConfiguration({required PassphrasePrompt promptPassphrase, ...})`: the picker accepts `zip`
  and `age`; the bytes go through the helper first. A cancel returns without changes and without a success message
  (the method returns a result value that the view uses to skip the SnackBar).
- Cluster import in `settings_view.dart`: the picker accepts `json`, `zip`, `age`; the view reads the bytes, runs the
  helper, and dispatches by content: encrypted or ZIP magic (`PK\x03\x04`) → `importClustersZip`, otherwise JSON →
  `importClusters`. Dispatch by content instead of extension means a renamed file still works.
- `PassphrasePromptDialog` (material_ui, obscured field, show/hide toggle, inline "wrong passphrase" error when
  `previousAttemptFailed`) is shared by both import buttons. It shows no minimum length on import (old files might
  come from the `age` CLI with shorter passphrases).
- While decrypting, the dialog/button shows a progress indicator (scrypt takes about a second).

### D7 No logging of secrets

The passphrase is passed only as a function argument. `exportConfiguration`'s debug line logs only whether
encryption was requested (boolean). Error messages are built from `BundleCryptoError` variants and ARB strings, never
from input. A Dart test overrides `debugPrint` and fails if the test passphrase appears in any captured line during
export and import (success and failure).

### Layering summary

| Piece | Layer | Why |
|---|---|---|
| age encrypt/decrypt, error mapping, min-length check | `kafkalyzer-core` | Pure computation, reusable by future MCP/profile crate |
| `BundleCryptoError`, `Vec<u8>` functions | bridge crate | L3, frb only here |
| detection, retry loop, dispatch, file dialogs, file write | Dart services/view | I/O and UI flow, existing importers are Dart |

## Risks / Trade-offs

- [`age` is labelled beta and 0.12 pulls post-quantum crates] → The passphrase format `age-encryption.org/v1` with
  scrypt is stable and specified (C2SP). Spike S1 measures size/build time and may pin 0.11. `Cargo.lock` pins the
  version.
- [scrypt work factor calibrated on a fast exporter is too high for a slow importer] → Default max = importer's
  target + 4 (≈16 s). Beyond that, `ExcessiveWork` gives a clear error instead of a hang. The spike measures real
  numbers on all runners.
- [Dart strings holding the passphrase cannot be zeroized] → Accepted. The passphrase is not persisted, not logged,
  and the controllers are disposed. Rust zeroizes its copy.
- [Users lose the passphrase] → Not recoverable by design. The dialog warns, and the secret-free export remains as a
  fallback.
- [The rest of the configuration bundle (non-secret prefs, keystore/truststore files) is only protected when
  credentials are included] → Same as today for secret-free exports. Encrypting secret-free bundles is a non-goal.
- [Removing the plaintext opt-in breaks users who scripted around `kafkalyzer_config.zip` with passwords] → Old files
  still import. `age -d` gives the plain ZIP for external tooling.

## Migration Plan

No stored-data migration; no preference keys added. Old unencrypted bundles stay importable (same code path after the
`isAgeEncrypted` check). Rollback = revert the commit; encrypted bundles written meanwhile can still be opened with
`age -d`, then imported as plain ZIPs into the older version.

## Open Questions

- Should the save dialog's default file name carry a date (e.g. `kafkalyzer_config-2026-05-01.zip.age`)? Cosmetic,
  can be decided during implementation.
