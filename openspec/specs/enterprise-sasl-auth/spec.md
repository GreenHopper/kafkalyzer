# enterprise-sasl-auth Specification

## Purpose
TBD - created by archiving change enterprise-security-and-decoding-improvements. Update Purpose after archive.
## Requirements
### Requirement: Detailed Kerberos GSSAPI Configuration
The system SHALL support configuring SASL GSSAPI (Kerberos) with custom parameters including Kerberos Service Name, Keytab location, Principal, and krb5.conf path.

#### Scenario: Save and connect using Kerberos config
- **WHEN** the user configures a cluster profile with SASL GSSAPI and enters the service name, keytab file path, principal, and krb5.conf path
- **THEN** the system SHALL set the corresponding rdkafka options (`sasl.kerberos.service.name`, `sasl.kerberos.keytab`, `sasl.kerberos.principal`, `sasl.kerberos.kinit.cmd`) and establish connection to the broker

### Requirement: SASL OAuthBearer Support
The system SHALL support SASL OAuthBearer authentication using a static token or an token provider command.

#### Scenario: Connect using SASL OAuthBearer static token
- **WHEN** the user configures a cluster profile with SASL OAUTHBEARER and inputs a static token
- **THEN** the system SHALL authenticate the consumer connection using the specified token

### Requirement: AWS MSK IAM Authentication Support
The system SHALL support AWS MSK IAM authentication using the standard SASL mechanism (`AWS_MSK_IAM`).

#### Scenario: Connect to Amazon MSK
- **WHEN** the user selects the AWS MSK IAM mechanism in the cluster profile settings
- **THEN** the system SHALL resolve AWS credentials (via default credentials chain or profile) and authenticate to MSK

