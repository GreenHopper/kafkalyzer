# Spec Delta

## Purpose

Enables automated detection, visual sidebar grouping, and contextual incident diagnostics for Kafka retry and dead-letter queue (DLQ) topics and standardized failure headers.

## ADDED Requirements

### Requirement: Automatic Detection of Retry and Dead-Letter Topics

The system SHALL automatically identify retry and dead-letter queue topics by evaluating cluster topic names against established naming patterns, associating them with their respective primary topics.

#### Scenario: Topic matching DLQ suffix is recognized as dead-letter queue

- **WHEN** the cluster contains topics matching patterns such as `*-dlq`, `*-DLQ`, `*.dlq`, `*.DLQ`, `*-dlt`, or `*_dlq`
- **THEN** the system SHALL classify the topic as a dead-letter queue
- **AND** map it to its corresponding base topic

#### Scenario: Topic matching retry pattern is recognized as retry queue

- **WHEN** the cluster contains topics matching patterns such as `*-retry`, `*-retry-*`, or `*.retry`
- **THEN** the system SHALL classify the topic as an intermediate retry queue
- **AND** determine its retry progression relative to the base topic

### Requirement: Visual Grouping and Badging in Topic Sidebar

The Explorer topic sidebar and topic detail headers SHALL visually distinguish retry and DLQ topics with distinct badges and support grouping them alongside their parent topic.

#### Scenario: Primary topic displays badge for related failure topics

- **WHEN** a primary topic has one or more associated retry or DLQ topics
- **THEN** the topic item in the sidebar SHALL display an indicator showing the count of related retry and DLQ topics
- **AND** allow expanding a sub-tree to quickly inspect the associated failure queues

#### Scenario: DLQ topic displays parent link badge

- **WHEN** a DLQ topic is selected and inspected
- **THEN** the header SHALL display a badge identifying it as a Dead-Letter Queue
- **AND** provide a direct link to open the primary origin topic

### Requirement: DLQ Message Failure Diagnostics and Original Message Navigation

When inspecting a message that contains standard failure headers, the message inspector SHALL render a dedicated Failure Diagnostics panel presenting exception details and providing one-click navigation to the origin message.

#### Scenario: Inspecting message with exception headers displays diagnostics card

- **WHEN** a message contains failure headers such as `x-exception-message`, `kafka_dlt-exception-message`, or `x-exception-stacktrace`
- **THEN** the message inspector SHALL render a prominent Failure Diagnostics card at the top of the payload view
- **AND** display the exception message, exception class, and formatted stack trace

#### Scenario: Navigating from DLQ message to original topic and offset

- **WHEN** the message headers contain `x-original-topic`, `x-original-partition`, and `x-original-offset` (or Spring `kafka_dlt-*` equivalents)
- **THEN** the Failure Diagnostics card SHALL provide a "Jump to Original Message" action
- **AND** tapping the action SHALL open the original topic and seek directly to the specified partition and offset

#### Scenario: Copying external replay command for message remediation

- **WHEN** the user chooses to remediate or replay a DLQ message externally
- **THEN** the Failure Diagnostics card SHALL provide a "Copy Replay Command" action
- **AND** copy a pre-formatted CLI command (such as `kcat`) targeting the original topic with message key and payload
