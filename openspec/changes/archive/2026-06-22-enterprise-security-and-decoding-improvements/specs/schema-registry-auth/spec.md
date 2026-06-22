## ADDED Requirements

### Requirement: Schema Registry Basic Auth
The system SHALL support configuring a username and password for Confluent Schema Registry basic authentication.

#### Scenario: Configure and save Basic Auth credentials
- **WHEN** the user adds or edits a cluster profile with Schema Registry credentials and connects to it
- **THEN** the system SHALL authenticate all REST calls to the Schema Registry (fetching subjects and schemas) using HTTP Basic Authentication

### Requirement: Schema Registry TLS Connection
The system SHALL support HTTPS connections to the Schema Registry and allow inheriting the SSL truststore and keystore certificates configured for the Kafka broker.

#### Scenario: Connect to secure Schema Registry
- **WHEN** the user connects to a cluster with an HTTPS Schema Registry URL and SSL certificates
- **THEN** the system SHALL perform a TLS handshake with the Schema Registry using the configured CA truststore and client certificates
