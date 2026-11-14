# Spec Delta

## REMOVED Requirements

### Requirement: DLQ Message Failure Diagnostics and Original Message Navigation

**Reason**: Its scenario *Copying external replay command for message remediation* requires a ready-to-run producer command, which conflicts with the read-only invariant. A MODIFIED block cannot drop a scenario, so the requirement is replaced as a whole.

**Migration**: Replaced by *DLQ Failure Diagnostics, Original Navigation and Failed Message Copy*, which keeps the diagnostics and navigation scenarios unchanged and offers "Copy failed message" instead of the replay command.

## ADDED Requirements

### Requirement: DLQ Failure Diagnostics, Original Navigation and Failed Message Copy

When inspecting a message that contains standard failure headers, the message inspector SHALL render a dedicated Failure Diagnostics panel presenting exception details, providing one-click navigation to the origin message, and offering a copy of the failed message for external reprocessing, without offering any command that writes to Kafka.

#### Scenario: Inspecting message with exception headers displays diagnostics card
- **WHEN** a message contains failure headers such as `x-exception-message`, `kafka_dlt-exception-message`, or `x-exception-stacktrace`
- **THEN** the message inspector SHALL render a prominent Failure Diagnostics card at the top of the payload view
- **AND** display the exception message, exception class, and formatted stack trace

#### Scenario: Navigating from DLQ message to original topic and offset
- **WHEN** the message headers contain `x-original-topic`, `x-original-partition`, and `x-original-offset` (or Spring `kafka_dlt-*` equivalents)
- **THEN** the Failure Diagnostics card SHALL provide a "Jump to Original Message" action
- **AND** tapping the action SHALL open the original topic and seek directly to the specified partition and offset

#### Scenario: Copying the failed message for external reprocessing
- **WHEN** the user chooses "Copy failed message" on the Failure Diagnostics card
- **THEN** the system SHALL copy a JSON document containing the DLQ message's topic, partition, offset, timestamp, key, value and headers, the original topic, partition and offset when known, and the exception message and class when present
- **AND** a null key or value SHALL appear as JSON `null`, distinct from an empty string
- **AND** the system SHALL confirm the copy with a short localized notice

#### Scenario: No producer command is offered
- **WHEN** the Failure Diagnostics card is shown for any message
- **THEN** the card SHALL NOT offer any action that copies or runs a command which writes to Kafka
