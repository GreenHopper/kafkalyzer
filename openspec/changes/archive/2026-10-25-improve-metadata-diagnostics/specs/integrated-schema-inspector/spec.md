# Spec Delta

## ADDED Requirements

### Requirement: Inspector Opened For An Explicit Subject And Version

The schema inspector SHALL be openable for a subject and version chosen by the user from outside the topic schema list, such as the schema recorded for a single message, and SHALL present that exact version rather than the latest version of the subject.

#### Scenario: Open a message schema version

- **WHEN** the user opens the schema of a message that was encoded with subject `orders-value` version 4
- **THEN** the inspector SHALL load subject `orders-value` and display version 4
- **AND** the version selector SHALL show version 4 as the active selection

#### Scenario: Switch to another version of the same subject

- **WHEN** the user changes the version selector while the inspector was opened from a message
- **THEN** the inspector SHALL show the newly selected version of the same subject
- **AND** returning to version 4 SHALL show the schema definition the message referenced

#### Scenario: Subject or version no longer present

- **WHEN** the requested subject or version can no longer be retrieved from the Schema Registry
- **THEN** the inspector SHALL show its existing error state for that subject
- **AND** the requesting view SHALL keep showing the subject, version and schema id it received from the message

#### Scenario: Non-blocking behavior is preserved

- **WHEN** the inspector is opened from a message while a message stream is running
- **THEN** the stream SHALL keep delivering messages without interruption
- **AND** the inspector SHALL show a loading state until the schema version is available
