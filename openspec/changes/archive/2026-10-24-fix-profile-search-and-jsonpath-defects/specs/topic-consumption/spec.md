# Spec Delta

## MODIFIED Requirements

### Requirement: Pre-compiled Filter Evaluation

The consumer SHALL pre-compile all configured regular expressions and search terms prior to entering the message consumption loop and evaluate them without allocating or compiling new regex instances per message. The consumer SHALL NOT substitute substring matching for a pattern that failed to compile; an uncompilable pattern SHALL prevent the scan from running instead of producing degraded results.

#### Scenario: Consuming with regex filters

- **WHEN** message consumption begins with `filter_type` set to `Regex` and one or more filter terms provided
- **THEN** the consumer compiles each filter term into a reusable regular expression once during setup
- **AND** matches each incoming message against the pre-compiled expressions without compiling regular expressions inside the message loop

#### Scenario: Uncompilable pattern does not degrade to substring matching

- **WHEN** a scan is requested with `filter_type` set to `Regex` and a pattern that is not a valid regular expression
- **THEN** the scan SHALL NOT start and no messages SHALL be returned as if the filter had matched
- **AND** no regular expression SHALL be compiled inside the message loop as a fallback

## ADDED Requirements

### Requirement: Filter Pattern Validation Feedback

The search configuration SHALL validate a regular-expression filter term before a scan starts and whenever the term changes, and SHALL report an invalid pattern to the user in the active UI language at the input that caused it.

#### Scenario: Invalid pattern blocks the scan

- **WHEN** the user enters the filter term `orders[` with filter type `Regex` and triggers the scan
- **THEN** the scan SHALL be refused
- **AND** the filter input SHALL show a localized inline error naming the invalid term
- **AND** the active-filter chip for the pattern SHALL indicate the invalid state while the panel is collapsed

#### Scenario: Valid pattern produces no validation message

- **WHEN** the user enters a syntactically valid regular expression and triggers the scan
- **THEN** the scan SHALL start and no validation error SHALL be shown

### Requirement: Match Diagnostics Without Payload Echo

Scan diagnostics for a filter match SHALL identify the match by topic, partition, offset and the matched filter term, and SHALL NOT stream message payload or key content as a diagnostic record to the user interface.

#### Scenario: Large payloads do not inflate diagnostics

- **WHEN** a scan with a filter term matches many messages whose payloads exceed 100 KB each
- **THEN** each match diagnostic SHALL contain topic, partition, offset and filter term only
- **AND** no diagnostic record SHALL contain the matched payload or key text

#### Scenario: Matched content stays visible in the results

- **WHEN** a message is returned by a filtered scan
- **THEN** its full payload SHALL remain available in the message table and in the message inspector
