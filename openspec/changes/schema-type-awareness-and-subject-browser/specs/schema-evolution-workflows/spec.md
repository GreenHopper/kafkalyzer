## ADDED Requirements

### Requirement: Compatibility Level Display

For every subject shown in the schema inspector, the system SHALL display the effective compatibility level and whether it is set on the subject or inherited from the global level. Values that cannot be read SHALL be shown as unknown with the reason, never as a default level.

#### Scenario: Level set on the subject
- **WHEN** the registry reports compatibility `FULL` for subject `orders-value` and `BACKWARD` globally
- **THEN** the inspector SHALL show `FULL` for `orders-value`, marked as set on the subject

#### Scenario: Subject inherits the global level
- **WHEN** the registry answers the subject compatibility request for `orders-value` with "not found" and reports `BACKWARD` globally
- **THEN** the inspector SHALL show `BACKWARD` for `orders-value`, marked as inherited from the global level

#### Scenario: Subject level not readable
- **WHEN** the subject compatibility request returns HTTP 403
- **THEN** the inspector SHALL show the subject compatibility as unknown with an "access denied" hint
- **AND** it SHALL NOT show the global level as the subject's level

#### Scenario: Neither level readable
- **WHEN** the subject level is not set and the global compatibility request fails
- **THEN** the inspector SHALL show the compatibility as unknown with the reason of the global failure

### Requirement: Associated Topic Availability

Associated topics of a subject SHALL be checked against the topic list of the connected cluster. A topic present there SHALL be openable. A topic not present SHALL be marked as not found on the cluster and SHALL NOT be opened with made-up metadata. A failed association lookup SHALL be shown as an error, not as "no associated topics".

#### Scenario: Derived topic missing on the cluster
- **WHEN** subject `legacy-value` is inspected and the connected cluster has no topic `legacy`
- **THEN** `legacy` SHALL be listed as not found on this cluster without an open action

#### Scenario: Association lookup fails
- **WHEN** resolving the associated topics of a subject fails
- **THEN** the associated topics section SHALL show an error with "Retry" instead of "No associated topics found"

### Requirement: Schema Evolution Reads Stay Read-Only

Reading compatibility levels, versions and associated topics SHALL only use GET requests against the Schema Registry and no Kafka request beyond the already loaded topic list. The compatibility check of a draft schema SHALL remain the only POST and SHALL NOT register or change anything.

#### Scenario: Viewing compatibility and associations
- **WHEN** the user opens a subject, views its compatibility level and its associated topics
- **THEN** every request sent to the Schema Registry SHALL be a GET request
- **AND** no compatibility setting, subject or schema SHALL be created or changed
