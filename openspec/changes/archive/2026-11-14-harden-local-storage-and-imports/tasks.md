# Tasks

All work is Dart (no Rust crate, no bridge change). Run `flutter test <file>` after every task that names a test.

## 1. Archive safety helpers

- [x] 1.1 Create `lib/src/utils/archive_safety.dart` with `safeArchiveTarget`, `isSafePathSegment`,
      `safePathSegment`, `planArchiveExtraction` and `UnsafeArchiveEntryException` (design D1, D5); verify with
      `test/src/utils/archive_safety_test.dart` covering `../x`, `a/../../x`, `..\x`, `/etc/x`, `\x`, `C:\x`, `C:x`,
      `\\server\share\x`, empty name, NUL byte, symlink entry (`ArchiveFile.symlink`), valid `files/a.jks` and nested
      `step1/out.json`, and `safePathSegment` for `..`, `.`, `""`, `a/b`, `name. `, `CON`, `My Test Script` →
      `My_Test_Script`
- [x] 1.2 Verify `planArchiveExtraction` checks directory entries and ignored entries too and throws before returning
      any plan (unit test: unsafe entry placed last after valid ones)

## 2. Safe archive importers

- [x] 2.1 `ClusterListController.importClustersZip`: plan all entries with `planArchiveExtraction` before writing,
      write only planned targets, and surface `UnsafeArchiveEntryException` to the caller; verify with
      `test/src/features/cluster/presentation/controllers/cluster_list_controller_import_test.dart`: a zip with
      `../evil.txt` and a zip with an absolute entry `/tmp/evil.txt` both throw, write no file inside or outside the
      temp target dir, and leave stored profiles unchanged
- [x] 2.2 `SettingsService.importConfiguration`: validate all `files/` entries and parse `preferences.json` before
      writing any file or preference; verify in `test/src/services/settings_service_test.dart`: zips with
      `files/../../evil` and with `files//abs/evil` (absolute after prefix strip) and `files/C:\evil` throw, write no
      file, and leave every preference unchanged; the existing import tests still pass
- [x] 2.3 `ScriptRunner.importRunArchive`: validate the manifest `id` (or zip-name fallback) with `isSafePathSegment`
      and all entries with `planArchiveExtraction` before creating the run dir; verify in
      `test/src/features/scripting/presentation/controllers/script_runner_test.dart`: zips with `../evil.txt`, with
      an absolute entry, and with manifest id `../../outside` throw and create no directory; a zip produced by
      `exportRunArchive` round-trips
- [x] 2.4 Show the unsafe-archive error in the three import UIs (settings cluster import, configuration import,
      script history import) through the existing error SnackBar with the new ARB key `importRejectedUnsafeEntry`
      (en + de, placeholder `entry`); verify with `flutter gen-l10n` (or build) and a widget test on one import path

## 3. Sanitised script run directories

- [x] 3.1 Replace the four `safeName` constructions in `script_runner.dart` with `safePathSegment(script.name)` and
      build `runId` as `"${safePathSegment(script.name)}_$timestamp"` while the manifest keeps `scriptName`
      unchanged; verify with a `script_runner_test.dart` case for the names `../../reports/x` and `..` asserting that the
      run directory is inside `<output>/<sanitised>` and that "My Test Script" still maps to `My_Test_Script`

## 4. Keyring status, migration and rename

- [x] 4.1 `SecureStorageService`: add `ValueNotifier<bool> unavailable` + `isAvailable`, set on the first read/write/
      delete failure, and make `saveClusterSecrets` return `Future<bool>` (true only if every operation reached the
      keyring); verify in `test/src/services/secure_storage_service_test.dart` with a throwing `FlutterSecureStorage`
      mock
- [x] 4.2 `ClusterService.loadClusters` migration: strip plaintext only for profiles whose `saveClusterSecrets`
      returned true, keep the raw entries of the others, and set `credentials_migrated_to_keyring_v1` only when all
      succeeded; verify in `test/src/services/cluster_service_test.dart`: (a) keyring write throws → stored
      `cluster_profiles` still contains the plaintext, the flag is not set, and the loaded profile has its password;
      (b) failure for profile B only → A stripped, B kept; (c) the existing happy-path migration test still passes
- [x] 4.3 `ClusterService.saveClusters`: delete secrets of removed/renamed names only when all writes returned
      true; never write secrets into preferences; verify with tests: rename "Prod"→"Prod EU" moves the secrets and
      removes the old keys; with the keyring failing, the old keys are not deleted and the stored JSON has no secret
- [x] 4.4 Configuration import secrets: ignore `credentials_migrated_to_keyring_v1` from the bundle and save
      imported profiles through `ClusterService` so bundle secrets replace keyring values; if the keyring fails, keep
      the plaintext JSON and clear the migration flag; verify in `settings_service_test.dart`: an import with
      credentials leaves no secret in `cluster_profiles` and overrides a stale keyring value; with a failing keyring,
      the plaintext is kept and the flag is false

## 5. Unreadable stores are preserved

- [x] 5.1 Create `lib/src/services/stored_list.dart` (`StoredListParse`, `StoredDataUnreadableException`, backup
      writer to `<appSupport>/backups/<key>-<timestamp>.json`, `StoreStatus`); verify with
      `test/src/services/stored_list_test.dart` (per-entry parse, raw entries carried through, backup file content
      equals the raw value, backup failure → `backupPath == null`)
- [x] 5.2 `ClusterService`: per-entry parse, re-save `readable ++ rawUnreadable`, throw on an unreadable top level
      from load and save, add `discardUnreadable()`, and skip secret cleanup for names in raw entries; verify with
      tests: a corrupt second entry → two profiles loaded, the entry kept after `saveClusters`; truncated JSON → load
      throws, `saveClusters` throws, the preference is byte-identical, and a backup file exists
- [x] 5.3 `ScriptRepository`: same pattern on the raw list (replace by `id`, append otherwise, keep unreadable
      entries), add `discardUnreadable()`; verify with `test/src/features/scripting/data/script_repository_test.dart`
      (corrupt entry preserved across `saveScript` and `deleteScript`; corrupt store → load and save throw, data
      unchanged)
- [x] 5.4 `SavedSearchesService`: keep unreadable strings on `savePreset` / `deletePreset` / `updatePreset`; verify
      in `test/src/services/saved_searches_service_test.dart`
- [x] 5.5 `ClusterListController` and `ScriptController`: catch `StoredDataUnreadableException`, expose
      `storeStatus` (including legacy duplicate names for profiles), refuse add/update/delete/import/create/duplicate
      while `unreadable` with an error, and do not show the empty state then; add `discardUnreadable()`; verify with
      controller unit tests
- [x] 5.6 Headless runner: when the script or cluster store is unreadable, print "script store could not be read" /
      "cluster profiles could not be read" (not "not found") and exit non-zero; verify in
      `test/src/features/scripting/headless_script_runner_test.dart`

## 6. Unique profile names and import conflicts

- [x] 6.1 Add `normalizeProfileName` and the pure `mergeImportedProfiles(existing, imported, resolve)` returning the
      merged list + `ImportSummary` (design D4); verify with unit tests for replace, rename (suggested names
      `(imported)`, `(imported 2)`), skip, cancel (`null` → no change), duplicates inside one bundle, and
      case/whitespace-insensitive matching
- [x] 6.2 `ClusterBasicInfoForm`: add the `existingNames` parameter and a validator using `normalizeProfileName`
      (excluding the edited profile), and trim the saved name; wire it from the create/edit call sites in
      `settings_view.dart` and `explorer_view.dart`; add ARB key `clusterNameAlreadyUsed` (en + de); verify with a
      widget test (" prod " rejected when "Prod" exists; editing "Prod" without rename accepted)
- [x] 6.3 `ImportConflictDialog` (material_ui, three actions + cancel, editable unique name for rename) and ARB keys
      `importConflictTitle`, `importConflictMessage`, `importConflictReplace`, `importConflictRename`,
      `importConflictSkip`, `importSummary` (en + de); verify with a widget test per action
- [x] 6.4 Route `importClustersZip`, `importClusters` and `SettingsService.importConfiguration` (cluster profiles
      only) through `mergeImportedProfiles` with a `resolve` callback supplied by the UI; profiles not in the bundle
      stay; refuse profile import while the store is unreadable; show `importSummary` in the success SnackBar;
      regenerate mocks with `dart run build_runner build` (settings/explorer view test mocks); verify with tests that
      a conflicting import with "skip" leaves the existing profile and its keyring secrets unchanged and that
      configuration import keeps "Prod" when the bundle only has "Test"

## 7. Remove GCS key file from configuration export

- [x] 7.1 Delete `_gcsKeyFileName`, `_findGcsKeyFile` and the GCS export step in `settings_service.dart`; verify with
      a `settings_service_test.dart` case where a file with the old name exists in the support dir and the exported
      zip contains only `preferences.json` and the configured `files/` keystore/truststore entries

- [x] 7.2 Add `includeSecrets` (default `false`) to `ClusterListController.exportClustersZip` and `exportClusters`;
      serialize `cluster.sanitized()` unless it is `true`; in `settings_view.dart` show the existing
      include-credentials choice with security warning before the cluster export (reuse the configuration export
      dialog and ARB keys); verify with a test that a default export of a profile with SASL password, OAuth token,
      PEM key password and Schema Registry password contains none of them, and that an opt-in export after
      confirmation contains all of them

## 8. Notices and keyring indicator

- [x] 8.1 `StorageNoticeBanner` in `lib/src/ui/` shown by `main_layout.dart`: keyring-unavailable (no dismiss),
      profile/script store unreadable (with backup location or "no backup", "Copy backup path", and "Discard
      unreadable data" with a confirmation dialog), partially unreadable count, and duplicate profile names; icon +
      text, tooltips and semantic labels; ARB keys `keyringUnavailableNotice`, `profileStoreUnreadableNotice`,
      `scriptStoreUnreadableNotice`, `storeBackupLocation`, `storeBackupFailed`, `storePartiallyUnreadable`,
      `duplicateProfileNamesNotice`, `discardUnreadableData`, `discardUnreadableConfirm`, `copyBackupPath`,
      `storeUnreadableActionRefused` (en + de); verify with widget tests for each state and for the hidden banner when
      everything is ok
- [x] 8.2 `PasswordFormField`: when `SecureStorageService.isAvailable` is false, show a warning icon with tooltip
      `passwordsNotPersistedTooltip` (en + de) instead of the lock; verify with a widget test for both states

## 9. Final verification

- [x] 9.1 Confirm that `git diff --stat rust/` is empty (so cargo fmt/clippy/test and bridge regeneration are not
      needed) and that `dart format --output=none --set-exit-if-changed lib test` passes
- [x] 9.2 Run `flutter analyze` with no new issues and `flutter test` all green
- [x] 9.3 Run `scripts/check_read_only.sh` and confirm it passes unchanged (no new Kafka or Schema Registry calls)
- [ ] 9.4 Manual smoke on Linux: import a crafted `../` zip in each of the three importers (rejected, nothing
      written); corrupt `cluster_profiles` in the preferences file (banner shown, data untouched, backup present); run
      without a Secret Service (banner shown, plaintext not stripped)
