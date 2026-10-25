# Spec Delta

## Purpose

Shows which clients make up a consumer group and which topic-partitions each of them owns, so a stalled or missing consumer can be identified instead of only counting members.

## ADDED Requirements

### Requirement: Consumer Group Member Identity

For a consumer group with at least one member, the system SHALL list every member with its member id, client id, client host, and the number of topic-partitions assigned to it.

#### Scenario: Member list for a running group

- **WHEN** the user opens the details of a consumer group that has three members
- **THEN** the system SHALL show three member rows
- **AND** each row SHALL show member id, client id, client host and assigned partition count

#### Scenario: Empty group

- **WHEN** the user opens the details of a consumer group that currently has no members
- **THEN** the system SHALL show an explicit empty state for members
- **AND** it SHALL NOT render a member row with blank values

#### Scenario: Client host unavailable

- **WHEN** the cluster reports a member without a client host
- **THEN** the system SHALL show a placeholder for the host
- **AND** the remaining member fields SHALL still be shown

### Requirement: Member To Partition Assignment

The system SHALL show, for each consumer group, which member owns which topic-partition, listing topic, partition and owning member together.

#### Scenario: Assignment table

- **WHEN** the user views the assignment of a group consuming two topics with three partitions each
- **THEN** the system SHALL list one entry per assigned topic-partition
- **AND** each entry SHALL name the owning member

#### Scenario: Assignment follows the group state

- **WHEN** the user refreshes the lag of a group after a rebalance moved a partition to another member
- **THEN** the assignment table SHALL show the partition owned by the new member after the refresh
- **AND** the previous member SHALL no longer list that partition

#### Scenario: Source for the assignment

- **WHEN** the assignment is rendered
- **THEN** it SHALL be derived from the group membership the cluster reports for that group
- **AND** it SHALL NOT require the application to join or modify the consumer group

### Requirement: Unassigned Partition Indication

The system SHALL report topic-partitions of a subscribed topic that no member of the group owns, as a count and a list, so a partition nobody consumes becomes visible.

#### Scenario: Partition without owner

- **WHEN** a group subscribes to a topic with three partitions but its members own only two of them
- **THEN** the system SHALL report one unassigned partition for that topic
- **AND** selecting the indicator SHALL list the partition numbers without an owner

#### Scenario: Fully assigned group shows none

- **WHEN** the partitions owned by all members cover every partition of every subscribed topic
- **THEN** the system SHALL report zero unassigned partitions

### Requirement: Member View Stays Read-Only

All member and assignment information SHALL be obtained through read-only cluster queries, and the application SHALL NOT join a consumer group, commit offsets, or change group membership while presenting it.

#### Scenario: No consumer group membership is created

- **WHEN** the user opens the member view of any consumer group repeatedly
- **THEN** the group's member list as reported by the cluster SHALL be unchanged by those reads
- **AND** no committed offset SHALL be written by the application
