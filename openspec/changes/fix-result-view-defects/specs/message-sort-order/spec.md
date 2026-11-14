## MODIFIED Requirements

### Requirement: Ordering of displayed messages by selected field
Displayed messages SHALL be ordered by the selected sort field according to the selected ascending or descending order. Supported fields are timestamp, partition, offset, key, and value (payload). Ascending MUST place smaller/earlier values first. Descending MUST place larger/later values first. Null or missing key/value fields MUST sort consistently (treated as empty for comparison). Messages that compare equal on the selected field MUST be ordered by topic, then partition, then offset, in the same direction as the selected order, so the resulting order is total and does not change between refreshes. The same tie-breakers apply to table column-header sorting, to view-specific orderings (such as script run views) and to aggregated multi-topic result lists.

#### Scenario: Descending order shows newest first
- **WHEN** sort field is timestamp and sort order is descending
- **AND** multiple messages with different timestamps are displayed
- **THEN** the first visible message SHALL be the one with the newest timestamp

#### Scenario: Ascending order shows oldest first
- **WHEN** sort field is timestamp and sort order is ascending
- **AND** multiple messages with different timestamps are displayed
- **THEN** the first visible message SHALL be the one with the oldest timestamp

#### Scenario: Ascending offset shows lowest offset first
- **WHEN** sort field is offset and sort order is ascending
- **AND** multiple messages with different offsets are displayed
- **THEN** the first visible message SHALL be the one with the lowest offset

#### Scenario: Descending key sorts keys reverse lexicographically
- **WHEN** sort field is key and sort order is descending
- **AND** multiple messages with different keys are displayed
- **THEN** the first visible message SHALL be the one whose key is last in lexicographic order among those keys

#### Scenario: Equal timestamps are ordered by topic, partition and offset
- **WHEN** sort field is timestamp and sort order is descending
- **AND** several displayed messages share the same millisecond timestamp
- **THEN** those messages SHALL be ordered by topic, then partition, then offset, each descending

#### Scenario: Order of equal keys is stable across live updates
- **WHEN** messages with equal values in the selected sort field are displayed while new messages keep arriving
- **THEN** the relative order of the already displayed messages SHALL NOT change between updates

#### Scenario: Table column-header sort uses the same tie-breakers
- **WHEN** the table is sorted by a column header
- **AND** several rows have the same value in that column
- **THEN** those rows SHALL be ordered by topic, then partition, then offset, in the direction of the column sort

#### Scenario: View-specific ordering falls back to the tie-breakers
- **WHEN** a result view uses its own ordering (such as chronological or by-topic in a script run view)
- **AND** two messages are equal under that ordering
- **THEN** they SHALL be ordered by topic, then partition, then offset, ascending
