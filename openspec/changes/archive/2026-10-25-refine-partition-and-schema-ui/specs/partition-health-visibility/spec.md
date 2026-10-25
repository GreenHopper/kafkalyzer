# Spec Delta: partition-health-visibility

## MODIFIED Requirements

### Requirement: Per-Partition Replication Metadata

For every topic, the system SHALL expose the replication state of each partition: the leader broker id, the replica broker ids, and the in-sync replica broker ids. In the topic detail view, this replication breakdown SHALL be accessible on demand through interactive header actions or in the Topic Analysis tab, rather than occupying a permanent, static table above the message search bar.

#### Scenario: Partition table lists replication state

- **WHEN** the user opens the partition replication breakdown for a topic with three partitions
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
