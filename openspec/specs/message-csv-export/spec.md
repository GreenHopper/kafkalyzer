# message-csv-export Specification

## Purpose

Enables users to export consumed Kafka messages into RFC 4180 compliant CSV format using the table view's visible standard and dynamic projected columns, seamlessly integrated into the existing results toolbar export affordance.

## Requirements

### Requirement: Integrated Message Export Format Selection

The message results toolbar export button SHALL provide a compact format selection affordance allowing users to choose between exporting full messages as JSON, as NDJSON (one message per line), or exporting visible tabular columns as CSV, together with the export options that apply to the current view, without occupying additional persistent toolbar space.

#### Scenario: User triggers export format menu

- **WHEN** the user activates the export messages button on the results toolbar
- **THEN** the system SHALL display a compact menu offering "Export as JSON (Full Payload)", "Export as NDJSON (One Message per Line)" and "Export as CSV (Visible Columns)"
- **AND** the selection menu SHALL NOT permanently enlarge the toolbar or add persistent button rows

#### Scenario: Cancel export selection

- **WHEN** the export menu is displayed and the user dismisses it or clicks outside
- **THEN** no export file SHALL be generated and the view state SHALL remain unchanged

#### Scenario: Options shown only when they apply

- **WHEN** the export menu is displayed
- **THEN** the "only selected messages" option SHALL be shown only while at least one message is selected, labelled with the number of selected messages
- **AND** the "include dimmed non-matches" option SHALL be shown only while an in-memory search is active and non-matching messages are displayed dimmed
- **AND** the "add headers column" option SHALL be shown for CSV
- **AND** toggling an option SHALL keep the menu open and SHALL NOT start an export

### Requirement: RFC 4180 Compliant CSV Generation

When CSV export is selected, the system SHALL generate an RFC 4180 compliant, UTF-8 encoded CSV file containing a header row matching the currently visible standard columns and active dynamic projected columns, followed by one data row per exported message in the displayed order.

#### Scenario: Single-topic CSV export

- **WHEN** the user chooses CSV export for messages originating from a single topic
- **THEN** the system SHALL prompt the user to save a `.csv` file named with the topic name and current timestamp
- **AND** the exported file SHALL contain a header row with column titles followed by comma-separated values for every exported message, in the order they are displayed
- **AND** fields containing commas, line breaks, or double quotes SHALL be escaped and enclosed in double quotes according to RFC 4180

#### Scenario: Null and missing projected values in CSV

- **WHEN** a message does not contain a value for an active projected column path
- **THEN** the corresponding cell in the CSV row SHALL be rendered as an empty string without raising an error

#### Scenario: Tombstone and null key distinguishable from empty values

- **WHEN** an exported message has no payload (tombstone) or no key
- **THEN** the corresponding Payload or Key cell SHALL be an empty, unquoted field
- **AND** a payload or key that is an empty string SHALL be written as a quoted empty field (`""`)

#### Scenario: Step column carries the displayed step name

- **WHEN** a CSV export from a script result view includes the Step column
- **THEN** each Step cell SHALL contain the step name shown in the table for that message

#### Scenario: Optional headers column

- **WHEN** the user enables "add headers column" and exports as CSV
- **THEN** the CSV SHALL contain an additional last column titled `Headers` whose cell holds the message headers as a JSON array of objects with `key` and `value`, in their original order including duplicate keys
- **AND** a message without headers SHALL have `[]` in that cell

#### Scenario: Default CSV columns unchanged

- **WHEN** the user exports as CSV without enabling "add headers column"
- **THEN** the CSV SHALL contain exactly the columns it contained before this change, so existing readers keep working

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

When the messages to be exported originate from multiple distinct Kafka topics, the system SHALL generate an individual file in the chosen format for each topic and bundle all generated files into a single `.zip` archive.

#### Scenario: Multi-topic export generates ZIP archive

- **WHEN** the exported message set contains messages from more than one topic
- **THEN** the system SHALL prompt the user to save a `.zip` archive
- **AND** the archive SHALL contain one `<topic_name>.csv`, `<topic_name>.json` or `<topic_name>.ndjson` file, matching the chosen format, for each topic present in the message set
- **AND** each file SHALL keep the displayed order of that topic's messages

### Requirement: Export Scope Matches The Displayed Messages

A message export SHALL contain the messages the active result view displays, in the displayed order: active in-memory search, table column filters and table or view sort SHALL apply. Dimmed non-matching messages SHALL be excluded unless the user enables "include dimmed non-matches". With "only selected messages" enabled, only the selected displayed messages SHALL be exported.

#### Scenario: Table column filter and sort respected

- **WHEN** the table view has a column filter on Partition `1` and is sorted by Offset ascending, and the user exports
- **THEN** the export SHALL contain only messages from partition 1, ordered by ascending offset

#### Scenario: Dimmed non-matches excluded by default

- **WHEN** an in-memory search is active with "show non-matches" enabled and the user exports without enabling "include dimmed non-matches"
- **THEN** the export SHALL contain only the matching messages
- **AND** enabling "include dimmed non-matches" SHALL export matching and dimmed messages in displayed order

#### Scenario: Export only the selection

- **WHEN** three messages are selected and the user enables "only selected messages" and exports
- **THEN** the export SHALL contain exactly those three messages in their displayed order

#### Scenario: No selection

- **WHEN** no message is selected
- **THEN** the "only selected messages" option SHALL NOT be offered and the export SHALL contain all displayed messages

#### Scenario: Export uses loaded messages only

- **WHEN** the user exports messages
- **THEN** the system SHALL serialize only messages already loaded in the view and SHALL NOT issue any Kafka or Schema Registry request

#### Scenario: Export write failure

- **WHEN** the export file cannot be written to the chosen path
- **THEN** the system SHALL show an error notification with the cause and SHALL NOT report a successful export

### Requirement: JSON And NDJSON Export Content

Each exported message in JSON and NDJSON SHALL be one object with `topic`, `partition`, `offset`, `timestamp`, `key` and `payload` as before, plus `timestampIso` (ISO-8601 UTC), `headers` (array of `{key, value}`) and `keySchema` / `valueSchema` (`{schemaId, subject, version}` or `null`). Existing fields keep their names and value types. JSON writes one array; NDJSON writes one compact object per line.

#### Scenario: Metadata present in JSON export

- **WHEN** a message with timestamp `1700000000000`, header `traceId=abc` and value schema subject `orders-value` version 4 id 128 is exported as JSON
- **THEN** its object SHALL contain `"timestamp": "1700000000000"`, `"timestampIso": "2023-11-14T22:13:20.000Z"`, `"headers": [{"key": "traceId", "value": "abc"}]` and `"valueSchema": {"schemaId": 128, "subject": "orders-value", "version": 4}`

#### Scenario: Unknown schema or timestamp shown as unknown

- **WHEN** a message side has no registry schema, or the registry subject or version could not be resolved, or the message timestamp is unavailable (`0`)
- **THEN** the corresponding `keySchema` / `valueSchema` SHALL be `null`, or its `subject` / `version` SHALL be `null`, and `timestampIso` SHALL be `null`

#### Scenario: Tombstone exported as null

- **WHEN** a message without payload (tombstone) or without key is exported as JSON or NDJSON
- **THEN** `payload` or `key` SHALL be `null`
- **AND** a message whose payload text is `null` or empty SHALL NOT be exported with `"payload": null`

#### Scenario: NDJSON export

- **WHEN** the user exports two messages of one topic as NDJSON
- **THEN** the system SHALL prompt to save a `.ndjson` file whose content is exactly two lines, each a complete JSON object of the shape above

#### Scenario: Older export readers

- **WHEN** a consumer of the previous JSON export format reads a new export
- **THEN** every field it read before SHALL be present with the same name and value type

### Requirement: Script Result Files Preserve Message Metadata

Result files that a search or script run saves to the output directory SHALL store each message's headers, key and value schema and ISO-8601 timestamp in addition to the existing fields. Loading run results SHALL restore these fields when present and SHALL still load files written by older versions.

#### Scenario: Metadata survives a run reload

- **WHEN** a script run saved a message with headers and a value schema and the user later opens that run's results
- **THEN** the loaded message SHALL show the same headers and value schema provenance as when it was received

#### Scenario: Older result files

- **WHEN** the user opens a run whose result files lack headers, schema or ISO timestamp fields
- **THEN** the messages SHALL load as before with no headers and no schema provenance, without an error

#### Scenario: Malformed result file

- **WHEN** a result file of a run cannot be parsed
- **THEN** the remaining files of that run SHALL still load and the failure SHALL be logged
