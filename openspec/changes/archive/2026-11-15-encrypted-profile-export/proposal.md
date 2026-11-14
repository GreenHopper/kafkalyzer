# Proposal: encrypted-profile-export

Source: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md`, §5.7 (change id `encrypted-profile-export`),
decision E6 (`age` passphrase format through the Rust crate `age`), under the guardrails of §1 (L1, L2, L3, L5) and
the non-goals of §7. Roadmap phase 1b ("sicherer Team-Export").

## Why

Today a bundle that carries credentials is plaintext. The configuration export writes keyring secrets into
`preferences.json` when the user ticks "Include passwords and tokens" (`settings_service.dart:94-109`). The cluster
ZIP export (`ClusterListController.exportClustersZip`) serializes the in-memory profiles, so it always contained
secrets. The prerequisite `harden-local-storage-and-imports` scrubs them by default and adds a warned plaintext
opt-in. Sharing a working profile with a colleague still means a file with readable passwords on disk, in mail and
in chat. E6 decided to close that gap with a standard format (`age`, scrypt + ChaCha20-Poly1305) instead of a home-made
container, so the file can also be opened with the `age` CLI.

## What Changes

- **Export with credentials is passphrase-encrypted only.** In the configuration export and in the cluster export
  (Settings > cluster list), ticking "include passwords and tokens" now asks for a passphrase. The finished ZIP is
  encrypted in Rust as an `age` passphrase file (`.zip.age`). The plaintext opt-in from the prerequisite is removed:
  no code path writes credentials to an export file unencrypted. **BREAKING** (UI flow only): the plaintext
  credential export no longer exists.
- **Export without credentials stays the default** and stays an unencrypted `.zip`, as today. No optional encryption
  of secret-free bundles.
- **Passphrase rules.** Minimum length of 12 characters, entered twice, with a warning that a lost passphrase cannot
  be recovered. The passphrase is never stored, logged or put into an error message.
- **Import detects encrypted bundles** by the `age` header (`age-encryption.org/v1`), not by file extension, in both
  the configuration import and the cluster import. The user is asked for the passphrase. A wrong passphrase lets the
  user retry or cancel. A damaged or unsupported file gives a clear error. In every failure case no profile, secret,
  file or preference is changed. After decryption the bundle runs through the prerequisite's safe import (entry
  validation, merge with conflict dialog, secrets into the keyring).
- **Old bundles stay importable:** unencrypted ZIP and JSON bundles, with or without credentials, import as before.
- **Rust:** a new pure module `kafkalyzer_core::profile_crypto` (encrypt/decrypt bytes with a passphrase) and the
  additive bridge functions `encrypt_bundle_with_passphrase` / `decrypt_bundle_with_passphrase` (bytes in, bytes out,
  typed error). New dependency `age` (minimal features) in `kafkalyzer-core`, checked on Linux, macOS and Windows by a
  spike first.

Read-only impact: no new Kafka or Schema Registry calls. Only local file encryption. `scripts/check_read_only.sh`
must pass unchanged (`age` brings no `rdkafka`, `reqwest` or `flutter_rust_bridge`).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `secure-credentials-storage`: MODIFIED *Safe Profile Export and Import Controls* (credentials only in a
  passphrase-encrypted `age` bundle; encrypted import with wrong-passphrase/corrupt handling; legacy bundles still
  import); ADDED *Export Passphrase Handling* (minimum length, confirmation, not-recoverable warning, never stored or
  logged).
- `cluster-profile-persistence`: MODIFIED *Stored Profiles Survive Configuration Export And Import* (the authorized
  export with credentials is the encrypted export; round trip through the passphrase).

## Impact

- Rust: `rust/kafkalyzer-core/Cargo.toml` (+ `age`), new `rust/kafkalyzer-core/src/profile_crypto.rs`,
  `rust/kafkalyzer-core/src/lib.rs`; bridge `rust/src/api/profile_crypto.rs`, `rust/src/api/mod.rs`; regenerated
  `lib/src/rust/**` and `test/src/rust/api/rust_mocks.mocks.dart`.
- Dart: `lib/src/services/settings_service.dart` (export/import), `lib/src/features/cluster/presentation/controllers/
  cluster_list_controller.dart` (export/import), `lib/src/features/settings/presentation/settings_view.dart` (shared
  export dialog, file names, import prompts), new `lib/src/services/encrypted_bundle.dart` and a passphrase dialog
  widget, ARB files (en + de).
- Dart API: `exportConfiguration(includeSensitiveCredentials:)` and `exportClustersZip(includeSecrets:)` become
  `encryptionPassphrase:`-based (credentials are included exactly when a passphrase is given). Internal callers and
  tests only.
- CI: build time of the bridge crate grows by the `age` dependency tree; checked on all three runners in the spike.
- **Prerequisites (implemented first):** `harden-local-storage-and-imports` (secret-free default for the cluster
  export, shared include-credentials dialog, zip-slip-safe import planner, merge-with-conflict import, imported
  secrets go to the keyring). `harden-read-only-gate` (dependency allowlist must stay green with `age`).

## Non-goals

- Key management, public-key (X25519/SSH) recipients, team password store (§5.7).
- Encrypting exports without credentials, or any other file the app writes (message exports, script runs, logs).
- ASCII-armored `age` files on import or export (binary format only).
- Passphrase strength meter, passphrase generation, remembering the passphrase.
- Packaging further files (PEM key/certificate files, Kerberos keytabs) into bundles; contents stay as defined by the
  prerequisite.
- MCP/headless profile export (§5.16) and the planned `kafkalyzer-profiles` crate.
