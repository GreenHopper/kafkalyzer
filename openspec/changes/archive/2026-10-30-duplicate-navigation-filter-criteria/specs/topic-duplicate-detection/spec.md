# Spec Delta: topic-duplicate-detection

## MODIFIED Requirements

### Requirement: Duplicate Analysis Dashboard Presentation

The topic analysis view SHALL present duplicate analysis metrics in a dedicated summary card and provide a section to inspect the top duplicated messages with interactive drill-down, copy actions, and seamless navigation into filtered message views.

#### Scenario: Summary card display
- **WHEN** topic analysis results are loaded in the view
- **THEN** a summary card SHALL display the duplicate message count and duplicate rate percentage

#### Scenario: Viewing top duplicates list
- **WHEN** duplicate messages were detected
- **THEN** the report view SHALL render the top duplicated messages list with decoded payload preview and occurrence details
- **AND** allow copying payload and key contents

#### Scenario: Inspecting duplicate message details
- **WHEN** the user selects a duplicated message item or activates its details action
- **THEN** the system SHALL display a duplicate details dialog presenting full decoded payload content, key, occurrence count, share percentage, and sample partition, offset, and timestamp
- **AND** provide quick copy actions for the payload and key

#### Scenario: Navigating to sample message
- **WHEN** the user triggers navigation from the duplicate details dialog for a sample message in a live session
- **THEN** the system SHALL navigate to the topic's messages view positioned at the sample partition and offset

#### Scenario: Filtering duplicate occurrences across topic partitions
- **WHEN** the user triggers the action to show duplicate occurrences in the messages view from the duplicate details dialog
- **THEN** the system SHALL switch to the topic's messages view
- **AND** pre-populate the quick filter text with the duplicate key when present, or an excerpt/content from the payload preview when unkeyed
- **AND** set the search scope to `key` for keyed duplicates and `value` for unkeyed duplicates
- **AND** set the filter type to `exact` for key matching and `contains` for payload matching
- **AND** clear partition restrictions so message consumption spans all topic partitions
- **AND** configure the scan mode to `offsetEarliest` starting from offset 0 with an adequate result limit
- **AND** initiate message streaming to isolate and display the duplicate messages
