# Spec Delta

## MODIFIED Requirements

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

## ADDED Requirements

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
