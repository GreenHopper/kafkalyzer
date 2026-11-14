## MODIFIED Requirements

### Requirement: Timeline Coverage Indication

The report SHALL record from which moment on the scanned data is complete and, when the scan stopped before the log end, until which moment it is complete. When the selected recent window or a listed day lies partly outside that coverage, the system SHALL mark it as partially covered instead of presenting missing data as low volume. A scan of a partition subset SHALL be marked as covering only the selected partitions.

#### Scenario: Sampled scan does not cover the window

- **WHEN** the user scanned only the last 10,000 messages and these reach back 5 hours, and the 24-hour window is selected
- **THEN** the view SHALL indicate that only the last 5 hours of the window are covered by the scan
- **AND** hours before the coverage start SHALL be visually distinguished from hours with zero messages

#### Scenario: Partially covered day

- **WHEN** the coverage start lies within a day of the daily distribution
- **THEN** that day SHALL be marked as partially covered

#### Scenario: Full scan

- **WHEN** a full scan of all retained messages completes
- **THEN** no part of the timeline SHALL be marked as partially covered

#### Scenario: Oldest messages scan ends before the window

- **WHEN** the user scanned the oldest 5,000 messages, these end 3 days before the scan moment, and the 24-hour window is selected
- **THEN** the whole window SHALL be marked as not covered by the scan
- **AND** the hours SHALL NOT be presented as hours with zero messages

#### Scenario: Time range with an end

- **WHEN** the user scanned the range 2026-11-20 14:00 to 16:00 local time
- **THEN** hours before 14:00 and from 16:00 on SHALL be marked as not covered
- **AND** the day 2026-11-20 SHALL be marked as partially covered

#### Scenario: Partition subset

- **WHEN** the user scanned partitions 0 and 3 of a 6-partition topic
- **THEN** the recent hours view and the daily distribution SHALL state that they cover only partitions 0 and 3

#### Scenario: Coverage end not recorded

- **WHEN** the displayed report does not record a coverage end
- **THEN** the timeline SHALL use only the coverage start as before
