## MODIFIED Requirements

### Requirement: Consumer Lag Display
The system SHALL calculate and display the lag for each partition of a consumer group's topics. Every partition the group has a committed offset for, or is subscribed to, SHALL be listed with one of three outcomes: a known lag, "no commit", or "unknown" with its reason. A partition SHALL NOT be omitted, and "no commit" or "unknown" SHALL NOT be shown as a lag of 0.

#### Scenario: View consumer lag
- **WHEN** the user views a specific consumer group
- **THEN** the system displays the topics, partitions, log end offsets, current offsets, and the computed lag

#### Scenario: Partition without committed offset
- **WHEN** a group is subscribed to a topic with three partitions and has committed offsets for only two of them
- **THEN** the system SHALL list all three partitions
- **AND** the partition without a committed offset SHALL be marked "no commit" instead of showing a committed offset or a lag value

#### Scenario: Log end offset cannot be read
- **WHEN** the log end offset of a partition cannot be read, for example because its leader is unavailable
- **THEN** the system SHALL list the partition with lag "unknown" and the reason
- **AND** the group's total lag SHALL be shown as unknown instead of a sum that silently leaves the partition out

#### Scenario: Topic metadata not readable
- **WHEN** the metadata of one of the group's topics cannot be read, for example because describe access is denied
- **THEN** the system SHALL show that topic as not readable with the reason
- **AND** it SHALL NOT drop the topic from the group's topics

### Requirement: Refresh Consumer Lag
The system SHALL provide a way to refresh the consumer lag data to view the most current state. A refresh cycle SHALL NOT start while the previous cycle is still running, and results of an outdated cycle SHALL be discarded.

#### Scenario: Refresh lag data
- **WHEN** the user clicks the refresh button or triggers an auto-refresh
- **THEN** the system fetches the latest offsets and updates the displayed lags

#### Scenario: Auto-refresh fires while a cycle is running
- **WHEN** the auto-refresh interval elapses while the previous refresh cycle has not finished
- **THEN** the system SHALL NOT start a second cycle
- **AND** the running cycle SHALL complete and its results SHALL be shown

#### Scenario: Manual refresh while a cycle is running
- **WHEN** the user requests a refresh while a refresh cycle is running
- **THEN** the system SHALL indicate that a refresh is in progress and SHALL NOT start a parallel cycle

#### Scenario: Outdated results are discarded
- **WHEN** the active cluster changes while lag queries of the previous cluster are still running
- **THEN** results of those queries SHALL NOT be shown for the new cluster

## ADDED Requirements

### Requirement: Lag Of Groups Without Active Members
For a consumer group without active members, for example a stopped group in state `Empty`, the system SHALL determine the group's topics, partitions and lag from the group's committed offsets. When the committed offsets cannot be read, the group's lag SHALL be shown as unknown with the reason, never as 0.

#### Scenario: Stopped group with backlog
- **WHEN** a group with no members has committed offset 100 on a partition whose log end offset is 150
- **THEN** the system SHALL show that partition with lag 50
- **AND** the group's total lag SHALL include those 50 messages

#### Scenario: Committed offsets not readable
- **WHEN** reading the committed offsets of a group without members fails, for example because of missing group describe permission or an unavailable group coordinator
- **THEN** the system SHALL show the group's lag as unknown with the reason
- **AND** it SHALL NOT show a lag of 0

#### Scenario: Group without any committed offset
- **WHEN** a group without members has no committed offsets at all
- **THEN** the system SHALL state that the group has no committed offsets
- **AND** it SHALL NOT show a lag value for the group

### Requirement: Group Lag Errors Stay Visible
A failure to read the lag of one group SHALL NOT remove the group from the list or fail the lag of other groups. The error of each failed group SHALL remain retrievable from the group row and the group details until the next successful read, together with a retry action.

#### Scenario: One group fails in a batch
- **WHEN** lag is read for several groups at once and reading one of them fails
- **THEN** the other groups SHALL show their lag
- **AND** the failed group SHALL remain listed with an error indication

#### Scenario: Inspect and retry a failed group
- **WHEN** the user inspects the error indication of a failed group
- **THEN** the system SHALL show the error reason
- **AND** the user SHALL be able to retry reading that group's lag

### Requirement: Complete Lag Aggregates Across Groups
The total-lag summary and sorting by lag SHALL cover every group in the list. Until the lag of every listed group is known, the system SHALL show how many of the listed groups are loaded ("n of m") and SHALL load the remaining groups in the background within the configured query concurrency limit. A group without a known lag SHALL NOT count or rank as 0.

#### Scenario: Total lag while groups are loading
- **WHEN** 40 groups are listed and the lag of 25 of them is known
- **THEN** the total-lag summary SHALL indicate "25 of 40" loaded
- **AND** the remaining 15 groups SHALL be loaded without the user scrolling them into view

#### Scenario: Sorting by lag with unknown values
- **WHEN** the user sorts the groups by lag while some groups have no known lag
- **THEN** groups with a known lag SHALL be ordered by that lag
- **AND** groups without a known lag SHALL be placed after them in both sort directions

#### Scenario: Total lag with a failed group
- **WHEN** the lag of every listed group was read and one group failed
- **THEN** the total-lag summary SHALL indicate that it is incomplete
- **AND** it SHALL NOT present the sum of the remaining groups as the complete total

### Requirement: Lag Reading Stays Read-Only
Reading group lists, members, committed offsets and log end offsets SHALL use read-only cluster queries only. The application SHALL NOT join a consumer group, subscribe, assign partitions of the group, or commit or reset offsets while reading lag, including for groups without active members.

#### Scenario: Reading lag of a stopped group
- **WHEN** the user repeatedly reads the lag of a group without members
- **THEN** the group SHALL still report no members afterwards
- **AND** its committed offsets SHALL be unchanged by those reads

#### Scenario: Reading lag of a running group
- **WHEN** the user reads the lag of a group with active members
- **THEN** the group's member list SHALL be unchanged by the read
- **AND** no rebalance SHALL be triggered by the application
