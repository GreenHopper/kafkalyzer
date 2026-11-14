# archive-import-safety Specification

## Purpose

Ensures that importing any zip archive validates every entry path and archive-derived identifier before creating directories or writing files, rejecting unsafe archives atomically.

## Requirements

### Requirement: Archive Extraction Rejects Unsafe Paths Before Writing

Before creating any destination directory or writing any file, every archive importer SHALL validate every entry in the archive against the intended destination directory. Entries whose target path is empty, absolute, contains a Windows drive or UNC prefix, contains `.` or `..` traversal segments, resolves outside the destination directory, or represents a symbolic link SHALL be rejected. Rejection SHALL abort the whole import with an error without creating directories, writing files, or modifying stored profiles or preferences.

#### Scenario: Cluster zip archive contains a traversal entry
- **WHEN** the user imports a cluster profile zip containing a valid `keystore.jks` entry and an entry named `../evil.txt`
- **THEN** the import SHALL fail with a user-visible error naming the rejected entry
- **AND** neither `evil.txt` nor `keystore.jks` SHALL be created on disk
- **AND** existing cluster profiles SHALL remain unchanged

#### Scenario: Configuration archive contains an absolute or drive-prefixed entry
- **WHEN** the user imports a configuration zip containing `files//etc/passwd` or `files/C:/evil.txt`
- **THEN** the import SHALL fail with an error without writing any file or overwriting any preference

#### Scenario: Script run archive contains an unsafe entry or run id
- **WHEN** the user imports a script run zip containing an entry whose resolved path escapes the script output directory, or whose manifest `runId` is not a single safe path segment
- **THEN** the import SHALL fail with an error without creating a run directory or extracting any entry

### Requirement: Archive-Derived Identifiers Are Single Safe Path Segments

Any directory or file name derived from archive metadata or a profile or script name during import SHALL be validated as a single safe path segment before use in a filesystem path.

#### Scenario: Run archive manifest carries a traversal run id
- **WHEN** a script run archive manifest declares `runId` as `../../other`
- **THEN** the import SHALL reject the archive before creating any directory or writing any file
