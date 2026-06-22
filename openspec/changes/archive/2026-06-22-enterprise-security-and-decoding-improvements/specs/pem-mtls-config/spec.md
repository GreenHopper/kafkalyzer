## ADDED Requirements

### Requirement: PEM Client Certificate and Key Configuration
The system SHALL allow configuring client-side mTLS using separate Client Certificate and Private Key PEM files.

#### Scenario: Configure separate PEM files
- **WHEN** the user selects PEM as the keystore format and inputs separate file paths for the client certificate and the client private key (along with private key password if encrypted)
- **THEN** the system SHALL set the corresponding rdkafka configurations (`ssl.certificate.location`, `ssl.key.location`, `ssl.key.password`) to establish the client TLS identity
