## ADDED Requirements

### Requirement: Fast Trace Target Partition Preview

While Fast Trace is enabled in the topic search configuration, the system SHALL show, before the scan starts, the partition the entered key hashes to and the partition count used. The shown partition MUST be computed by the same routine and from the same key the scan uses, so the previewed partition and the scanned partition are always identical for the same key and partition count. The preview SHALL be pure computation and SHALL NOT contact the cluster.

#### Scenario: Partition shown for an entered key

- **WHEN** Fast Trace is enabled, the topic metadata reports 12 partitions and the user enters the key `order-4711`
- **THEN** the search configuration SHALL show the target partition for that key together with the partition count 12
- **AND** starting the scan SHALL read exactly that partition

#### Scenario: Matches the Java default partitioner

- **WHEN** the preview is computed for a key and a partition count
- **THEN** the partition SHALL equal `(murmur2(UTF-8 bytes of the key) & 0x7fffffff) mod partition count`, as computed by the Java client's default partitioner for a string key

#### Scenario: Preview follows key edits

- **WHEN** the user changes the key text while Fast Trace is enabled
- **THEN** the preview SHALL update to the partition of the new key without starting a scan
- **AND** a result for an outdated key text MUST NOT replace the result for the current key text

#### Scenario: Collapsed advanced panel

- **WHEN** Fast Trace is enabled and the advanced filter panel is collapsed
- **THEN** the Fast Trace chip in the compact search bar SHALL include the target partition

#### Scenario: Unknown partition count

- **WHEN** Fast Trace is enabled and the partition count of the topic is unknown or reported as 0
- **THEN** the preview SHALL state that the partition count is unknown and SHALL NOT show a partition number

#### Scenario: Empty key

- **WHEN** Fast Trace is enabled and no key is entered
- **THEN** the preview SHALL ask for a key and SHALL NOT show a partition number

#### Scenario: Several filter terms

- **WHEN** Fast Trace is enabled and the user enters several comma-separated terms
- **THEN** the preview SHALL show the partition of the first term only
- **AND** SHALL state that only the first term selects the scanned partition

#### Scenario: No cluster access

- **WHEN** the preview is computed or updated
- **THEN** the system SHALL NOT issue any Kafka or Schema Registry request for it

### Requirement: Fast Trace Partitioning Assumption Disclosure

Wherever Fast Trace can be enabled, the system SHALL state the assumption behind the partition choice: the Java default partitioner hashing the key as UTF-8 text. It SHALL warn that the real partition can differ for other partitioners (for example the librdkafka `consistent`/CRC32 default or custom partitioners), for binary or serialized keys (for example Avro keys with the Confluent wire-format prefix) and when partitions were added after the message was produced.

#### Scenario: Assumption shown with the preview

- **WHEN** the target partition preview is visible in the topic search configuration
- **THEN** it SHALL name the Java default partitioner and the UTF-8 text key as its assumption
- **AND** SHALL name other partitioners, binary or serialized keys and later partition increases as reasons the real partition can differ

#### Scenario: Assumption shown in the script step editor

- **WHEN** the user views the Fast Trace switch in the script step editor
- **THEN** the same assumption and caveats SHALL be available at the switch, for example as a tooltip

#### Scenario: Localized disclosure

- **WHEN** the preview or the disclosure is displayed
- **THEN** all its texts SHALL be rendered from localized strings in the active UI language
