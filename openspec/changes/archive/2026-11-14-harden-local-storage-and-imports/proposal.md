# Proposal: harden-local-storage-and-imports

Source: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md`, §5.22 (change id `harden-local-storage-and-imports`),
motivated by the code-review findings A2, A3, A4, A5 and A7 in §2.4, under the guardrails of §1 (L1, L5).

## Why

Local data handling can silently destroy or leak user data: all three archive importers write entries outside their
target directory (zip-slip), an unreadable profile or script store looks like an empty list and is overwritten on the
next save, a failing OS keyring silently degrades to memory and the plaintext migration strips secrets even when the
keyring write failed, a foreign GCS key file is packed into configuration exports, and duplicate profile names make
two profiles share (and overwrite) one set of keyring secrets. This is phase 0a ("no silent data loss") and blocks
`cluster-profile-ergonomics` (§5.26) and `encrypted-profile-export` (§5.7).

## What Changes

- **Archive imports (A2):** the cluster-profile import, the configuration import and the script-run import validate
  every entry before writing anything. An entry whose resolved path leaves the target directory (`../`, absolute
  path, drive letter, UNC path, symbolic link) aborts the whole import with an error; nothing is written. The run
  directory name taken from a run manifest is validated the same way.
- **Unreadable stores (A3):** profiles, scripts and saved search presets are parsed entry by entry. A single unreadable
  entry no longer hides the others and is kept verbatim on the next save. If the whole store is unreadable, the raw
  content is copied to a backup file, the app shows a persistent notice, and saves to that store are refused until
  the user explicitly discards the unreadable data.
- **Keyring unavailable (A4):** the fallback to memory is reported as a persistent notice ("passwords are not saved");
  the lock indicator in the cluster dialog stops claiming keyring protection. Plaintext secrets (legacy profiles or
  an imported configuration bundle) are removed from local preferences only for profiles whose keyring write
  succeeded; otherwise they stay and the migration is retried on the next start.
- **Configuration import secrets (found while verifying A4):** an imported configuration bundle with credentials
  currently leaves those credentials in plaintext in local preferences (the source's migration flag is imported too)
  and stale local keyring values take precedence over the bundle. The import now moves them into the keyring under
  the same no-strip-on-failure rule. This fixes a deviation from the existing scenario *Authorized export reproduces
  complete profile authentication*.
- **Cluster ZIP export leaks secrets (found while verifying A4):** the cluster-list export in Settings serializes the
  in-memory profiles, which carry the secrets loaded from the keyring, so every exported bundle contains plaintext
  passwords and tokens without any prompt. The export now scrubs secrets by default and offers the same explicit,
  warned opt-in as the configuration export. The existing requirement *Safe Profile Export and Import Controls*
  already demands this, so no spec delta. Encryption of such bundles stays with §5.7.
- **GCS key file (A5):** the hard-coded GCS key file lookup and its inclusion in configuration exports are removed.
  No spec delta (removal of unspecified behaviour).
- **Unique profile names (A7):** profile names are unique (trimmed, case-insensitive). The cluster dialog rejects a
  colliding name. Importing a profile whose name already exists asks per conflict: replace, import under a new name,
  or skip. A rename moves the keyring secrets to the new name and deletes the old entries only after the new ones
  were stored.
- **Run directory names:** the per-run directory is built from the sanitised script name (no path separators,
  reserved characters, `.`/`..` or trailing dots/spaces), so a script name cannot place output outside the script
  output folder.

Read-only impact: no new Kafka or Schema Registry calls. All changes are local file, preference and keyring handling.
`scripts/check_read_only.sh` must pass unchanged.

## Capabilities

### New Capabilities
- `archive-import-safety`: validation of archive entries and archive-derived names before any file is written, with
  all-or-nothing abort for profile, configuration and script-run imports.

### Modified Capabilities
- `cluster-profile-persistence`: ADDED unreadable profile store is reported and preserved; ADDED unique profile names
  with conflict resolution on import.
- `secure-credentials-storage`: MODIFIED *Automatic Migration from Plaintext Storage* (strip only after a successful
  keyring write, also for imported bundles); MODIFIED *Discrete Security Indicator in Cluster Dialog* (warning state
  when the keyring is unavailable); ADDED keyring-unavailable notice; ADDED secrets follow a profile rename.
- `ergonomic-script-workspace`: ADDED unreadable script store is reported and preserved.
- `saved-topic-searches`: ADDED unreadable presets are preserved instead of being dropped on the next save.
- `unify-output-paths`: MODIFIED *Derived Script Output Path* (run directory built from the sanitised script name).

## Impact

- Dart only (§5.22 "Schichten: nur Dart"); no Rust, no bridge regeneration, no new dependency (`archive` and `path`
  are already dependencies).
- Affected code: `lib/src/features/cluster/presentation/controllers/cluster_list_controller.dart`,
  `lib/src/services/settings_service.dart`, `lib/src/features/scripting/presentation/controllers/script_runner.dart`,
  `lib/src/services/cluster_service.dart`, `lib/src/services/secure_storage_service.dart`,
  `lib/src/features/scripting/data/script_repository.dart`, `lib/src/services/saved_searches_service.dart`,
  `lib/src/features/cluster/presentation/widgets/config_dialog/{cluster_basic_info_form,password_form_field}.dart`,
  `lib/src/features/settings/presentation/settings_view.dart`, `lib/src/ui/main_layout.dart`, ARB files (en, de).
- Behaviour change: the configuration import merges cluster profiles through the conflict resolution instead of
  replacing the whole profile list; other preferences keep restore semantics.
- Stored data stays loadable: existing duplicate names are loaded unchanged and reported; no storage format changes.
- Prerequisites: none. Unlocks §5.26 `cluster-profile-ergonomics` (unique names) and §5.7 `encrypted-profile-export`.

## Non-goals

- Encrypted profile export (§5.7 `encrypted-profile-export`). This change only restores the specified default
  (no secrets without explicit, warned opt-in).
- Profile UX: duplicate, environment tags, filtering, `client.properties` import (§5.26 `cluster-profile-ergonomics`).
- Migrating other name-keyed data (saved search presets, tab sessions, recent topics, script step cluster names) on a
  profile rename; per-cluster sessions are B13 in §5.26.
- Corruption handling for recent-topic history and tab sessions (regenerable caches, capped, no user-authored data).
- Archive size limits / zip-bomb protection; log file handling (§5.25).
