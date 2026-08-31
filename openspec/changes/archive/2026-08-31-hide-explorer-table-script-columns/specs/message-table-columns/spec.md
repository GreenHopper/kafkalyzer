## Purpose

Controls when Step and Topic columns appear in the shared Kafka message table so explorer stays focused and scripting keeps multi-step context.

## ADDED Requirements

### Requirement: Hide Step and Topic columns in topic explorer table
When the user views Kafka messages in the topic explorer using table view, the system SHALL NOT display the Step column or the Topic column.

#### Scenario: Explorer table omits script-oriented columns
- **WHEN** the user opens a topic in the topic explorer feature
- **AND** the message results are shown in table view
- **THEN** the table SHALL NOT include a Step column
- **AND** the table SHALL NOT include a Topic column

### Requirement: Show Step and Topic columns in scripting message tables
When the user views Kafka messages from the scripting feature in table view, the system SHALL display the Step column and the Topic column.

#### Scenario: Script run details table includes Step and Topic
- **WHEN** the user views message results from a script run in table view
- **THEN** the table SHALL include a Step column
- **AND** the table SHALL include a Topic column
