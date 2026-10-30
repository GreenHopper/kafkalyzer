# Design: Topic Analysis Duplicate Message Detection

## Context

Kafkalyzer performs high-throughput streaming analysis of Kafka topics by reading partitions in parallel or sequence, computing statistics for sizes, timestamps, keys, and JSON/Avro payloads. In many production systems, producer retries and network reconnects result in duplicate records.

Because topic scans can process millions of messages, all duplicate tracking must run in the native Rust accumulator with strict memory bounds and amortized $O(1)$ operations, without causing memory spikes or slowing down intake throughput.

## Goals / Non-Goals

**Goals:**
- Provide single-pass duplicate detection integrated directly into `AnalyzerAccumulator`.
- Support configurable duplicate scopes: `PayloadOnly` (default) and `KeyAndPayload`.
- Accurately compute `unique_messages`, `duplicate_messages`, and `duplicate_rate`.
- Identify and rank the Top 20 most frequent duplicated messages, displaying their key, payload preview, count, percentage, and sample coordinates (partition, offset, timestamp).
- Cap memory usage for large topics by using 128-bit Sha256 hashes (`[u8; 16]`) for unique message tracking and a bounded map for top duplicates.
- Preserve backward and forward compatibility in exported/imported report files.
- Deliver localized UI components adhering to Material UI 3 guidelines.

**Non-Goals:**
- De-duplicating messages on the Kafka broker (Kafkalyzer is strictly a read-only analysis and inspection tool).
- Storing full payload byte arrays for all scanned messages.
- Semantic or fuzzy similarity matching (comparison is exact byte/value equality).

## Decisions

### 1. Equality Definition & Scope

- **Choice:** Provide an enum `DuplicateDetectionScope` with two variants:
  - `PayloadOnly` (default): Two messages are duplicates if their payload bytes are identical, regardless of message keys.
  - `KeyAndPayload`: Two messages are duplicates only if both their key and payload bytes match.
- **Rationale:** Satisfies the user request. Retried messages often have identical keys and payloads, while topics with null keys or different keys may also need payload redundancy checks.
- **Alternatives considered:**
  - *Payload only without options*: Inflexible for scenarios where the same payload produced under different keys represents distinct business entities.
  - *JSON semantic canonicalization*: Normalizing JSON fields before hashing would add substantial CPU overhead in hot loops. Exact byte hashing preserves high throughput ($>100k$ msg/s).

### 2. Hash Representation & Memory Bounded Tracking

- **Choice:** Use 128-bit truncated Sha256 hashes (`[u8; 16]`) for tracking seen message fingerprints:
  - For `PayloadOnly`: `Sha256(payload_bytes)`.
  - For `KeyAndPayload`: `Sha256(key_bytes || 0xFF || payload_bytes)`.
  - Maintain `seen_hashes: HashSet<[u8; 16]>` to count unique items.
  - Maintain `duplicate_samples: HashMap<[u8; 16], DuplicateSample>` capped at 1,000 distinct duplicate payloads to store preview strings and sample coordinates.
- **Rationale:**
  - 128 bits ensures negligible collision probability ($< 10^{-15}$ across 10 million records).
  - Storing 1,000,000 hashes in a `HashSet<[u8; 16]>` consumes $\approx 24\text{ MB}$ of RAM, completely safe for desktop applications.
  - Duplicate sample map is capped at 1,000 entries, preventing memory growth even with high duplicate diversity.
- **Alternatives considered:**
  - *Full byte storage*: Would require gigabytes of RAM for large topics.
  - *64-bit standard hasher*: Faster, but higher risk of hash collision on large datasets ($> 4\text{ billion}$ pairs). 128-bit Sha256 truncation strikes the ideal balance of performance and collision safety.

### 3. Data Structures & Report Integration

- **In `kafkalyzer-core` (`kafka_types.rs`):**
  ```rust
  #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
  pub enum DuplicateDetectionScope {
      PayloadOnly,
      KeyAndPayload,
  }

  #[derive(Debug, Clone, Serialize, Deserialize)]
  pub struct TopDuplicateOccurrence {
      pub key: Option<String>,
      pub payload_preview: String,
      pub count: i64,
      pub percentage: f64,
      pub sample_partition: i32,
      pub sample_offset: i64,
      pub sample_timestamp_ms: i64,
  }

  #[derive(Debug, Clone, Serialize, Deserialize)]
  pub struct DuplicateAnalysisResult {
      pub scope: DuplicateDetectionScope,
      pub total_messages: i64,
      pub unique_messages: i64,
      pub duplicate_messages: i64,
      pub duplicate_rate: f64,
      pub top_duplicates: Vec<TopDuplicateOccurrence>,
  }
  ```
- **In `TopicAnalysisReport`:**
  - Added optional field `#[serde(default)] pub duplicate_analysis_result: Option<DuplicateAnalysisResult>`.

### 4. UI Presentation & Integration

- **Scan Options**: Add a scope picker (`SegmentedButton` or `Dropdown`) to the topic analysis configuration panel before scanning, defaulting to `PayloadOnly`.
- **Summary Cards**: Add a new KPI card to `TopicAnalysisSummaryCards` showing:
  - Title: "Duplicate Messages" (localized)
  - Value: Duplicate count (e.g. `1,250`)
  - Subtitle: Duplicate rate % (e.g. `12.5%`)
- **Top Duplicates Section**:
  - A collapsible card/table below field distributions displaying ranked top duplicate messages.
  - Columns: Rank, Occurrences, Share %, Key, Payload Preview, Sample Coordinates (Partition, Offset, Timestamp).
  - Copy actions for payload preview and key.
- **Report Import/Export**:
  - `TopicAnalysisReportFile` serializes `duplicate_analysis_result`.
  - Older imported files render a localized "Not available for this report" placeholder.

## Risks / Trade-offs

- **[Risk] CPU overhead of Sha256 hashing inside message poll loop**:
  - *Mitigation*: Sha256 is hardware-accelerated on modern x86_64/aarch64 CPUs (often $>500\text{ MB/s}$ per core). Hashing is only performed on the payload bytes (and key). For very large payloads, hashing the first 4KB + length + last 4KB could be considered if needed, but standard Sha256 on message payloads is easily fast enough for typical Kafka messages ($<100\text{ KB}$).
- **[Risk] Tombstones and empty payloads**:
  - *Mitigation*: Null and empty payloads are handled explicitly: multiple tombstones are counted according to the selected scope (e.g., all tombstones duplicate each other under `PayloadOnly`, or only tombstones with matching keys duplicate each other under `KeyAndPayload`).
- **[Risk] Backward compatibility of saved report files**:
  - *Mitigation*: `duplicate_analysis_result` is marked optional with `#[serde(default)]` in Rust and nullable in Dart. Older format versions parse smoothly without missing field errors.
