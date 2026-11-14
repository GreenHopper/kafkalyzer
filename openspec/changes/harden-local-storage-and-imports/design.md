# Design: harden-local-storage-and-imports

## Context

See `proposal.md` (Why) and the delta specs for the required behaviour. Observed state (code read, not executed):

- **Importers.** `ClusterListController.importClustersZip` writes `'${dir}/${entry.name}'` (string concat:
  `../` escapes, an absolute name stays inside by accident). `SettingsService.importConfiguration` writes
  `p.join(dir, name.substring('files/'.length))`: `../` escapes and an absolute remainder *replaces* the root, because
  `p.join` drops earlier parts. `ScriptRunner.importRunArchive` writes `'${baseDir}/$runId/${entry.name}'` with
  `runId` read unchecked from `run_manifest.json`. All three write entry by entry, so a bad last entry leaves earlier
  files on disk.
- **Stores.** `ClusterService.loadClusters` and `ScriptRepository.getScripts` return `[]` on any exception, and one bad
  entry fails the whole list. The next `saveClusters` / `saveScript` writes the in-memory list over the raw data.
  `SavedSearchesService` drops unreadable entries per entry and rewrites the list without them on save/delete.
  `RecentTopicsService` and `SessionRestoreService` behave similarly, but they hold regenerable data (non-goal).
- **Keyring.** `SecureStorageService.write/read` catch any error, set the sticky `_useFallback` flag and continue in
  memory. Nothing reports this. `saveClusterSecrets` returns normally either way, so the migration in
  `loadClusters` strips the plaintext (re-saves `sanitized()` profiles) even when every keyring write failed.
- **Config import secrets.** `exportConfiguration` exports every preference, including
  `credentials_migrated_to_keyring_v1`. With credentials included, the import therefore writes plaintext secrets into
  `cluster_profiles` and sets the migrated flag, so the migration never runs. `withSecrets` also prefers the local
  keyring value over the bundle value.
- **Names.** The name field validator only checks for empty input. Keyring keys are `cluster_<name>_<field>`. Both
  import paths replace a profile with the same name without asking, and the configuration import replaces the whole
  `cluster_profiles` value. Rename works today because the edited in-memory profile holds its secrets: `saveClusters`
  writes the new keys first, then deletes keys of names that are gone.
- **Run dirs.** `safeName` replaces `<>:"/\|?*` but keeps `..`. `runId = "${script.name}_$ts"` uses the raw name.
- **GCS.** `_gcsKeyFileName` / `_findGcsKeyFile` are a leftover from another project. Nothing else references them.

Constraints: Dart only, no new dependency (`archive` ^4.0.7 and `path` already present), stored formats unchanged,
UI via `package:material_ui/material_ui.dart` and `AppLocalizations` (en + de).

## Goals / Non-Goals

**Goals:** one shared validator for archive entry names; one shared pattern for "store unreadable" handling; an
explicit keyring status that UI and migration can rely on; testable pure functions for path checks, sanitising,
parsing and conflict merging.

**Non-Goals (design level):** no generic storage abstraction across all preferences, no keyring retry or recovery
within a session, no change to export contents except removing the GCS file, no Rust changes.

## Decisions

### D1 Archive safety: validate everything first, then extract

New pure helper `lib/src/utils/archive_safety.dart`:

- `String? safeArchiveTarget(String rootDir, String entryName)` returns the normalised target path, or `null` when
  the entry is unsafe. It rejects: an empty name; a leading `/` or `\`; a drive letter (`^[A-Za-z]:`); UNC paths; any
  `..` segment after splitting on both `/` and `\`; NUL bytes. It also requires
  `p.isWithin(rootDir, p.normalize(p.join(rootDir, name)))`. The check uses the `path` package's context for the
  current platform plus explicit checks for both separators, so the result does not depend on the host OS.
- `bool isSafePathSegment(String s)` checks archive-derived names such as `runId`.
- `Map<ArchiveFile, String> planArchiveExtraction(Archive a, String rootDir, {bool Function(String)? select})`
  throws `UnsafeArchiveEntryException(entryName)` on the first unsafe entry or symlink entry (`ArchiveFile.isSymbolicLink`,
  present in the locked archive 4.6.0). It checks every entry, including directory entries and entries the
  importer would otherwise ignore, and returns the write plan.
- Importers call the planner, and also validate `runId` / `preferences.json` / `clusters.json` content, **before** the
  first write. Only then do they write files and apply preferences/profiles.

Alternatives: (a) skip unsafe entries and import the rest. Rejected: the roadmap requires a full abort, and a partial
import hides tampering. (b) Extract to a temp dir and then move. Rejected: more I/O, and validating first already
gives all-or-nothing for the safety case. An I/O error halfway through extraction can still leave files behind, the
same as today; this is accepted (Risks).

### D2 Unreadable stores: parse per entry, keep raw entries, block on total failure

Shared helper `lib/src/services/stored_list.dart` (pure apart from the backup write):

- `StoredListParse<T>` holds `items`, `rawUnreadable` (a list of the original JSON values that failed to parse) and
  `storeUnreadable` (the top level is not a JSON list).
- Profiles and scripts: decode the top-level list, then parse each entry in its own try/catch. Unreadable entries
  are kept as raw `dynamic` JSON. On save, the encoder writes `readable entries ++ rawUnreadable`, so those entries
  survive. Script saves already re-read the store, so `ScriptRepository` keeps working on the raw list: it replaces
  the entry with the same `id` and appends otherwise.
- When the top level is unreadable, `StoredDataUnreadableException(store, backupPath?)` is thrown from load and from
  every save. The backup goes to `<applicationSupportDir>/backups/<key>-<yyyyMMdd-HHmmss>.json`, written once per
  session. If the backup write fails, `backupPath` is `null`. The raw preference value is never written by the app.
- `discardUnreadable()` (ClusterService/ScriptRepository) removes the preference key only after explicit
  confirmation in the UI, and only removes that key.
- `ClusterService.saveClusters` cleans up secrets only for names it could parse from the old list. It never deletes
  secrets of names that sit in raw unreadable entries (it extracts `name` from the raw map when present).
- Saved searches: the string list is kept. Unreadable strings are carried through unchanged on save and delete.

`ClusterListController` and `ScriptController` catch the exception and expose `StoreStatus`
(`ok | partiallyUnreadable(n) | unreadable(backupPath)`). The controllers also refuse mutations while the store is
`unreadable` and report an error. The headless runner already maps a thrown load error to exit code 3. Its message
names the unreadable store (task).

Alternatives: (a) back up and then overwrite anyway. Rejected: the roadmap says "nicht überschreiben". (b) Show
unreadable entries as placeholder tiles. Rejected for now: a count in the notice is enough and needs no new tile UI.

### D3 Keyring status is explicit

- `SecureStorageService` gets `final ValueNotifier<bool> unavailable` and the getter `isAvailable`. The existing
  sticky fallback stays: the first failure sets `unavailable.value = true`.
- `saveClusterSecrets` returns `Future<bool>`: `true` only if every write and delete reached the keyring.
  Existing callers that ignore the result keep compiling.
- Migration (`ClusterService.loadClusters`): for each profile with plaintext, call `saveClusterSecrets`. Strip the
  plaintext (re-save as `sanitized()`) only for profiles where it returned `true`. Keep the raw entry of the others,
  and set `credentials_migrated_to_keyring_v1` only if every profile succeeded. While plaintext remains, the
  in-session profile uses the plaintext values (`withSecrets` falls back to them).
- Config import: never apply `credentials_migrated_to_keyring_v1` from the bundle. Imported profiles go through the
  merge in D4 and `ClusterService.saveClusters`, which writes bundle secrets to the keyring (bundle values replace
  local keyring values) and stores only `sanitized()` JSON when the write succeeded. If it failed, the plaintext
  profile JSON is kept and the migration flag is cleared, which triggers the retry on the next start (spec:
  *Automatic Migration*).
- `saveClusters` with an unavailable keyring stores `sanitized()` JSON (no plaintext fallback). Secrets live in
  memory only, and the notice tells the user they are lost on exit.
- Rename (`saveClusters`): the order stays "write all current names, then delete removed names". Deletes run only
  when every write returned `true` (spec: *Secrets Follow A Profile Rename*).

Alternative: write secrets to an encrypted file when the keyring is missing. Rejected: it needs key management
(non-goal of §5.7), and the guidelines allow secrets only in the OS keyring.

### D4 Unique names and import conflicts

- `String normalizeProfileName(String n) => n.trim().toLowerCase()`. Pure, in `cluster_service.dart`. Case is ignored
  because keyring backends may compare keys case-insensitively (assumption, not verified per platform) and because
  users rarely mean "Prod" ≠ "prod".
- `ClusterBasicInfoForm` gets `existingNames` (all other profiles; when editing, the edited profile is excluded by
  index) and adds a validator error `clusterNameAlreadyUsed`. Saved names are trimmed.
- Pure function `mergeImportedProfiles(existing, imported, resolve)` with
  `resolve: Future<ImportConflictChoice?> Function(ClusterProfile imported, String suggestedName)`, where
  `ImportConflictChoice` is `replace | rename(newName) | skip`. A `null` result means cancel and aborts with no change.
  It returns the new list plus an `ImportSummary(imported, replaced, renamed, skipped)`. The suggested name is
  `"<name> (imported)"`, then `"(imported 2)"`, and so on, until unique. Duplicates inside one bundle are treated as
  conflicts against the already-merged list.
- `importClustersZip`, `importClusters` (JSON) and `SettingsService.importConfiguration` all use it. The UI passes a
  `resolve` callback that shows a Material dialog (`ImportConflictDialog`, three actions plus cancel, and an editable
  name for rename that is validated for uniqueness). The configuration import parses `cluster_profiles` from the
  bundle, merges, and saves through `ClusterService` instead of `prefs.setString` (behaviour change, see proposal).
  It refuses profile import while the local profile store is `unreadable`.
- Legacy duplicates: loading is unchanged. `StoreStatus` carries `duplicateNames`, and the notice lists them.

### D5 Sanitised run directory names

Pure helper `String safePathSegment(String name)` in `archive_safety.dart`. It replaces `<>:"/\|?*` and control
characters with `_`, trims trailing dots and spaces, and maps an empty result, `.` or `..` to `_`. Windows reserved
device names (`CON`, `NUL`, `COM1`, …) get a `_` prefix. `ScriptRunner` uses it for the script folder (three existing
`safeName` call sites plus the cleanup at ~1071) and for `runId = "${safePathSegment(script.name)}_$ts"`. The run
manifest keeps the original `scriptName`. Existing run folders with unsanitised names stay readable, because history
lists directories and does not rebuild names.

### D6 Notices

A single `StorageNoticeBanner` widget shows a `MaterialBanner` (from `package:material_ui/material_ui.dart`) at the
top of the content area in `main_layout.dart`. It listens to `SecureStorageService.unavailable`,
`ClusterListController.storeStatus` and `ScriptController.storeStatus`. Each issue gets icon + text (not colour
only), and when relevant "Show backup location" (copies the path) and "Discard unreadable data" (confirmation
dialog). The keyring notice has no dismiss action. The store notices disappear when the status returns to `ok`.
Saved-search unreadable entries are only logged (`logger`, no payload). They are preserved but not bannered, because
they are per-topic and minor (spec requires preservation only).

`PasswordFormField` reads `getIt<SecureStorageService>().isAvailable` and shows `Icons.warning_amber` with the tooltip
`passwordsNotPersistedTooltip` instead of the lock.

### D8 Cluster ZIP export scrubs secrets by default

`ClusterListController.exportClustersZip` serializes the in-memory profiles, which `withSecrets` filled from the
keyring. It gains an `includeSecrets` parameter (default `false`) and serializes `cluster.sanitized()` unless it is
`true`. The Settings export button opens the same include-credentials choice and security warning that the
configuration export already uses (`includeSensitiveCredentials` in `SettingsService`), reusing its dialog and ARB
keys. Keystore/truststore files stay in the bundle as today. Plain-JSON `exportClusters` gets the same parameter.
This restores *Safe Profile Export and Import Controls*; no delta.

### D7 Remove GCS key file export

Delete `_gcsKeyFileName`, `_findGcsKeyFile` and step "2. Handle GCS Key File". A test asserts the export contains only
`preferences.json` and `files/<configured keystore/truststore>` entries.

### Layering

Everything is Dart (`lib/src/utils`, `lib/src/services`, feature controllers/widgets). Nothing here is shared with a
second caller in Rust. Path validation of user archives is UI/IO glue, and the roadmap fixes this change as Dart
only. No bridge or DTO changes.

## Risks / Trade-offs

- [Valid exports from older versions contain names the new validator rejects] → The exporters only ever wrote
  `clusters.json`, `preferences.json`, `files/<basename>` and run files at root or subfolders. Tests import fixtures
  built like the current exporters.
- [I/O failure during extraction after validation leaves some files] → Same as today. Safety rejection happens before
  any write. Report the error, and accept it.
- [A blocked store frustrates users] → The notice offers an explicit discard with backup. The raw value can be
  restored by hand from the backup.
- [Sticky keyring fallback after a transient read error] → Accepted. The notice makes it visible, and a restart
  retries. Retry-in-session is out of scope.
- [Plaintext stays in preferences while the keyring is down] → Required by the roadmap (no data loss). The notice
  shows that passwords are not protected, and the migration retries on every start.
- [Case-insensitive uniqueness rejects existing case-variant pairs on next edit] → Only on save of a renamed or new
  profile. Existing pairs load and are reported as duplicates.
- [Config import changes from replace to merge] → Profiles not in the bundle survive, and their secrets are no longer
  orphaned. Called out in the proposal.

## Migration Plan

No data migration. Formats are unchanged, and the plaintext migration keeps its key. Rollback means reverting the
commit. Backups written to `backups/` are harmless for older versions.

## Open Questions

- Should the discard action also offer to open the backup folder through the existing file-opener service? Purely
  a UI convenience, deferrable.
