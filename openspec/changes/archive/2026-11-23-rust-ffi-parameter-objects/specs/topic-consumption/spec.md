# Spec Delta

## ADDED Requirements

### Requirement: Consumption Criteria Named Per Request

A message-consumption request SHALL carry each of its criteria exactly once and identified by name rather than by position: topic and partition selection, start and end bounds, filter terms, filter field, filter type, search scope, structured filter expression with its variables, result limit, live mode, tail start and the locally supplied schemas. A criterion the request does not carry SHALL keep its documented default.

#### Scenario: Optional criterion omitted

- **WHEN** a consumption request supplies no structured filter expression and no tail start
- **THEN** the run SHALL behave as before with structured filtering off and tail start off
- **AND** the emitted messages SHALL be the same set as with those criteria explicitly set to their defaults

#### Scenario: Two criteria share a type

- **WHEN** a request carries two criteria of the same value type, for example a start bound and a filter field
- **THEN** each criterion SHALL be applied to the purpose its name identifies
- **AND** exchanging the two values without exchanging their names SHALL NOT be representable in a well-formed request

#### Scenario: Criterion recorded before this change is replayed

- **WHEN** a saved search or script step stored by an earlier version is run again
- **THEN** its stored criteria SHALL resolve to one request carrying those same criteria
- **AND** the run SHALL emit the same result set as it did for the same cluster and topic before the change
- **AND** a stored criterion that can no longer be understood SHALL be reported and SHALL NOT be dropped silently

#### Scenario: A criterion refers to a partition that is not readable

- **WHEN** the request selects a partition whose read is denied by cluster permissions
- **THEN** the run SHALL report that partition as not readable
- **AND** it SHALL NOT present the outcome as an empty result or a zero count
