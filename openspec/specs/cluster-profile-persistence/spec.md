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

The system SHALL allow exporting cluster profiles to a configuration bundle, supporting both sanitized exports with sensitive credentials excluded and passphrase-encrypted exports with credentials included, restoring configurations accurately upon import without dropping existing profiles that are absent from the bundle.

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
- **WHEN** the user explicitly exports a cluster profile including credentials with a passphrase and imports the encrypted bundle into another installation with the same passphrase
- **THEN** the imported profile SHALL carry all connection parameters, certificates, and credentials
- **AND** the imported credentials SHALL be written to the destination machine's native OS keyring

#### Scenario: Encrypted import that cannot be decrypted changes nothing
- **WHEN** the user imports an encrypted bundle and decryption fails because of a wrong passphrase or a damaged file
- **THEN** the stored profiles and their keyring secrets SHALL be unchanged
- **AND** the user SHALL see an error message instead of a success message

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

### Requirement: Duplicate a Cluster Profile Including Secrets

The Settings cluster list SHALL offer a "Duplicate" action per profile. It SHALL open the cluster dialog with a copy of every field, including secrets, the environment tag, the TLS verification state and additional properties, under a suggested unique name. On save, the copy's secrets SHALL be stored in the OS keyring under the new name. The source profile and its secrets SHALL stay unchanged.

#### Scenario: Duplicating a SASL profile
- **WHEN** the user duplicates profile "orders-prod" that uses SASL SCRAM with a stored password and saves the dialog unchanged
- **THEN** a profile "orders-prod (copy)" SHALL exist with the same mechanism, username and password
- **AND** after an application restart both profiles SHALL connect without re-entering a password

#### Scenario: Suggested name is unique
- **WHEN** profiles "orders-prod" and "orders-prod (copy)" exist and the user duplicates "orders-prod"
- **THEN** the suggested name SHALL be "orders-prod (copy 2)"

#### Scenario: Cancelled duplicate
- **WHEN** the user cancels the dialog opened by "Duplicate"
- **THEN** no profile and no keyring entry SHALL be created

#### Scenario: Copy is independent
- **WHEN** the user changes the password of the copy and saves
- **THEN** the source profile SHALL keep its original password

#### Scenario: Keyring unavailable while duplicating
- **WHEN** the OS keyring is unavailable and the user saves a duplicate
- **THEN** the copy SHALL be created and the existing "passwords are not saved" notice SHALL apply to it

### Requirement: Allowlisted Additional Client Properties

A profile SHALL be able to store additional Kafka client properties. Only keys on a fixed positive allowlist SHALL be applied to a connection, and only with a value of the allowed type and range. Keys outside the allowlist SHALL never reach the Kafka client, whatever their source (dialog, stored data, import). The allowlist SHALL contain no key that can write, commit, join a group, enable transactions or idempotence, create topics, run commands, load plugins, or change TLS or SASL settings.

#### Scenario: Allowed property is applied
- **WHEN** a profile carries `client.id=kafkalyzer-alice` and the user connects
- **THEN** the Kafka client SHALL use `kafkalyzer-alice` as its client id

#### Scenario: Forbidden property in imported or stored data
- **WHEN** an imported profile bundle contains additional properties `enable.auto.commit`, `transactional.id`, `allow.auto.create.topics`, `group.instance.id` or `enable.ssl.certificate.verification` and the user connects
- **THEN** none of these keys SHALL be passed to the Kafka client
- **AND** the cluster dialog SHALL mark them as not allowed when the profile is opened

#### Scenario: Properties set by the application win
- **WHEN** a profile carries an allowlisted property
- **THEN** the consumer settings the application fixes for read-only operation (manual assignment, auto-commit off, partition EOF, fetch limits) SHALL be unchanged

#### Scenario: Additional properties survive restart and export
- **WHEN** the user saves a profile with additional properties, restarts the application, and exports and imports the profile
- **THEN** the additional properties SHALL be unchanged after the restart and after the import

#### Scenario: Read-only operation preserved
- **WHEN** any combination of allowlisted properties is applied
- **THEN** the connection SHALL issue only the same read-only requests as without additional properties
