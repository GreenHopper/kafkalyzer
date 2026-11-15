# Spec Delta

## MODIFIED Requirements

### Requirement: Pre-compiled Filter Evaluation

The consumer SHALL pre-compile all configured regular expressions, search terms and the filter expression prior to entering the message consumption loop and evaluate them without allocating or compiling new regex instances or parsing the expression per message. The consumer SHALL NOT substitute substring matching for a pattern that failed to compile; an uncompilable pattern or an invalid filter expression SHALL prevent the scan from running instead of producing degraded results.

#### Scenario: Consuming with regex filters
- **WHEN** message consumption begins with `filter_type` set to `Regex` and one or more filter terms provided
- **THEN** the consumer compiles each filter term into a reusable regular expression once during setup
- **AND** matches each incoming message against the pre-compiled expressions without compiling regular expressions inside the message loop

#### Scenario: Uncompilable pattern does not degrade to substring matching
- **WHEN** a scan is requested with `filter_type` set to `Regex` and a pattern that is not a valid regular expression
- **THEN** the scan SHALL NOT start and no messages SHALL be returned as if the filter had matched
- **AND** no regular expression SHALL be compiled inside the message loop as a fallback

#### Scenario: Filter expression compiled once
- **WHEN** a scan is requested with a filter expression containing `matches` conditions and timestamp literals
- **THEN** the expression SHALL be parsed and its regular expressions and timestamps converted once before the first poll
- **AND** no parsing or regular-expression compilation SHALL happen inside the message loop

#### Scenario: Invalid filter expression stops the scan before reading
- **WHEN** a scan is requested with a filter expression that is not valid
- **THEN** the scan SHALL fail before any message is read, reporting the error and its position
- **AND** the failure SHALL be shown as an error, not as an empty result

### Requirement: Progressive Disclosure for Advanced Topic Search Filters

The topic search bar SHALL default to a compact, single-row primary control layout. Advanced filter parameters (`Field`, `Filter Type: Contains | Regex | Exact`, `Search Scope: Key | Value | Both`, `Expression`, `Partition`, and `Fast Trace`) SHALL be collapsed by default behind an "Advanced Filters" toggle. When collapsed, any non-default active advanced filter parameters SHALL be visibly summarized as removable or clickable filter chips in the compact bar.

#### Scenario: Initial display in collapsed mode
- **WHEN** a topic view is opened
- **THEN** advanced filter controls (`Field`, `Filter Type`, `Search Scope`, `Expression`, `Partition`, `Fast Trace`) SHALL be hidden in a collapsed panel
- **AND** the toggle button SHALL indicate the collapsed state (e.g. "Advanced" or "⚙️ Erweitert")

#### Scenario: Expanding advanced filters
- **WHEN** the user activates the advanced filters toggle
- **THEN** the advanced filter controls panel SHALL expand smoothly without disrupting the existing message list or active stream

#### Scenario: Non-default filter chips when collapsed
- **WHEN** the user has configured a partition filter (e.g. Partition `3`) or exact regex filter and collapses the advanced panel
- **THEN** compact chips displaying the active values (e.g. `Partition: 3`, `Regex`) SHALL appear in the compact search bar
- **AND** clicking a chip or its removal icon SHALL allow quick editing or clearing of the parameter

#### Scenario: Active expression chip when collapsed
- **WHEN** the user has entered a filter expression and collapses the advanced panel
- **THEN** a chip SHALL show the expression's canonical text, shortened with an ellipsis when long and complete in its tooltip
- **AND** the chip SHALL indicate an invalid expression by an icon and text, not by colour alone
- **AND** clicking the chip SHALL open the expression editor and its removal icon SHALL clear the expression

### Requirement: Match Diagnostics Without Payload Echo

Scan diagnostics for a filter match SHALL identify the match by topic, partition, offset and the matched filter term, or the marker `expression` for a match that only a filter expression decided, and SHALL NOT stream message payload or key content as a diagnostic record to the user interface.

#### Scenario: Large payloads do not inflate diagnostics
- **WHEN** a scan with a filter term matches many messages whose payloads exceed 100 KB each
- **THEN** each match diagnostic SHALL contain topic, partition, offset and filter term only
- **AND** no diagnostic record SHALL contain the matched payload or key text

#### Scenario: Matched content stays visible in the results
- **WHEN** a message is returned by a filtered scan
- **THEN** its full payload SHALL remain available in the message table and in the message inspector

#### Scenario: Expression match diagnostics
- **WHEN** a scan with only a filter expression matches a message
- **THEN** the match diagnostic SHALL contain topic, partition, offset and the marker `expression`, not the expression text or any field value
- **AND** the canonical expression text SHALL be logged once when the scan starts
