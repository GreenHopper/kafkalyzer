## MODIFIED Requirements

### Requirement: Bounded Memory Tracking

To support scanning large topics with millions of messages, duplicate message tracking SHALL use memory-efficient fingerprint hashing and enforce bounded tracking structures for top duplicate samples. The set of tracked fingerprints SHALL have a fixed upper limit, SHALL NOT be copied for intermediate progress results, and reaching the limit SHALL mark the duplicate figures as estimated.

#### Scenario: High volume scan
- **WHEN** a scan processes hundreds of thousands or millions of messages
- **THEN** duplicate tracking SHALL operate via compact hash representations without storing full payload copies of non-duplicate messages in memory

#### Scenario: Fingerprint limit not reached
- **WHEN** a scan sees fewer distinct messages than the fingerprint limit
- **THEN** the unique and duplicate counts SHALL be exact
- **AND** the duplicate figures SHALL NOT be marked as estimated

#### Scenario: Fingerprint limit reached
- **WHEN** a scan sees more distinct messages than the fingerprint limit
- **THEN** the number of tracked fingerprints SHALL NOT exceed the limit
- **AND** messages whose fingerprint could no longer be tracked SHALL be counted as unique
- **AND** the duplicate summary card and the duplicate section SHALL label the duplicate count and rate as an estimate that is a lower bound, together with the number of untracked messages

#### Scenario: Duplicate sample table full
- **WHEN** more distinct duplicated messages occur than the duplicate sample table holds
- **THEN** the top duplicated messages list SHALL be labelled as possibly incomplete

#### Scenario: Duplicates across partitions read in parallel
- **WHEN** two identical messages are stored in different partitions that are read by different scan workers
- **THEN** the second message SHALL be counted as a duplicate

#### Scenario: Older report without estimate information
- **WHEN** the displayed report does not contain fingerprint limit information
- **THEN** the duplicate figures SHALL be shown without the estimate label
