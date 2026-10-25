# Shareable Message References Specification

## Purpose

Defines standardized shareable reference URIs, clipboard export affordances, and quick-jump resolution mechanisms allowing engineers to share, restore, and seek exact message locations across kafkalyzer instances.

## Requirements

### Requirement: Shareable Message Link Generation and Clipboard Export

The system SHALL generate a standardized, human-readable reference URI and compact reference token for any selected Kafka message, providing direct copy affordances in the message inspector and table context menus.

#### Scenario: Copying shareable message link from inspector header
- **WHEN** a user selects a message in the message viewer and triggers the "Copy Shareable Link" action
- **THEN** the system SHALL construct a reference URI containing cluster name, topic name, partition, and offset
- **AND** copy the formatted URI to the system clipboard with visual confirmation

#### Scenario: Copying shareable message link from table context menu
- **WHEN** a user right-clicks on a message row in the message table
- **THEN** the context menu SHALL display a "Copy Message Link" action
- **AND** copy the reference URI for that message to the clipboard

### Requirement: Quick-Jump Reference Resolution and Message Seeking

The system SHALL provide a Quick-Jump dialog accessible via global keyboard shortcut (`Ctrl+G` / `Cmd+G`) or navigation bar action that resolves a pasted reference link, activates the target cluster, opens the topic tab, seeks to the partition and offset, and selects the message.

#### Scenario: Opening valid reference link navigates directly to target message
- **WHEN** the user pastes a valid `kafkalyzer://` message reference into the Quick-Jump dialog
- **THEN** the system SHALL parse the cluster, topic, partition, and offset
- **AND** open the corresponding topic tab, seek to the partition and offset, and select the message in the inspector

#### Scenario: Reference targeting unconfigured cluster prompts cluster selection
- **WHEN** the pasted reference link specifies a cluster name not found in the local configuration
- **THEN** the system SHALL display a prompt asking the user to choose an existing cluster profile to use for the topic lookup
- **AND** proceed with topic navigation upon selection

#### Scenario: Invalid or malformed reference string displays inline error
- **WHEN** the user inputs an unparseable or malformed string into the Quick-Jump dialog
- **THEN** the dialog SHALL indicate an invalid reference format
- **AND** keep the input field focused without triggering navigation

### Requirement: Filter Context Preservation in Shared References

The system SHALL support encoding optional search query parameters and scan filters into the shareable reference URI, allowing recipients to restore the exact filter criteria under which the message was discovered.

#### Scenario: Copying message link preserves active search phrase
- **WHEN** a message is selected while an active search filter query is applied
- **THEN** the generated reference URI SHALL include the search filter query parameter
- **AND** resolving the reference SHALL populate the search input and highlight matching terms in the message
