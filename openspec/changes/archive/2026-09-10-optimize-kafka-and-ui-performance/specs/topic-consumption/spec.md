## ADDED Requirements

### Requirement: Pre-compiled Filter Evaluation

The consumer SHALL pre-compile all configured regular expressions and search terms prior to entering the message consumption loop and evaluate them without allocating or compiling new regex instances per message.

#### Scenario: Consuming with regex filters

- **WHEN** message consumption begins with `filter_type` set to `Regex` and one or more filter terms provided
- **THEN** the consumer compiles each filter term into a reusable regular expression once during setup
- **AND** matches each incoming message against the pre-compiled expressions without compiling regular expressions inside the message loop

### Requirement: Cached Schema Registry Resolution

The consumer SHALL cache schema metadata and decoded schemas in memory across messages and across consecutive consumption sessions on the same cluster, resolving schema IDs without synchronous blocking network lookups on cached hits.

#### Scenario: Consuming schema-encoded messages with known schema ID

- **WHEN** a message with Confluent wire format is received and its schema ID has been previously resolved in the current cluster session
- **THEN** the consumer resolves the schema from the local in-memory cache
- **AND** decodes the payload without executing blocking runtime calls or HTTP requests to the Schema Registry

### Requirement: Throttled UI State Emission and Amortized Buffering

The Flutter message streaming layer SHALL buffer incoming messages from native Rust streams and dispatch UI state notifications (`notifyListeners`) at a throttled frame cadence of at most once every 50ms to 100ms, using amortized $O(1)$ collection operations.

#### Scenario: High-throughput message streaming to UI

- **WHEN** Kafka messages arrive across the FFI stream at sustained throughput exceeding 100 messages per second
- **THEN** the UI controller buffers incoming messages and triggers state notifications at a throttled cadence between 50ms and 100ms
- **AND** does not invoke `notifyListeners()` on every individual message
- **AND** adds incoming messages without $O(N)$ list prepending shifts

### Requirement: Non-Blocking Consumer Disk Logging

When message logging to an output directory is enabled, the search and consumption pipeline SHALL persist log entries asynchronously without executing synchronous blocking file I/O operations on the Flutter main UI isolate.

#### Scenario: Logging consumer events to disk

- **WHEN** a log message is received from the consumer stream while file logging is enabled
- **THEN** the log entry is written asynchronously using non-blocking I/O
- **AND** does not block frame rendering on the Flutter UI isolate
