# Spec Delta

## Purpose

Enables users to export consumed Kafka messages into RFC 4180 compliant CSV format using the table view's visible standard and dynamic projected columns, seamlessly integrated into the existing results toolbar export affordance.

## ADDED Requirements

### Requirement: Integrated Message Export Format Selection

The message results toolbar export button SHALL provide a compact format selection affordance allowing users to choose between exporting full message payloads as JSON or exporting visible tabular columns as CSV, without occupying additional persistent toolbar space.

#### Scenario: User triggers export format menu

- **WHEN** the user activates the export messages button on the results toolbar
- **THEN** the system SHALL display a compact menu offering "Export as JSON (Full Payload)" and "Export as CSV (Visible Columns)"
- **AND** the selection menu SHALL NOT permanently enlarge the toolbar or add persistent button rows

#### Scenario: Cancel export selection

- **WHEN** the export menu is displayed and the user dismisses it or clicks outside
- **THEN** no export file SHALL be generated and the view state SHALL remain unchanged

### Requirement: RFC 4180 Compliant CSV Generation

When CSV export is selected, the system SHALL generate an RFC 4180 compliant, UTF-8 encoded CSV file containing a header row matching the currently visible standard columns and active dynamic projected columns, followed by one data row per filtered message.

#### Scenario: Single-topic CSV export

- **WHEN** the user chooses CSV export for messages originating from a single topic
- **THEN** the system SHALL prompt the user to save a `.csv` file named with the topic name and current timestamp
- **AND** the exported file SHALL contain a header row with column titles followed by comma-separated values for all loaded matching messages
- **AND** fields containing commas, line breaks, or double quotes SHALL be escaped and enclosed in double quotes according to RFC 4180

#### Scenario: Null and missing projected values in CSV

- **WHEN** a message does not contain a value for an active projected column path
- **THEN** the corresponding cell in the CSV row SHALL be rendered as an empty string without raising an error

### Requirement: Projected and Visible Column Mapping

The CSV export SHALL extract and align cell values according to the active column configuration in the message table view, including custom dynamic JSONPath columns and standard columns (Partition, Offset, Timestamp, Key, and Payload/Summary).

#### Scenario: Active projected columns included in CSV

- **WHEN** the table is configured with dynamic projected columns (such as `customer.id` and `order.amount`)
- **THEN** the generated CSV SHALL include headers for `customer.id` and `order.amount`
- **AND** each row SHALL contain the resolved JSONPath values extracted from the respective message payload

#### Scenario: Hidden standard columns excluded from CSV

- **WHEN** a standard column (such as Timestamp or Partition) has been hidden in the table customization settings
- **THEN** that column SHALL NOT be included in the exported CSV header or data rows

### Requirement: Multi-Topic CSV Export Bundling

When the messages to be exported originate from multiple distinct Kafka topics, the system SHALL generate an individual CSV file for each topic and bundle all generated CSV files into a single `.zip` archive.

#### Scenario: Multi-topic export generates ZIP archive

- **WHEN** the exported message set contains messages from more than one topic
- **THEN** the system SHALL prompt the user to save a `.zip` archive
- **AND** the archive SHALL contain one `<topic_name>.csv` file for each topic present in the message set
