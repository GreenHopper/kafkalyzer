# cluster-profile-persistence Specification

## Purpose

Defines how a Kafka cluster profile is stored and restored locally, so that every configured connection, security and Schema Registry setting survives application restarts and profile export/import.

## Requirements

### Requirement: Complete Cluster Profile Round Trip

The system SHALL store and restore every configured field of a cluster profile without loss, delegating sensitive credentials (passwords, tokens) to secure OS keyring storage and non-sensitive connection attributes to local configuration storage.

#### Scenario: Kerberos profile survives an application restart
- **WHEN** the user saves a cluster profile configured with SASL GSSAPI (service name, keytab path, principal, krb5.conf path) and restarts the application
- **THEN** the profile SHALL be listed with all four Kerberos values unchanged
- **AND** connecting to that cluster SHALL use the same rdkafka options as before the restart

#### Scenario: PEM mTLS and Schema Registry credentials survive an application restart
- **WHEN** the user saves a cluster profile with PEM client certificate, private key, private key password, and Schema Registry username and password, then restarts the application
- **THEN** the reloaded profile SHALL contain the same certificate, key, password and Schema Registry credential values resolved transparently
- **AND** the mTLS broker connection and the Schema Registry basic-auth connection SHALL succeed without re-entering any value

#### Scenario: Editing one field preserves the remaining security settings
- **WHEN** the user opens an existing profile that uses SASL SCRAM and changes only the bootstrap server list
- **THEN** the saved profile SHALL keep the mechanism, username, password and all other previously configured fields unchanged

### Requirement: Stored Profiles Survive Configuration Export And Import

The system SHALL allow exporting cluster profiles to a configuration bundle, supporting both sanitized exports with sensitive credentials excluded and explicit authorized exports with credentials included, restoring configurations accurately upon import without dropping existing profiles that are absent from the bundle.

#### Scenario: Import reproduces the source profile authentication
- **WHEN** the user exports the configuration of a cluster profile that uses an enterprise SASL mechanism and imports the bundle into a fresh installation
- **THEN** the imported profile SHALL carry the same mechanism, credentials and certificate paths as the exported profile
- **AND** a connection test against the cluster SHALL produce the same result as on the source installation

#### Scenario: Configuration import preserves existing profiles not in the bundle
- **WHEN** the user has profile "Prod" configured and imports a configuration bundle containing only profile "Test"
- **THEN** both "Prod" and "Test" SHALL be present after the import

#### Scenario: Sanitized export omits passwords for safe sharing
- **WHEN** a cluster profile is exported using the default safe export mode
- **THEN** connection parameters and non-sensitive options SHALL be present in the bundle
- **AND** sensitive password and token fields SHALL be excluded from the archive

#### Scenario: Authorized export reproduces complete profile authentication
- **WHEN** the user explicitly exports a cluster profile including credentials and imports the bundle into another installation
- **THEN** the imported profile SHALL carry all connection parameters, certificates, and credentials
- **AND** the imported credentials SHALL be written to the destination machine's native OS keyring

### Requirement: Unique Profile Names

Cluster profile names SHALL be unique after trimming leading and trailing whitespace and comparing case-insensitively. Creating or editing a profile to match another existing profile's normalized name SHALL be rejected in the configuration form. Existing installations that already contain duplicate names SHALL surface a notice asking the user to rename the duplicates.

#### Scenario: Duplicate name rejected in configuration form
- **WHEN** a profile named "Prod" exists and the user enters " prod " for a new profile
- **THEN** the form SHALL show a validation error and refuse to save

#### Scenario: Editing a profile without changing its name is allowed
- **WHEN** the user opens an existing profile named "Prod" and edits its bootstrap servers without renaming it
- **THEN** validation SHALL allow saving the update

#### Scenario: Legacy duplicate names trigger a warning
- **WHEN** the application loads a stored profile list containing two profiles whose normalized names match
- **THEN** both profiles SHALL remain accessible and a persistent notice SHALL list the duplicate names

### Requirement: Import Conflict Resolution

When importing cluster profiles (from JSON, cluster zip, or configuration bundle), every normalized name collision against an existing profile or an earlier entry in the same import SHALL prompt the user to choose Replace, Rename (with an editable unique name), Skip, or Cancel.

#### Scenario: User chooses Skip on a conflicting profile
- **WHEN** profile "Prod" exists with keyring credentials and an import bundle also contains "prod"
- **AND** the user chooses Skip
- **THEN** the existing "Prod" profile and its keyring credentials SHALL remain unchanged

#### Scenario: User chooses Rename on a conflicting profile
- **WHEN** profile "Prod" exists and an import bundle contains "Prod"
- **AND** the user chooses Rename with "Prod (imported)"
- **THEN** both "Prod" and "Prod (imported)" SHALL exist after the import with their own credentials

#### Scenario: User cancels during conflict resolution
- **WHEN** the user chooses Cancel in the conflict dialog
- **THEN** the import SHALL abort without modifying existing profiles or keyring entries

### Requirement: Unreadable Profile Store Is Reported And Preserved

When stored cluster profiles cannot be read, the system SHALL NOT present them as an empty profile list and SHALL NOT overwrite them silently. Unreadable individual entries SHALL be skipped during load and preserved verbatim on subsequent saves; if the whole profile store is unreadable, the system SHALL write a backup copy of the raw data, show a persistent notice with the backup location and an explicit discard action, and refuse profile mutations until discarded.

#### Scenario: One corrupt entry alongside valid profiles
- **WHEN** the stored profile list contains two valid profiles and one malformed entry
- **THEN** the two valid profiles SHALL be loaded and usable
- **AND** a notice SHALL report that one stored profile entry could not be read
- **AND** saving an edit to one of the valid profiles SHALL preserve the malformed entry unchanged

#### Scenario: Whole profile store is corrupt JSON
- **WHEN** the stored profile data is truncated or not a JSON array
- **THEN** the application SHALL display a persistent notice stating that saved cluster profiles could not be read and showing the backup file path
- **AND** adding, editing, deleting, or importing profiles SHALL be refused with an error message
- **AND** the raw stored preference value SHALL remain unchanged

#### Scenario: User confirms discarding the unreadable profile store
- **WHEN** the whole profile store is unreadable and the user selects "Discard unreadable data" and confirms
- **THEN** the unreadable preference SHALL be cleared, saving new profiles SHALL succeed, and the backup file SHALL remain on disk

#### Scenario: Headless run with an unreadable profile store
- **WHEN** a headless script run looks up a cluster profile and the profile store is unreadable
- **THEN** the run SHALL fail with an error stating that cluster profiles could not be read, not that the profile was not found
- **AND** the process SHALL exit with a non-zero status
