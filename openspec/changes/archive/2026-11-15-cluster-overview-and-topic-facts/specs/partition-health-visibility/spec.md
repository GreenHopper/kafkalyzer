## ADDED Requirements

### Requirement: Cluster-Wide Replication Health Summary

The cluster overview SHALL show how many topics of the active cluster have at least one under-replicated or leaderless partition, derived from the latest topic list read. Topics whose partition metadata was unavailable SHALL be counted separately as health unknown and SHALL NOT be counted as healthy. Internal topics SHALL be included in all counts.

#### Scenario: Counting unhealthy topics
- **WHEN** the topic list contains topic A with one under-replicated partition, topic B with one leaderless partition and topic C fully replicated
- **THEN** the overview SHALL show 2 topics with unhealthy partitions
- **AND** it SHALL show the under-replicated and leaderless partition totals as 1 and 1

#### Scenario: Healthy cluster stays neutral
- **WHEN** no topic has an under-replicated or leaderless partition and every topic's health is known
- **THEN** the overview SHALL show zero unhealthy topics without a warning state

#### Scenario: Health unknown for some topics
- **WHEN** the broker gave no usable partition list for two topics
- **THEN** the overview SHALL show 2 topics with unknown health
- **AND** those topics SHALL NOT be counted as healthy or as unhealthy

#### Scenario: Topic list not available
- **WHEN** the topic list failed to load or is still loading
- **THEN** the health summary SHALL be shown as unknown or loading, not as zero unhealthy topics

#### Scenario: Warning not conveyed by colour alone
- **WHEN** at least one topic is unhealthy
- **THEN** the summary SHALL carry a warning icon and text in addition to any warning colour

### Requirement: Unhealthy Topic Drill-Down Filter

Activating the unhealthy-topic count in the cluster overview SHALL show the topic list restricted to topics with at least one under-replicated or leaderless partition, including internal and stream topics that are otherwise hidden. The active restriction SHALL be visible in the topic list with the number of shown topics and SHALL be removable in one action. It SHALL be cleared when the cluster changes and SHALL NOT be persisted.

#### Scenario: Drill-down from the overview
- **WHEN** the overview shows 2 topics with unhealthy partitions and the user activates that count
- **THEN** the topic list SHALL show exactly those 2 topics, even if one of them is an internal topic
- **AND** a visible filter indicator SHALL name the restriction and offer a remove action

#### Scenario: Removing the drill-down filter
- **WHEN** the drill-down filter is active and the user removes it
- **THEN** the topic list SHALL show the topics selected by the user's regular filters again

#### Scenario: No unhealthy topics
- **WHEN** the overview shows zero unhealthy topics
- **THEN** the count SHALL NOT offer the drill-down action

#### Scenario: Filter after a refresh
- **WHEN** the drill-down filter is active and a topic list refresh shows that a topic became fully in-sync
- **THEN** that topic SHALL disappear from the filtered list and the shown count SHALL be updated

#### Scenario: Filter reset on cluster switch
- **WHEN** the drill-down filter is active and the user connects to another cluster or restarts the application
- **THEN** the topic list SHALL be shown without the drill-down filter
