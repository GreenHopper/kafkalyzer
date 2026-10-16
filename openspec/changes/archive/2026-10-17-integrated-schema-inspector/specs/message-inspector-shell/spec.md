# Spec Delta

## MODIFIED Requirements

### Requirement: Structured Multi-Tab Inspection
The inspector panel SHALL organize detailed message contents into tabs:
1. `Payload`: displays the message payload using `SmartVirtualJsonTree` with progressive disclosure smart badges, in-tree search, formatting, and copy controls.
2. `Key & Headers`: displays the full message key and a structured list of all Kafka headers with an item count badge.
3. `Raw JSON`: displays the serialized representation of the complete message for export.
4. `Schema`: displays the registered Avro Key and Value schemas for the topic of the inspected message, enabling side-by-side comparison with the live payload and supporting field-level column pinning and filtering.

#### Scenario: Inspect topic schema in dedicated inspector tab
- **WHEN** the user selects the `Schema` tab in `MessageInspectorPanel` while inspecting a Kafka message
- **THEN** the panel body SHALL render the Key and Value Avro schema for the message's topic
- **AND** the user SHALL be able to search the schema and pin fields as table columns directly from the inspector panel

#### Scenario: Inspect Kafka headers in dedicated tab
- **WHEN** the user selects the `Key & Headers` tab for a message containing 3 headers
- **THEN** the tab label SHALL display a badge with the count `3`
- **AND** the panel body SHALL list all 3 headers with their keys and decoded values
- **AND** each header SHALL provide a copy button for its value

#### Scenario: Inspect and copy raw message JSON
- **WHEN** the user selects the `Raw JSON` tab
- **THEN** the panel SHALL display the full message structure (topic, partition, offset, timestamp, key, payload, headers) in indented JSON
- **AND** the user SHALL be able to copy the entire JSON to the clipboard
