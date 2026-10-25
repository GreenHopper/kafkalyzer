# Spec Delta

## MODIFIED Requirements

### Requirement: Topic Message Volume and Size Aggregation

The system SHALL scan topic partitions to compute the exact total number of messages, total payload bytes, average message payload size, minimum and maximum message sizes, and the 50th, 95th and 99th percentile of message payload size across all assigned partitions.

#### Scenario: Full topic volume scan

- **WHEN** the user initiates a content analysis scan on a topic
- **THEN** the system SHALL iterate through all assigned partitions from their starting offset to high watermarks
- **AND** calculate the aggregate count of messages, total payload bytes, and average payload size

#### Scenario: Empty topic scan

- **WHEN** the user initiates an analysis scan on an empty topic
- **THEN** the system SHALL immediately complete the scan and report zero messages, zero bytes, and an empty distribution summary

#### Scenario: Percentile size summary

- **WHEN** a content analysis scan completes over messages whose payload sizes vary
- **THEN** the report SHALL show the 50th, 95th and 99th percentile payload size in bytes
- **AND** each percentile value SHALL lie between the reported minimum and maximum payload size

#### Scenario: Percentiles on a single message

- **WHEN** a content analysis scan completes over exactly one message
- **THEN** the 50th, 95th and 99th percentile SHALL equal that message payload size

### Requirement: Message Key Frequency Analysis

The system SHALL analyze message keys to identify top recurring keys, the count of null keys, key frequency distribution, and an estimate of how many distinct keys occur in the scanned range.

#### Scenario: Identifying top recurring keys

- **WHEN** messages with non-null keys are scanned
- **THEN** the system SHALL track key occurrences and rank the top most frequent keys with their respective counts and percentages
- **AND** calculate the total number of records with null keys

#### Scenario: Distinct key estimate

- **WHEN** a scan covers 100000 messages carrying 400 different key values
- **THEN** the report SHALL show an estimated distinct key count
- **AND** the estimate SHALL be labeled as an estimate rather than an exact count

#### Scenario: All keys null

- **WHEN** every scanned message has a null key
- **THEN** the distinct key estimate SHALL be zero
- **AND** the null key count SHALL equal the scanned message count
