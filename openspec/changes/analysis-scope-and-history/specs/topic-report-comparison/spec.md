## MODIFIED Requirements

### Requirement: Select Two Reports To Compare

The system SHALL let the user pick two analysis reports as the comparison pair, where each side is either the currently loaded live analysis, a previously imported report file, or a report saved in the local history of the current cluster and topic.

#### Scenario: Compare live analysis with an imported report

- **WHEN** the user has a live analysis loaded and selects an imported report as the comparison base
- **THEN** the system SHALL show both reports side by side
- **AND** each side SHALL be labeled with its topic, scan moment and whether it is live or imported

#### Scenario: Compare two imported reports

- **WHEN** the user selects two imported report files as the pair
- **THEN** the system SHALL show the comparison without connecting to any cluster

#### Scenario: Only one report available

- **WHEN** the user opens the comparison action while only one report is available
- **THEN** the system SHALL prompt for the second report instead of showing a partial comparison

#### Scenario: Compare with a saved report from the history

- **WHEN** the user opens the comparison action and selects a saved report of the current cluster and topic
- **THEN** the system SHALL compare the displayed report with the saved report without a file dialog
- **AND** the saved side SHALL be labeled as imported with its scan moment

#### Scenario: History cannot be listed for comparison

- **WHEN** the local history cannot be listed while the user opens the comparison action
- **THEN** the system SHALL show a localized error and still offer picking a report file

## ADDED Requirements

### Requirement: Scope Of Both Sides Shown

The comparison SHALL show the scope summary of both reports and SHALL show a visible warning when the scopes differ in mode, message count, time range or partition selection, or when the scope of a side is not recorded.

#### Scenario: Different scopes

- **WHEN** the user compares a report of the newest 10,000 messages with a full-scan report of the same topic
- **THEN** both scope summaries SHALL be shown
- **AND** a warning SHALL state that the reports cover different scopes, so differences may come from the scope

#### Scenario: Same scope

- **WHEN** both reports are full scans of all partitions
- **THEN** no scope warning SHALL be shown

#### Scenario: Scope not recorded

- **WHEN** one side is a report file without a recorded scope
- **THEN** that side SHALL show "scope not recorded"
- **AND** the warning SHALL state that the scopes cannot be compared
