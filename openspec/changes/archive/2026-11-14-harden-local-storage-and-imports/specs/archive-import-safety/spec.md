# Spec Delta

## Purpose

Ensures that importing a ZIP archive (cluster profiles, application configuration, script runs) can never create,
overwrite or link files outside the import's target directory, and that a rejected archive leaves no partial state.

## ADDED Requirements

### Requirement: Archive Entries Stay Inside The Target Directory

Before writing any file, every archive import SHALL check every entry. An entry whose name is absolute (root, drive
letter, UNC), contains a `..` segment with either separator, or otherwise resolves outside the target directory, and
any symbolic-link entry, SHALL make the archive unsafe. This applies to the cluster-profile, configuration and
script-run imports.

#### Scenario: Entry with parent-directory traversal is rejected
- **WHEN** the user imports a cluster-profile archive containing an entry named `../../evil.sh`
- **THEN** the import SHALL be aborted with an error stating that the archive contains an unsafe entry and naming it
- **AND** no file SHALL be created or changed outside or inside the target directory

#### Scenario: Entry with an absolute path is rejected
- **WHEN** the user imports a configuration archive containing an entry named `files//etc/cron.d/evil` or `files/C:\Windows\evil.dll`
- **THEN** the import SHALL be aborted with the unsafe-entry error
- **AND** no file SHALL be written

#### Scenario: Backslash traversal is rejected on every platform
- **WHEN** the user imports a script-run archive containing an entry named `..\..\evil.txt`
- **THEN** the import SHALL be aborted with the unsafe-entry error on Linux, macOS and Windows alike

#### Scenario: Valid archive still imports
- **WHEN** the user imports an archive produced by the application's own export that contains only entries below the target directory
- **THEN** the import SHALL succeed and write the same files as before this change

### Requirement: Unsafe Archives Are Rejected Without Partial Changes

An archive import SHALL be all-or-nothing with respect to safety: when any entry is unsafe, the import SHALL write no
files, change no stored profiles, preferences or script runs, and report the failure to the user instead of
completing silently or partially.

#### Scenario: Unsafe entry after valid entries
- **WHEN** a configuration archive contains a valid `preferences.json`, a valid `files/truststore.jks` and, as last entry, `files/../../evil`
- **THEN** neither the truststore file nor any preference SHALL be written
- **AND** the stored cluster profiles SHALL be unchanged
- **AND** the user SHALL see an error message instead of a success message

#### Scenario: Corrupt archive
- **WHEN** the selected file is not a readable ZIP archive
- **THEN** the import SHALL fail with an error message and SHALL NOT change any stored data

### Requirement: Names Derived From Archive Content Are Validated

A directory or file name that an import takes from archive content (for example the run identifier in a script-run
manifest) SHALL be a single path segment that stays inside the target directory; otherwise the import SHALL be
rejected like an unsafe entry.

#### Scenario: Run manifest with traversal identifier
- **WHEN** the user imports a script-run archive whose manifest declares the run id `../../../outside`
- **THEN** the import SHALL be aborted with the unsafe-entry error
- **AND** no run directory SHALL be created
