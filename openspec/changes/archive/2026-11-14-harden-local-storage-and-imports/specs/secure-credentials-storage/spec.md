# Spec Delta

## MODIFIED Requirements

### Requirement: Automatic Migration from Plaintext Storage

On first startup after upgrading, the system SHALL automatically scan stored cluster profiles for plaintext credentials, securely import any detected secret values into the OS keyring, and overwrite the plaintext values in local preferences. The same SHALL apply to plaintext credentials that arrive in local preferences through a configuration import. Plaintext values of a profile SHALL be removed only after all of that profile's secrets were written to the OS keyring; otherwise they SHALL be kept and the migration SHALL be retried on the next start.

#### Scenario: Migrating legacy plaintext profiles to OS Keyring

- **WHEN** an existing installation with plaintext cluster credentials launches
- **THEN** the system SHALL read the sensitive credential fields
- **AND** write each secret into the OS keyring under the corresponding profile key
- **AND** remove the plaintext secret fields from `SharedPreferences` on disk

#### Scenario: Keyring write fails during migration

- **WHEN** an installation with plaintext cluster credentials launches and writing to the OS keyring fails
- **THEN** the plaintext secret fields SHALL remain in local preferences unchanged
- **AND** the profiles SHALL still be usable with their credentials in this session
- **AND** the migration SHALL be attempted again on the next start
- **AND** the keyring-unavailable notice SHALL be shown

#### Scenario: Keyring fails for one of several profiles

- **WHEN** the keyring write succeeds for profile "A" and fails for profile "B" during migration
- **THEN** the plaintext secrets of "A" SHALL be removed and those of "B" SHALL be kept

#### Scenario: Imported configuration bundle with credentials

- **WHEN** the user imports a configuration bundle that contains credentials and the OS keyring is available
- **THEN** the imported credentials SHALL be written to the OS keyring, replacing older keyring values of the same profile
- **AND** no imported credential SHALL remain in plaintext in local preferences

### Requirement: Discrete Security Indicator in Cluster Dialog

The cluster configuration dialog SHALL display a subtle, non-intrusive security indicator (such as a lock icon or badge with tooltip) confirming that secret fields are protected by the OS keyring, without disrupting the existing dialog layout. When the OS keyring is unavailable, the indicator SHALL instead show a warning state that does not claim keyring protection and is distinguishable without colour.

#### Scenario: Viewing protected secret field

- **WHEN** the user inspects or edits password fields in the Cluster Configuration Dialog
- **THEN** a subtle lock indicator SHALL be visible alongside the credential section
- **AND** hovering or tapping the indicator SHALL show a tooltip stating "Protected by OS Keyring"

#### Scenario: Viewing secret fields while the keyring is unavailable

- **WHEN** the OS keyring is unavailable and the user opens the Cluster Configuration Dialog
- **THEN** the indicator SHALL show a warning icon instead of the lock
- **AND** its tooltip SHALL state that passwords are kept only until the application is closed

## ADDED Requirements

### Requirement: Unavailable Keyring Is Reported Persistently

When reading from or writing to the OS keyring fails, the system SHALL keep secrets only in memory for the rest of the
session, SHALL never write them to local preferences instead, and SHALL show a persistent notice that passwords are
not saved. The notice SHALL stay visible for the session and SHALL NOT disappear on its own.

#### Scenario: Keyring is locked or missing on startup
- **WHEN** the application starts and the OS keyring cannot be accessed
- **THEN** a persistent notice SHALL state that passwords are not saved and will be lost when the application is closed
- **AND** connecting with credentials entered in this session SHALL still work

#### Scenario: Saving a profile while the keyring is unavailable
- **WHEN** the keyring is unavailable and the user saves a profile with a SASL password
- **THEN** the password SHALL NOT be written to local preferences or any file
- **AND** the persistent notice SHALL be visible

#### Scenario: Keyring available
- **WHEN** keyring reads and writes succeed
- **THEN** no keyring-unavailable notice SHALL be shown

### Requirement: Secrets Follow A Profile Rename

When a profile is renamed, the system SHALL store its secrets under the new name and SHALL remove the secrets stored
under the old name only after all secrets under the new name were written to the OS keyring.

#### Scenario: Renaming a profile keeps its password
- **WHEN** the user renames profile "Prod" with a stored SASL password to "Prod EU" and restarts the application
- **THEN** profile "Prod EU" SHALL connect with the same SASL password without re-entry
- **AND** no secret SHALL remain stored under the name "Prod"

#### Scenario: Rename while the keyring is unavailable
- **WHEN** the keyring write for the new name fails during a rename
- **THEN** the secrets stored under the old name SHALL NOT be deleted from the OS keyring
- **AND** the keyring-unavailable notice SHALL be shown
