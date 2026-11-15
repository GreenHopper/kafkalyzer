# schema-registry-auth Specification

## Purpose
TBD - created by archiving change enterprise-security-and-decoding-improvements. Update Purpose after archive.
## Requirements
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

### Requirement: Schema Registry URL Normalisation

The system SHALL derive one base URL from the configured Schema Registry URL for every registry request: surrounding whitespace and trailing slashes removed, a path prefix kept, and `http://` assumed when no scheme is given. An URL that cannot be parsed SHALL be reported as invalid configuration, not as an unreachable registry.

#### Scenario: Trailing slash
- **WHEN** the profile's registry URL is `https://registry.example.com/`
- **THEN** the subject list SHALL be requested from `https://registry.example.com/subjects`

#### Scenario: Missing scheme
- **WHEN** the profile's registry URL is `registry.example.com:8081`
- **THEN** requests SHALL go to `http://registry.example.com:8081`

#### Scenario: Path prefix
- **WHEN** the profile's registry URL is `https://gateway.example.com/sr/`
- **THEN** the subject list SHALL be requested from `https://gateway.example.com/sr/subjects`

#### Scenario: Invalid URL
- **WHEN** the profile's registry URL cannot be parsed as an URL
- **THEN** schema features SHALL report an invalid Schema Registry URL in the profile

### Requirement: Subject Names Are Encoded in Request Paths

Subject names SHALL be percent-encoded as single URL path segments in every registry request, so that names containing `/`, `?`, `#`, `%`, spaces or `:` address exactly that subject.

#### Scenario: Subject with a slash
- **WHEN** the user opens subject `team/orders-value`
- **THEN** the request path SHALL contain the single segment `team%2Forders-value`
- **AND** the schema of exactly that subject SHALL be shown

#### Scenario: Subject with a context prefix
- **WHEN** the user opens subject `:.prod:orders-value`
- **THEN** the subject SHALL be requested as one encoded path segment and its schema shown

### Requirement: Bounded and Understandable Registry Requests

Every Schema Registry request SHALL end within a fixed timeout. A non-success HTTP status SHALL be reported as an HTTP error with its status code and the registry's error message, never as an unreadable response. 401, 403, 404, timeouts, unreachable hosts and rejected certificates SHALL be distinguished in localized text.

#### Scenario: Wrong credentials
- **WHEN** the registry answers a request with HTTP 401
- **THEN** the user SHALL see that the Schema Registry rejected the credentials, with status 401
- **AND** the message SHALL NOT say that the response could not be decoded

#### Scenario: Missing permission
- **WHEN** the registry answers a request with HTTP 403
- **THEN** the user SHALL see that the credentials have no access to this resource, with status 403

#### Scenario: Subject not found
- **WHEN** the registry answers with HTTP 404 and error code 40401
- **THEN** the user SHALL see that the subject was not found, including the registry's message

#### Scenario: Registry does not answer
- **WHEN** the registry accepts the connection but does not answer within the timeout
- **THEN** the request SHALL end with a timeout error within the timeout plus a small margin

#### Scenario: Certificate rejected
- **WHEN** the registry presents a certificate that cannot be verified and verification is not disabled for the profile
- **THEN** the user SHALL see a certificate error, not a timeout or an empty result

### Requirement: Registry Errors Contain No Secrets

Error messages from Schema Registry requests, shown to the user or written to the log, SHALL NOT contain the registry password, the authorization header or credentials embedded in the URL. The registry's own error text SHALL be limited in length.

#### Scenario: URL with embedded credentials
- **WHEN** the registry URL contains `user:secret@` and the request fails
- **THEN** neither the shown error nor the log entry SHALL contain `secret`

### Requirement: Registry Reads Use GET Only

Reading subjects, versions, schemas, references and compatibility levels SHALL use HTTP GET only. The compatibility check of a draft schema SHALL be the only request with another method and SHALL use the same URL handling, timeout and error reporting.

#### Scenario: Any schema read
- **WHEN** the application loads subjects, schemas, references or compatibility levels
- **THEN** only GET requests SHALL be sent to the Schema Registry

#### Scenario: Compatibility check times out
- **WHEN** the draft compatibility check gets no answer within the timeout
- **THEN** the check SHALL report a timeout error instead of "incompatible"

