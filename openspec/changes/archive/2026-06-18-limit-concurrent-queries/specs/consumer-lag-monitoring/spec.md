## ADDED Requirements

### Requirement: Configurable Concurrent Lag Queries
The system SHALL strictly limit the number of concurrent background queries used to fetch individual consumer group lag details. It SHALL also allow configuring this concurrency limit in the settings.

#### Scenario: Enforce query concurrency limit
- **WHEN** multiple consumer group lag queries are triggered
- **THEN** the system SHALL queue queries and execute at most the configured limit of concurrent queries simultaneously

#### Scenario: Configure limit in settings
- **WHEN** the user changes the concurrent queries limit in the settings view
- **THEN** the system SHALL persist the new limit and apply it to the query execution queue immediately
