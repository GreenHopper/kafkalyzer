# Spec Delta

## MODIFIED Requirements

### Requirement: Load Failure Error States in Explorer

A failure while consuming messages, loading the topic list or loading Schema Registry subjects SHALL be shown as a localized error state that names the cause and offers a "Retry" action, visibly distinct from the corresponding empty state. A failure SHALL NOT be shown as zero messages, zero topics or "no schema". Retry SHALL repeat only the same read-only fetch. A cluster without a configured Schema Registry is not a subject load failure.

#### Scenario: Consumption failure before any message arrived
- **WHEN** message consumption for a topic tab fails (for example a broker, authentication or decoding error) before any message was received
- **THEN** the message area SHALL show an error state with an error title, the failure cause and a "Retry" action
- **AND** it SHALL NOT show the "No messages loaded yet" card

#### Scenario: Consumption failure after some messages arrived
- **WHEN** message consumption fails after some messages were already received
- **THEN** the received messages SHALL remain visible
- **AND** an inline error notice with the cause and a "Retry" action SHALL be shown above them, so the partial result is not mistaken for a complete one

#### Scenario: Retrying a failed consumption
- **WHEN** the user activates "Retry" in the consumption error state
- **THEN** the system SHALL start the same read-only consumption with the current search configuration
- **AND** the error state SHALL be cleared when the new attempt starts

#### Scenario: Topic list fails to load
- **WHEN** loading the topic list of the active cluster fails and no earlier topic list of that cluster is held
- **THEN** the explorer sidebar SHALL show an error state with the cause and a "Retry" action in place of the topic list
- **AND** it SHALL NOT show an empty topic list or a topic count of 0

#### Scenario: Topic list refresh fails while an earlier list is shown
- **WHEN** refreshing the topic list fails while an earlier topic list of the same cluster is shown
- **THEN** the earlier list SHALL stay visible
- **AND** the sidebar SHALL show an inline notice with the cause and a "Retry" action above the list
- **AND** the list age SHALL keep showing the time of the earlier successful load, so the list is not mistaken for current

#### Scenario: Retrying the topic list
- **WHEN** the user activates "Retry" in the topic list error state
- **THEN** the system SHALL reload the topic list with the same read-only metadata request and show the loading indicator while it runs

#### Scenario: Schema Registry subjects fail to load
- **WHEN** loading the Schema Registry subjects of a cluster with a configured Schema Registry fails
- **THEN** the explorer sidebar SHALL show an inline notice with the cause and a "Retry" action
- **AND** the schema inspector of a topic SHALL show the load error instead of stating that the topic has no schema

#### Scenario: Cluster without Schema Registry
- **WHEN** the active cluster has no Schema Registry configured
- **THEN** no subject load error SHALL be shown

#### Scenario: Localized error states
- **WHEN** the application runs under German or English locale
- **THEN** the error titles, notices and "Retry" labels SHALL be localized; the failure cause SHALL be shown as reported

## ADDED Requirements

### Requirement: Opening Topics Not in the Loaded List

A topic opened by name that is not in the loaded topic list SHALL get its metadata with a read-only request for that topic. This applies to recently viewed topics, the cluster overview, favourites, Quick Jump and DLQ "jump to original". Until the metadata arrives, and when it cannot be read, partitions, replication factor, health, retention and cleanup policy SHALL be shown as unknown. No placeholder value SHALL be shown.

#### Scenario: Opening a recent topic missing from the list
- **WHEN** the user opens a recently viewed topic that is not in the loaded topic list
- **THEN** the system SHALL load the metadata of that topic with a read-only request and show a loading indicator
- **AND** the opened tab SHALL show the loaded partition count, replication factor and health

#### Scenario: Topic that cannot be described
- **WHEN** the single-topic request reports that describing the topic is not authorized
- **THEN** the tab SHALL open and its header SHALL show "not readable — permission?"
- **AND** partitions, replication factor, health, retention and cleanup policy SHALL be shown as unknown, never as 0, 1, "delete" or a retention of 0

#### Scenario: Topic that no longer exists
- **WHEN** the single-topic request reports that the topic does not exist
- **THEN** the tab header SHALL show "topic not found" and SHALL NOT show partition or configuration values

#### Scenario: Single-topic request fails
- **WHEN** the single-topic request fails, for example because the broker is unreachable
- **THEN** no tab SHALL be opened with made-up metadata
- **AND** the user SHALL see the cause in a localized error message with a "Retry" action

#### Scenario: Jumping to a topic hidden by the sidebar filter
- **WHEN** Quick Jump or the DLQ "jump to original" targets a topic that is in the loaded list but hidden by the sidebar filters
- **THEN** the topic SHALL open with its loaded metadata
- **AND** the jump SHALL NOT silently do nothing

#### Scenario: Unknown partition count disables partition prediction
- **WHEN** a tab shows an unknown partition count
- **THEN** the Fast Trace partition preview SHALL be off for that tab, as for any topic without a known partition count
