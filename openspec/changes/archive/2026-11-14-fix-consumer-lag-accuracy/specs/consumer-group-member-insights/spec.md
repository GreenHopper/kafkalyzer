## MODIFIED Requirements

### Requirement: Unassigned Partition Indication

The system SHALL report topic-partitions of a subscribed topic that no member of the group owns, as a count and a list, so a partition nobody consumes becomes visible. When ownership cannot be determined, because a member's assignment could not be decoded or the group has no members, the system SHALL state that ownership is unknown instead of reporting partitions without owner.

#### Scenario: Partition without owner

- **WHEN** a group subscribes to a topic with three partitions but its members own only two of them
- **THEN** the system SHALL report one unassigned partition for that topic
- **AND** selecting the indicator SHALL list the partition numbers without an owner

#### Scenario: Fully assigned group shows none

- **WHEN** the partitions owned by all members cover every partition of every subscribed topic
- **THEN** the system SHALL report zero unassigned partitions

#### Scenario: Member assignment not decodable

- **WHEN** a group has two members and the assignment of one of them cannot be decoded
- **THEN** the system SHALL NOT report any partition as unassigned for that group
- **AND** it SHALL indicate that partition ownership is unknown for the group
- **AND** the affected member SHALL remain marked as having an unreadable assignment

#### Scenario: Group without members

- **WHEN** a group has no members but has committed offsets for a topic
- **THEN** the system SHALL NOT report the partitions of that topic as unassigned
- **AND** the member section SHALL show its explicit empty state
