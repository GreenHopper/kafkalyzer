# Spec Delta

## Purpose

Lets the user hand selected cluster connections to headless kafkalyzer binaries such as the local MCP server, one
profile at a time, without storing secrets in plain text and without exposing profiles that were not shared.

## ADDED Requirements

### Requirement: Per-Profile Sharing Setting

The Settings cluster list SHALL offer, for every cluster profile, a setting that shares the profile with headless
kafkalyzer binaries. The setting SHALL be off for every new and every existing profile until the user switches it
on, and SHALL keep its state across application restarts and profile edits, including a rename.

#### Scenario: Existing profiles after upgrade

- **WHEN** the application starts for the first time after the upgrade with stored profiles
- **THEN** no profile SHALL be shared

#### Scenario: Sharing survives restart and rename

- **WHEN** the user shares profile "orders-test", renames it to "orders-int" and restarts the application
- **THEN** "orders-int" SHALL be shown as shared
- **AND** no profile named "orders-test" SHALL be shared

#### Scenario: Shared profiles are recognisable in the list

- **WHEN** the cluster list shows a shared profile
- **THEN** the row SHALL carry a marker made of an icon and a text label, not of colour alone

### Requirement: Data Flow Warning Before Sharing

The control that switches sharing on SHALL be shown together with a warning, as text with an icon, stating that
message keys, payloads, headers and cluster metadata read by an MCP client can be sent to the provider of the
language model that the client uses, and that the user is responsible for sharing a production cluster.

#### Scenario: Warning is visible before the switch is used

- **WHEN** the user opens the sharing dialog of a profile that is not shared
- **THEN** the warning SHALL be visible without any further action before the switch can be operated

#### Scenario: Production-tagged profile

- **WHEN** the user opens the sharing dialog of a profile with a production environment tag
- **THEN** the dialog SHALL show the environment tag next to the profile name
- **AND** sharing SHALL remain possible

### Requirement: Shared Profile File Without Secrets

The system SHALL write every shared profile, and no other profile, to one file in the current user's configuration
directory. The file SHALL contain the non-secret connection settings, the environment tag, the TLS verification
state and the allowlisted additional client properties, and SHALL NOT contain any password, token or key password.
On systems with file permissions the file SHALL be readable and writable by its owner only.

#### Scenario: Shared SASL profile

- **WHEN** the user shares a profile that uses SASL SCRAM with a password and a Schema Registry password
- **THEN** the file SHALL list the profile with its bootstrap servers, mechanism, user names and Schema Registry URL
- **AND** the file SHALL contain neither password

#### Scenario: Profile that is not shared

- **WHEN** two profiles exist and only one is shared
- **THEN** the file SHALL NOT mention the other profile's name, servers or user names

#### Scenario: File cannot be written

- **WHEN** the user switches sharing on and the configuration directory is not writable
- **THEN** the application SHALL report that sharing failed, with the reason
- **AND** the profile SHALL be marked as "sharing failed", not as shared

### Requirement: Shared Secrets In A Dedicated Keyring Service

The secrets of a shared profile SHALL be stored in the operating system keyring under a service name used only for
shared profiles, separate from the entries the application uses for itself. A profile SHALL appear in the shared
file only when all of its secrets were stored. The shared file SHALL record which secrets belong to a profile, so
that a reader can tell a missing secret from a secret that was never configured.

#### Scenario: Secrets are available to a headless reader

- **WHEN** the user shares a profile with a SASL password and a headless binary of the same user reads the shared
  profiles
- **THEN** the reader SHALL obtain the profile with the same password the application uses

#### Scenario: Keyring unavailable

- **WHEN** the user switches sharing on while the operating system keyring is unavailable
- **THEN** the application SHALL report that sharing failed because the keyring is unavailable
- **AND** the profile SHALL NOT appear in the shared file
- **AND** no secret SHALL be written to the shared file or to local preferences instead

#### Scenario: Secret too large for the keyring

- **WHEN** one secret of a profile is rejected by the keyring
- **THEN** that profile SHALL NOT appear in the shared file and the failure SHALL be reported with the profile name
- **AND** other shared profiles SHALL stay shared

#### Scenario: Secret missing at read time

- **WHEN** the shared file records a secret for a profile and the keyring no longer holds it
- **THEN** reading that profile SHALL fail with an error naming the profile and the missing secret
- **AND** the profile SHALL NOT be returned without the secret

### Requirement: Shared Copy Follows Profile Changes

Every change to a shared profile that the application saves — edited settings, changed secrets, rename, deletion,
import that replaces it, or switching sharing off — SHALL be applied to the shared file and the dedicated keyring
entries as part of the same save. Removing a profile or its sharing SHALL remove its entry from the file and its
dedicated keyring entries. The application's own stored profiles and secrets SHALL be unaffected by a failed
update of the shared copy.

#### Scenario: Password change

- **WHEN** the user changes the SASL password of a shared profile and saves
- **THEN** a headless reader SHALL obtain the new password

#### Scenario: Sharing switched off

- **WHEN** the user switches sharing off for a profile
- **THEN** the profile SHALL be absent from the shared file
- **AND** its dedicated keyring entries SHALL be removed
- **AND** the profile and its secrets SHALL remain usable in the application

#### Scenario: Shared profile deleted

- **WHEN** the user deletes a shared profile
- **THEN** the profile SHALL be absent from the shared file and its dedicated keyring entries SHALL be removed

#### Scenario: Rename

- **WHEN** the user renames a shared profile
- **THEN** the shared file SHALL list the profile under the new name only
- **AND** the dedicated keyring entries of the old name SHALL be removed

#### Scenario: Update of the shared copy fails after a successful save

- **WHEN** the user edits a shared profile and the shared file cannot be written
- **THEN** the edit SHALL be saved in the application
- **AND** the application SHALL report that the shared copy is out of date and offer to retry

#### Scenario: Damaged shared file

- **WHEN** the shared file exists but cannot be read and the user saves a profile
- **THEN** the application SHALL replace the file with the current set of shared profiles
- **AND** SHALL log that the previous shared file was unreadable

### Requirement: Sharing Is Not Transferred By Import Or Duplicate

Sharing SHALL be a decision made on the machine where the profile is used. A profile that enters the application
through a JSON import, a cluster archive import or a configuration bundle import SHALL NOT be shared as a result of
the import, whatever the imported data states. A duplicated profile SHALL NOT be shared.

#### Scenario: Importing a bundle exported from a machine where the profile was shared

- **WHEN** the user imports a bundle whose profile was shared on the exporting machine
- **THEN** the imported profile SHALL NOT be shared
- **AND** it SHALL NOT appear in the shared file

#### Scenario: Import replaces a shared profile

- **WHEN** profile "Prod" is shared and the user imports a bundle containing "Prod" and chooses Replace
- **THEN** "Prod" SHALL no longer be shared
- **AND** its entry in the shared file and its dedicated keyring entries SHALL be removed

#### Scenario: Duplicating a shared profile

- **WHEN** the user duplicates a shared profile and saves the copy
- **THEN** the source SHALL stay shared and the copy SHALL NOT be shared

### Requirement: MCP Client Configuration Snippet

The sharing dialog of a shared profile SHALL show a configuration snippet in the JSON form used by common MCP
clients that starts the kafkalyzer MCP server program installed with the application, restricted to that profile,
and SHALL offer an action that copies it to the clipboard with visible confirmation. The snippet SHALL contain no
secret. The application SHALL NOT modify any MCP client's configuration.

#### Scenario: Copying the snippet

- **WHEN** the user activates the copy action for shared profile "orders-test"
- **THEN** the clipboard SHALL hold a JSON snippet with the absolute path of the server program and an argument
  that restricts it to "orders-test"
- **AND** a confirmation SHALL be shown

#### Scenario: Profile is not shared

- **WHEN** the user opens the sharing dialog of a profile that is not shared
- **THEN** the copy action SHALL be disabled and a hint SHALL state that the profile must be shared first

#### Scenario: Server program not found

- **WHEN** the server program does not exist at the path the snippet names
- **THEN** the dialog SHALL state that the program was not found at that path
- **AND** the snippet SHALL still be shown and copyable

#### Scenario: Profile name with special characters

- **WHEN** the profile name contains quotes, backslashes or non-ASCII characters
- **THEN** the copied snippet SHALL be valid JSON that yields the exact profile name
