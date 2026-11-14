# Spec Delta

## ADDED Requirements

### Requirement: Unreadable Profile Store Is Reported And Preserved

When stored cluster profiles cannot be read, the system SHALL NOT present them as "no clusters" and SHALL NOT
overwrite them silently. A single unreadable profile SHALL NOT hide the readable ones and SHALL be kept unchanged on
the next save. If the whole store is unreadable, its raw content SHALL be backed up and saving profiles SHALL be
refused until the user explicitly discards the unreadable data.

#### Scenario: One corrupt profile among valid ones
- **WHEN** the stored profile list contains three profiles and the second one cannot be read
- **THEN** the two readable profiles SHALL be listed
- **AND** a notice SHALL state that one stored profile could not be read
- **AND** after the user adds a new profile, the stored data SHALL still contain the unreadable entry unchanged

#### Scenario: Whole profile store is corrupt
- **WHEN** the stored profile data is not a readable profile list (for example truncated JSON)
- **THEN** the application SHALL show a persistent notice that the stored profiles could not be read, including the location of a backup copy of the raw content
- **AND** the cluster list SHALL NOT show the empty-state "no clusters" message as if no profiles existed
- **AND** adding, editing, deleting or importing a profile SHALL be refused with an error message while the store is unreadable
- **AND** the raw stored content SHALL remain unchanged

#### Scenario: User discards the unreadable profile store
- **WHEN** the whole profile store is unreadable and the user chooses to discard it and confirms the warning
- **THEN** the application SHALL start with an empty profile list and allow saving again
- **AND** the backup copy SHALL be kept

#### Scenario: Backup cannot be written
- **WHEN** the whole profile store is unreadable and writing the backup copy fails
- **THEN** the notice SHALL state that no backup could be created
- **AND** the raw stored content SHALL remain unchanged

### Requirement: Unique Cluster Profile Names

Cluster profile names SHALL be unique, compared after trimming whitespace and ignoring letter case. The cluster
dialog SHALL reject a name that collides with another profile. Profiles with colliding names that already exist in
storage SHALL remain loadable and SHALL be reported.

#### Scenario: Creating a profile with an existing name
- **WHEN** a profile named "Prod" exists and the user saves a new profile named " prod "
- **THEN** the dialog SHALL show a validation error that the name is already used
- **AND** no profile and no keyring secret SHALL be changed

#### Scenario: Saving an edited profile under its own name
- **WHEN** the user edits profile "Prod" and saves it without changing its name
- **THEN** the save SHALL succeed

#### Scenario: Legacy duplicates in storage
- **WHEN** the stored profiles contain two profiles named "Prod" from an earlier version
- **THEN** both profiles SHALL be listed
- **AND** a notice SHALL state that profile names are duplicated and must be made unique
- **AND** saving either of them SHALL require a name that is unique

### Requirement: Name Conflicts On Profile Import Are Resolved By The User

When an imported profile has the same name as an existing profile, the system SHALL ask the user, per conflict, to
replace the existing profile, import the profile under a new unique name, or skip it. It SHALL NOT replace an existing
profile without that decision. Profiles not contained in the import SHALL be kept.

#### Scenario: Import with a conflicting name, user chooses rename
- **WHEN** the user imports a bundle containing profile "Prod" while a profile "Prod" exists and chooses "import as new name" with "Prod (imported)"
- **THEN** both profiles SHALL exist afterwards
- **AND** the existing "Prod" profile and its keyring secrets SHALL be unchanged

#### Scenario: Import with a conflicting name, user chooses skip
- **WHEN** the user chooses "skip" for a conflicting profile
- **THEN** the existing profile SHALL be unchanged and the imported one SHALL be discarded
- **AND** the result message SHALL report the number of imported and skipped profiles

#### Scenario: User cancels the conflict dialog
- **WHEN** the user cancels the conflict dialog
- **THEN** no profile SHALL be imported or changed

#### Scenario: Configuration import keeps profiles that are not in the bundle
- **WHEN** the user imports a configuration bundle containing profile "Test" while profiles "Prod" and "Test" exist
- **THEN** the conflict for "Test" SHALL be resolved by the user
- **AND** profile "Prod" SHALL still exist afterwards
