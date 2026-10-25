# Spec Delta

## MODIFIED Requirements

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

The system SHALL allow exporting cluster profiles to a configuration bundle, supporting both sanitized exports with sensitive credentials excluded and explicit authorized exports with credentials included, restoring configurations accurately upon import.

#### Scenario: Import reproduces the source profile authentication

- **WHEN** the user exports the configuration of a cluster profile that uses an enterprise SASL mechanism and imports the bundle into a fresh installation
- **THEN** the imported profile SHALL carry the same mechanism, credentials and certificate paths as the exported profile
- **AND** a connection test against the cluster SHALL produce the same result as on the source installation

#### Scenario: Sanitized export omits passwords for safe sharing

- **WHEN** a cluster profile is exported using the default safe export mode
- **THEN** connection parameters and non-sensitive options SHALL be present in the bundle
- **AND** sensitive password and token fields SHALL be excluded from the archive

#### Scenario: Authorized export reproduces complete profile authentication

- **WHEN** the user explicitly exports a cluster profile including credentials and imports the bundle into another installation
- **THEN** the imported profile SHALL carry all connection parameters, certificates, and credentials
- **AND** the imported credentials SHALL be written to the destination machine's native OS keyring
