## MODIFIED Requirements

### Requirement: Cluster Overview Dashboard Empty State

When a cluster is actively selected but no topic tab is open in the Explorer view, the main content area SHALL display an informative cluster overview showing cluster connection metadata, the brokers of the cluster, total topic and partition counts, the replication health summary, Schema Registry status, and quick access to recently viewed topics for that cluster. Values that could not be read SHALL be shown as unknown, never as 0.

#### Scenario: Displaying cluster overview metrics
- **WHEN** an active cluster connection is established and all topic tabs are closed
- **THEN** the Explorer main content area SHALL display the cluster name, bootstrap server address, total number of topics, and Schema Registry configuration indicator
- **AND** display quick-launch cards or list items for recently opened topics belonging to this cluster

#### Scenario: Opening a recent topic from the cluster overview
- **WHEN** the user clicks on a recent topic card in the cluster overview
- **THEN** the system SHALL open a new search tab for that topic and focus it

#### Scenario: Broker list in the overview
- **WHEN** the cluster overview is shown and the cluster metadata read returned three brokers
- **THEN** the overview SHALL list three brokers, each with broker id, host and port, ordered by broker id
- **AND** the number of brokers SHALL be shown

#### Scenario: Topic and partition totals
- **WHEN** the topic list of the active cluster is loaded with 12 topics holding 40 partitions in total
- **THEN** the overview SHALL show 12 topics and 40 partitions

#### Scenario: Topic list not available
- **WHEN** the topic list of the active cluster is still loading or failed to load
- **THEN** the overview SHALL show the topic and partition totals as loading or unknown
- **AND** it SHALL NOT show 0 topics or 0 partitions

#### Scenario: Cluster id and controller shown only when reported
- **WHEN** the broker reported a cluster id and a controller broker id
- **THEN** the overview SHALL show the cluster id and the controller broker id together with its host and port
- **AND** when the broker did not report a controller, the controller SHALL be shown as unknown
- **AND** when the broker did not report a cluster id, no cluster id SHALL be shown and none SHALL be made up

#### Scenario: Broker metadata read fails
- **WHEN** reading the broker metadata for the overview fails, for example because the broker is unreachable or access is denied
- **THEN** the broker section SHALL show an error state naming the cause and a "Retry" action
- **AND** a denied access SHALL be labelled as "not readable" and SHALL NOT be shown as an empty broker list
- **AND** the rest of the overview SHALL stay usable

#### Scenario: Refreshing the overview
- **WHEN** the user activates the refresh action in the cluster overview
- **THEN** the system SHALL re-read the broker metadata and reload the topic list with the same read-only requests
- **AND** a loading indicator SHALL be shown until both reads have finished

#### Scenario: Overview reads stay read-only
- **WHEN** the cluster overview reads broker metadata
- **THEN** the system SHALL send only metadata requests and SHALL NOT create, alter or delete any topic, configuration, offset or consumer group

#### Scenario: Localized overview
- **WHEN** the application runs under German or English locale
- **THEN** all labels, counts, unknown markers and error texts of the overview SHALL be localized
