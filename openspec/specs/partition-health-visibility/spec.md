# partition-health-visibility Specification

## Purpose

Exposes the replication state Kafka already reports for every partition, so a user can see which partition is leaderless or under-replicated and which broker is missing from a replica set.

## Requirements

### Requirement: Per-Partition Replication Metadata

For every topic, the system SHALL expose the replication state of each partition: the leader broker id, the replica broker ids, and the in-sync replica broker ids, and SHALL list them per partition in the topic detail view.

#### Scenario: Partition table lists replication state

- **WHEN** the user opens the detail view of a topic with three partitions
- **THEN** the view SHALL show one row per partition from 0 to 2
- **AND** each row SHALL show the leader broker id, the replica broker ids and the in-sync replica broker ids

#### Scenario: Broker id resolution

- **WHEN** replication metadata references brokers that exist in the cluster broker list
- **THEN** the system SHALL show the broker id together with its host and port where available
- **AND** the leader SHALL be visually distinguished from the followers

#### Scenario: Metadata unavailable for a topic

- **WHEN** metadata for a topic reports an error instead of partitions
- **THEN** the system SHALL mark the partition rows as unavailable rather than showing empty replica sets
- **AND** no partition SHALL be reported as healthy

### Requirement: Under-Replicated Partition Detection

The system SHALL classify a partition as under-replicated when its number of in-sync replicas is lower than the number of its configured replicas, and SHALL report the count of under-replicated partitions per topic.

#### Scenario: Replica out of sync

- **WHEN** a partition has replicas [1, 2, 3] and in-sync replicas [1, 2]
- **THEN** the system SHALL classify that partition as under-replicated
- **AND** the topic SHALL show an under-replicated partition count of one

#### Scenario: Fully replicated topic stays neutral

- **WHEN** every partition of a topic has in-sync replicas equal to its replica set
- **THEN** the topic SHALL show zero under-replicated partitions
- **AND** no warning state SHALL be shown for that topic

### Requirement: Leaderless Partition Detection

The system SHALL classify a partition as leaderless when no leader broker is assigned to it, and SHALL report the count of leaderless partitions per topic.

#### Scenario: Broker loss leaves a partition without leader

- **WHEN** a partition reports no leader broker id
- **THEN** the system SHALL classify that partition as leaderless
- **AND** the topic SHALL show a leaderless partition count of one

#### Scenario: Leaderless partition is highlighted in the topic list

- **WHEN** a topic has at least one leaderless partition and the topic list is rendered
- **THEN** that topic SHALL carry a distinct warning indicator in the topic list
- **AND** selecting it SHALL open the detail view with the affected partition rows marked

### Requirement: Health Indicators Reflect the Latest Metadata Read

Replication health indicators SHALL be derived from the most recent metadata read for that cluster session, and SHALL be refreshed whenever the user refreshes the topic list or the topic detail view.

#### Scenario: Health updates after a refresh

- **WHEN** a partition becomes fully in-sync and the user triggers a metadata refresh
- **THEN** the under-replicated count for that topic SHALL drop to zero after the refresh completes
- **AND** the topic list warning indicator SHALL disappear

#### Scenario: Stale health state after disconnect

- **WHEN** the cluster connection is closed
- **THEN** the system SHALL stop showing health indicators as current
- **AND** previously shown counts SHALL NOT be presented as live values
