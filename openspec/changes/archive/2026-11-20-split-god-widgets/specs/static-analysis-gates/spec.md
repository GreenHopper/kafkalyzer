# Spec Delta

## Purpose

Keeps source files small enough to review, by failing any change that pushes a hand-written source file past the agreed size limit while leaving already oversized files editable so unrelated work is not blocked.

## ADDED Requirements

### Requirement: Source File Size Guard For Changed Sources

The quality gate SHALL check the size of hand-written Dart sources under the application source tree, and SHALL fail a change that takes such a file from at or below the agreed size limit to above it, or that adds a new hand-written Dart source above the limit. Files already above the limit at the merge base of the change SHALL stay editable without failing the check, and generated sources SHALL be exempt.

#### Scenario: Change grows a source file past the limit

- **WHEN** a change modifies a hand-written Dart source that was at or below the size limit at the merge base and leaves it above the limit
- **THEN** the quality gate SHALL fail and name the file with its line count and the limit

#### Scenario: Change adds an oversized new source file

- **WHEN** a change adds a new hand-written Dart source that is above the size limit
- **THEN** the quality gate SHALL fail and name the new file with its line count and the limit

#### Scenario: Unrelated work continues in an already oversized file

- **WHEN** a change modifies a hand-written Dart source that was already above the size limit at the merge base
- **THEN** the quality gate SHALL report no finding for that file, so long as the change does not take another file over the limit

#### Scenario: Oversized file is split

- **WHEN** a change splits an oversized source file into several files that are each at or below the limit
- **THEN** the quality gate SHALL report no finding for any of them

#### Scenario: Generated source is large

- **WHEN** the only file above the limit is produced by a checked-in generator or by code generation
- **THEN** the quality gate SHALL report no finding for that file

### Requirement: Size Guard Carries No Exception List

The source file size guard SHALL decide its verdict from the checked-out revision and the merge base of the change alone. It SHALL NOT read a committed baseline, allowlist or ratchet file, and SHALL NOT be silenced by a project-wide configuration switch.

#### Scenario: Contributor tries to exempt a file by editing a list

- **WHEN** keeping the gate green would require adding the file name to a committed exception list
- **THEN** that approach SHALL be considered non-conforming to this capability, and the change SHALL split the file or leave it below the limit

#### Scenario: Merge base is unavailable

- **WHEN** the version control history needed to compare the change against its merge base is not available to the gate
- **THEN** the guard SHALL fail with a tooling error naming the missing revision information
- **AND** it SHALL NOT report success for the checked-out sources
