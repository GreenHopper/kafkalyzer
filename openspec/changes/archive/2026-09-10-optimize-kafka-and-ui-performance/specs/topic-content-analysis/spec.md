## ADDED Requirements

### Requirement: Decoupled Progress Reporting

Topic analysis SHALL track scan counts, byte volumes, and partition progress via lightweight atomic counters, emitting periodic progress reports without cloning full nested accumulator maps on every tick.

#### Scenario: Progress reporting during active scan

- **WHEN** topic content analysis is actively scanning messages
- **THEN** progress updates emitted every 250ms are computed using atomic message and byte counters
- **AND** the system does not clone or deep-merge the entire 100k+ entry accumulator state on every 250ms progress interval
- **AND** full analytical reports are synthesized only upon scan completion or user cancellation

### Requirement: Low-Latency Worker Partition Polling

Worker threads scanning multiple partition queues SHALL employ non-blocking polling and adaptive yield backoff without executing unconditional thread sleep delays on active queues.

#### Scenario: Multi-partition worker queue draining

- **WHEN** a worker thread polls multiple partition queues during content analysis
- **THEN** it does not inject fixed 5ms thread sleeps between consecutive polls when data is flowing or awaiting immediate fetch
- **AND** yields execution cooperatively only when all assigned queues are idle
