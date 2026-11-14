# Spec Delta

## MODIFIED Requirements

### Requirement: Stored Profiles Survive Configuration Export And Import

The system SHALL allow exporting cluster profiles to a configuration bundle, supporting both sanitized exports with sensitive credentials excluded and passphrase-encrypted exports with credentials included, restoring configurations accurately upon import.

#### Scenario: Import reproduces the source profile authentication
- **WHEN** the user exports the configuration of a cluster profile that uses an enterprise SASL mechanism and imports the bundle into a fresh installation
- **THEN** the imported profile SHALL carry the same mechanism, credentials and certificate paths as the exported profile
- **AND** a connection test against the cluster SHALL produce the same result as on the source installation

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
