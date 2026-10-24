# cluster-profile-persistence Specification

## Purpose

Defines how a Kafka cluster profile is stored and restored locally, so that every configured connection, security and Schema Registry setting survives application restarts and profile export/import.

## Requirements

### Requirement: Complete Cluster Profile Round Trip

The system SHALL store and restore every configured field of a cluster profile without loss, including bootstrap servers, security protocol, SASL mechanism and credentials, Kerberos settings, OAuthBearer token, PEM client certificate and key settings, keystore and truststore locations with passwords, and Schema Registry URL with credentials.

#### Scenario: Kerberos profile survives an application restart
- **WHEN** the user saves a cluster profile configured with SASL GSSAPI (service name, keytab path, principal, krb5.conf path) and restarts the application
- **THEN** the profile SHALL be listed with all four Kerberos values unchanged
- **AND** connecting to that cluster SHALL use the same rdkafka options as before the restart

#### Scenario: PEM mTLS and Schema Registry credentials survive an application restart
- **WHEN** the user saves a cluster profile with PEM client certificate, private key, private key password, and Schema Registry username and password, then restarts the application
- **THEN** the reloaded profile SHALL contain the same certificate, key, password and Schema Registry credential values
- **AND** the mTLS broker connection and the Schema Registry basic-auth connection SHALL succeed without re-entering any value

#### Scenario: Editing one field preserves the remaining security settings
- **WHEN** the user opens an existing profile that uses SASL SCRAM and changes only the bootstrap server list
- **THEN** the saved profile SHALL keep the mechanism, username, password and all other previously configured fields unchanged

### Requirement: Stored Profiles Survive Configuration Export And Import

The system SHALL include every profile field in the profile export bundle and SHALL restore each of them when the bundle is imported into another installation.

#### Scenario: Import reproduces the source profile authentication
- **WHEN** the user exports the configuration of a cluster profile that uses an enterprise SASL mechanism and imports the bundle into a fresh installation
- **THEN** the imported profile SHALL carry the same mechanism, credentials and certificate paths as the exported profile
- **AND** a connection test against the cluster SHALL produce the same result as on the source installation
