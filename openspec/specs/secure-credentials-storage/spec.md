# secure-credentials-storage Specification

## Purpose

Protects sensitive cluster authentication secrets (SASL passwords, OAuth tokens, keystore/truststore passwords, PEM key passwords, and Schema Registry passwords) by delegating their encryption and persistence to the native operating system keyring instead of storing plaintext on disk.

## Requirements

### Requirement: Native OS Keyring Persistence for Sensitive Secrets

The system SHALL store and manage sensitive credentials (SASL passwords, OAuth tokens, PEM private key passwords, SSL keystore/truststore passwords, and Schema Registry basic-auth passwords) within the native OS keyring service (Secret Service on Linux, Keychain on macOS, Credential Manager on Windows), while storing non-sensitive cluster metadata in standard local preferences.

#### Scenario: Storing secrets in OS Keyring upon saving cluster profile

- **WHEN** the user saves a cluster profile configured with SASL password and Schema Registry password
- **THEN** the sensitive passwords SHALL be stored in the native OS keyring under a cluster-scoped identifier
- **AND** the plaintext profile JSON stored in `SharedPreferences` SHALL omit the secret values or replace them with secure reference tokens

#### Scenario: Transparently loading secrets for broker connections

- **WHEN** the application connects to a configured Kafka cluster
- **THEN** the system SHALL resolve the cluster's sensitive passwords from the native OS keyring
- **AND** supply them to the connection initialization without prompting the user for manual re-entry

### Requirement: Automatic Migration from Plaintext Storage

On first startup after upgrading, the system SHALL automatically scan stored cluster profiles for plaintext credentials, import each profile's detected secrets into the OS keyring, and strip plaintext secrets only for profiles whose keyring writes succeeded. Profiles whose keyring writes failed SHALL retain their plaintext secrets and keep the migration incomplete so migration retries on a later launch when a keyring is available. Configuration bundle imports SHALL likewise write imported profile secrets through the keyring and keep plaintext only when keyring writes fail.

#### Scenario: Migrating legacy plaintext profiles to OS Keyring

- **WHEN** an existing installation with plaintext cluster credentials launches with an available OS keyring
- **THEN** the system SHALL write each profile's secrets into the OS keyring under the corresponding profile key
- **AND** remove the plaintext secret fields from `SharedPreferences` on disk
- **AND** mark migration complete

#### Scenario: Migration retries when keyring fails for a profile

- **WHEN** an installation with legacy plaintext credentials launches while the OS keyring is unavailable
- **THEN** the plaintext credentials SHALL remain in `SharedPreferences` and the migration flag SHALL remain unset
- **AND** the loaded profiles SHALL still carry those credentials in memory for the current session

#### Scenario: Configuration import updates keyring and strips plaintext

- **WHEN** the user imports a configuration bundle containing credentials while the OS keyring is available
- **THEN** the imported secrets SHALL be written to the OS keyring (overriding any stale keyring values for replaced profiles)
- **AND** the stored `cluster_profiles` preference SHALL contain no plaintext secret fields

### Requirement: Safe Profile Export and Import Controls

When exporting cluster profiles or the configuration to an archive bundle, the system SHALL exclude sensitive credentials by default. A bundle that includes credentials SHALL only be written encrypted with a user passphrase in the standard age passphrase format (`age-encryption.org/v1`), never unencrypted. Import SHALL recognize encrypted bundles by content and SHALL keep accepting unencrypted bundles.

#### Scenario: Default export scrubs secrets from profile bundle

- **WHEN** the user initiates a cluster profile export without checking the include-secrets option
- **THEN** the exported configuration bundle SHALL have all password and token fields removed or empty
- **AND** importing this bundle into another machine SHALL require the recipient to enter passwords manually

#### Scenario: Explicit opt-in export includes credentials with warning

- **WHEN** the user explicitly selects "Include sensitive passwords in export"
- **THEN** the system SHALL display a clear security warning and SHALL require a passphrase before the export can start
- **AND** upon confirmation, the written file SHALL be encrypted with that passphrase and SHALL contain the necessary credentials only inside the encrypted content
- **AND** no unencrypted file containing credentials SHALL be written, not even temporarily

#### Scenario: Configuration export follows the same rule

- **WHEN** the user exports the application configuration with the include-credentials option and a valid passphrase
- **THEN** the written configuration file SHALL be encrypted with that passphrase
- **AND** exporting the configuration without that option SHALL produce an unencrypted bundle without credentials, as before

#### Scenario: Configuration export does not bundle legacy GCS key files

- **WHEN** a legacy `gcs_credentials.json` file exists in the application support directory and the user exports configuration
- **THEN** the exported zip SHALL contain only `preferences.json` and configured `files/` keystore/truststore entries

#### Scenario: Encrypted bundle is readable with the standard age tool

- **WHEN** an encrypted export is decrypted with the age command-line tool and the same passphrase
- **THEN** the result SHALL be the unencrypted bundle archive that the application would import

#### Scenario: Importing an encrypted bundle with the correct passphrase

- **WHEN** the user imports an encrypted bundle and enters the passphrase used at export
- **THEN** the bundle SHALL be imported like an unencrypted bundle, including its credentials
- **AND** the credentials SHALL be stored in the OS keyring of the importing machine

#### Scenario: Wrong passphrase on import

- **WHEN** the user imports an encrypted bundle and enters a wrong passphrase
- **THEN** the system SHALL report that the passphrase is wrong and SHALL allow the user to try again or cancel
- **AND** no profile, keyring secret, preference or file SHALL be changed

#### Scenario: Damaged or unsupported encrypted file

- **WHEN** the user imports a file that starts with the age header but is truncated, modified or not passphrase-encrypted
- **THEN** the system SHALL report that the file is damaged or not a supported encrypted bundle
- **AND** no profile, keyring secret, preference or file SHALL be changed

#### Scenario: User cancels the passphrase prompt

- **WHEN** the user imports an encrypted bundle and cancels the passphrase prompt
- **THEN** the import SHALL end without a success message
- **AND** no profile, keyring secret, preference or file SHALL be changed

#### Scenario: Unencrypted bundles from earlier versions stay importable

- **WHEN** the user imports an unencrypted bundle created by an earlier version, with or without credentials
- **THEN** the import SHALL proceed without asking for a passphrase and SHALL produce the same profiles as before this change

### Requirement: Export Passphrase Handling

The passphrase for an encrypted export SHALL have at least 12 characters and SHALL be entered twice identically
before the export can start. The dialog SHALL warn that a lost passphrase cannot be recovered and that the bundle
cannot be opened without it. The system SHALL NOT store the passphrase, write it to logs or show it in messages.

#### Scenario: Passphrase too short

- **WHEN** the user enters a passphrase with fewer than 12 characters for an export with credentials
- **THEN** the dialog SHALL show a validation error stating the minimum length
- **AND** the export SHALL NOT start

#### Scenario: Passphrase confirmation does not match

- **WHEN** the passphrase and its confirmation differ
- **THEN** the dialog SHALL show a validation error and the export SHALL NOT start

#### Scenario: Not-recoverable warning

- **WHEN** the user selects the include-credentials option
- **THEN** the dialog SHALL show a warning, as text with an icon, that the passphrase cannot be recovered

#### Scenario: Passphrase is never persisted or logged

- **WHEN** the user completes an encrypted export or import, or the operation fails
- **THEN** the passphrase SHALL NOT appear in local preferences, the OS keyring, log output or any error message

#### Scenario: Encryption fails

- **WHEN** encrypting the bundle or writing the encrypted file fails
- **THEN** the system SHALL report the export as failed and SHALL NOT report success
- **AND** no unencrypted bundle with credentials SHALL be left on disk

### Requirement: Discrete Security Indicator in Cluster Dialog

The cluster configuration dialog SHALL display a subtle, non-intrusive security indicator (such as a lock icon or badge with tooltip) confirming that secret fields are protected by the OS keyring when available, and SHALL switch to a warning icon with a tooltip stating that passwords will not be persisted when the OS keyring is unavailable.

#### Scenario: Viewing protected secret field

- **WHEN** the user inspects or edits password fields in the Cluster Configuration Dialog while the OS keyring is available
- **THEN** a subtle lock indicator SHALL be visible alongside the credential section
- **AND** hovering or tapping the indicator SHALL show a tooltip stating "Protected by OS Keyring"

#### Scenario: Viewing secret field when keyring is unavailable

- **WHEN** the user inspects or edits password fields in the Cluster Configuration Dialog while the OS keyring is unavailable
- **THEN** a warning icon SHALL be shown instead of the lock icon
- **AND** hovering or tapping the indicator SHALL show a tooltip stating that passwords will not be persisted across restarts

### Requirement: Plaintext Secrets Are Retained Only When Keyring Fails

When saving profiles while the OS keyring is unavailable, the system SHALL NOT write secrets into preferences (except retaining legacy unmigrated plaintext during failed migration/import) and SHALL surface a persistent, non-blocking notice informing the user that credentials are kept in memory for the current session only.

#### Scenario: Saving a new profile while keyring is unavailable

- **WHEN** the user saves a cluster profile with a SASL password while the OS keyring is unavailable
- **THEN** the stored `cluster_profiles` preference SHALL contain no secret field
- **AND** a persistent banner SHALL warn that the system keyring is unavailable and credentials are kept in memory only

### Requirement: Keyring Secrets Follow Profile Rename

When a user renames an existing cluster profile, the system SHALL write the secrets under the new profile name first and remove the old profile's keyring keys only if all writes under the new name succeeded.

#### Scenario: Renaming a cluster profile with secrets

- **WHEN** the user renames profile "Prod" (which has a SASL password) to "Prod EU" while the keyring is available
- **THEN** the SASL password SHALL be stored under "Prod EU" in the keyring
- **AND** the old keyring entry for "Prod" SHALL be removed

#### Scenario: Renaming a cluster profile when keyring write fails

- **WHEN** the user renames profile "Prod" to "Prod EU" and writing to the keyring fails
- **THEN** the old keyring entry for "Prod" SHALL NOT be deleted
- **AND** no secret SHALL be written into preferences
