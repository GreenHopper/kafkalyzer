# Kafkalyzer Model Context Protocol (MCP) Server: Architecture & API Design

## Executive Summary

This document specifies the architecture, functional analysis, and API surface for exposing **Kafkalyzer**'s Kafka inspection, debugging, and analytical capabilities as a **Model Context Protocol (MCP)** server.

By integrating Kafkalyzer with MCP, Large Language Models (LLMs) and AI agents (such as Claude, Cursor, ChatGPT, and automated incident response bots) can autonomously interact with Apache Kafka clusters to:
- **Triage production incidents:** Rapidly detect stuck consumer groups, isolate poison pill messages, and inspect backlog trends.
- **Trace distributed transactions:** Perform cascading multi-topic searches using key hash projections or JSONPath correlation across complex event streams.
- **Audit topic health & data schemas:** Inspect partition skew, message size distribution, tombstone ratios, and Schema Registry evolution.
- **Debug payload anomalies:** Execute structural JSON diffs between message versions, decode Schema Registry formats (Avro, Protobuf, JSON Schema) and legacy AS400 payloads, and extract deeply nested fields.

---

## 1. Application Functionality Analysis

Kafkalyzer combines a high-performance native Rust core (`kafkalyzer-kafka`, `kafkalyzer-core`, and `rust_lib_kafkalyzer`) with a Flutter desktop presentation layer. Its features divide naturally into nine distinct operational domains:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             Kafkalyzer Capabilities                             │
├───────────────────┬───────────────────┬───────────────────┬──────────────────────┤
│ 1. Cluster & Auth │ 2. Topic Metadata │ 3. Message Query  │ 4. Payloads & Diffs  │
│   • Multi-profile │   • Topics list   │   • Offset/Time   │   • Avro/JSON/Proto  │
│   • SASL / mTLS   │   • Partitions    │   • Regex/Exact   │   • AS400 / EBCDIC   │
│   • Schema Reg    │   • Retention/EOF │   • Murmur2 fast  │   • Structural Diff  │
├───────────────────┼───────────────────┼───────────────────┼──────────────────────┤
│ 5. Topic Analysis │ 6. Consumer Lags  │ 7. Schema Reg     │ 8. Cascading Script  │
│   • Partition skew│   • Group state   │   • Subjects      │   • Chained steps    │
│   • Top keys      │   • Per-part lag  │   • Schemas by ID │   • JSONPath extract │
│   • Field stats   │   • Poison pill   │   • Compatibility │   • Script Authoring │
├───────────────────┴───────────────────┴───────────────────┴──────────────────────┤
│ 9. Partitioner Simulation & Utilities (Murmur2 hashing, export/import, presets)  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Cluster Connection & Authentication
- **Multi-cluster profile registry:** Stores broker bootstrap lists and security configurations.
- **Enterprise security protocols:** Supports `PLAINTEXT`, `SSL`, `SASL_PLAINTEXT`, and `SASL_SSL`.
- **SASL mechanisms:** `PLAIN`, `SCRAM-SHA-256`, `SCRAM-SHA-512`, `GSSAPI` (Kerberos via keytab/ticket cache), and `OAUTHBEARER`.
- **mTLS & Cryptography:** Custom JKS keystores/truststores, as well as direct PEM certificate and private key files.
- **Schema Registry integration:** Confluent Schema Registry endpoints with HTTP Basic Authentication.
- **Connectivity validation:** Active broker probe and metadata handshake validation.

### 1.2 Topic & Partition Metadata
- **Topic inventory:** Enumerates all topics, partition counts, and replication factors.
- **Topic configuration inspection:** Retrieves broker-level configurations such as `retention.ms`, `cleanup.policy` (`delete`, `compact`, `compact,delete`), and segment sizes.
- **Watermark tracking:** Earliest offset (low watermark) and Log End Offset (high watermark) per partition.

### 1.3 Message Consumption, Search & Filtering
- **Bi-directional temporal & offset positioning:**
  - Start strategies: `earliest`, `latest`, `tail` (last $N$ messages), specific offset, or epoch timestamp.
  - End strategies: `live` continuous tailing, partition `EOF` bounded scan, specific offset, specific timestamp, or max records cap.
- **Multi-term payload & key filtering:** Exact match, substring (`contains`), or full regex matching across keys, payloads, or both.
- **JSONPath field-targeted filtering:** Applies predicate expressions directly against structured JSON fields.
- **Fast-trace partition targeting:** Calculates Kafka's default `murmur2` key hash to directly locate the exact target partition for a known key without scanning unrelated partitions.
- **Throttling & batching:** Backpressure-safe retrieval designed for high-throughput topics.

### 1.4 Message Inspection, Decoding & Diffing
- **Wire format auto-detection:**
  - Confluent Schema Registry wire format (magic byte `0x00` + 4-byte schema ID) resolving to Avro, JSON Schema, or Protobuf.
  - Raw JSON and UTF-8 strings.
  - AS400 / IBM EBCDIC record decoding.
  - Raw binary / Hex representation and Tombstone detection (`payload == null` or empty).
- **Header inspection:** Full key-value header decoding.
- **Deep JSONPath extraction:** Resolves nested objects and array indices (e.g. `orders[0].items.sku`).
- **Message diffing:** Computes fine-grained structural JSON diffs (`json_diff`) and character-level textual diffs (`diff_match_patch`) between two messages or consecutive offsets.

### 1.5 Deep Content & Statistical Analysis
- **Sampling & volume metrics:** Scans up to $N$ messages across partitions; computes total message counts, byte volumes, and min/max/average message size.
- **Partition balance & skew detection:** Computes message counts, byte sizes, and distribution percentage per partition to detect imbalance or uneven key hashing.
- **Temporal distribution:** Builds hourly production histograms (24-hour distribution) to uncover burst patterns.
- **Key cardinality analysis:** Identifies top recurring keys and null-key percentages.
- **Schema field discovery & frequencies:** Traverses all sampled JSON/Avro records to discover field paths, percentage presence, and the top recurring values per field.
- **Report serialization:** Export and import of complete topic analysis snapshots in versioned JSON format.

### 1.6 Consumer Group & Lag Diagnostics
- **Group inventory & states:** Queries all cluster consumer groups, states (`Stable`, `PreparingRebalance`, `CompletingRebalance`, `Dead`, `Empty`), protocol types, and member counts.
- **Partition-level lag breakdown:** Evaluates `log_end_offset`, `current_offset`, and calculated `lag` per partition.
- **Lag trend & delta monitoring:** Tracks offset movement over time to distinguish actively draining groups from stalled or accumulating backlogs.
- **Poison pill / stuck offset inspection:** Fetches the exact message located at `current_offset` for any lagging partition to reveal unparseable or rejected records.

### 1.7 Schema Registry Management
- **Subject catalog:** Lists all registered subjects in the registry.
- **Schema retrieval:** Fetches the raw schema definition (Avro JSON, JSON Schema, or Protobuf IDL) by subject or numerical schema ID.

### 1.8 Scripting & Multi-Step Cascading Pipelines
- **Declarative workflow execution:** Chains sequential queries across multiple topics and clusters.
- **Variable extraction & propagation:** Extracts field values from upstream messages (via JSONPath on key or payload) and feeds them into downstream filter templates (e.g., extracting `trackingId` from `orders` and querying `shipments` for `{{trackingId}}`).
- **Run audit & history:** Retains historical run statistics, execution timings, and extracted values.

### 1.9 Partitioner Simulation & Utilities
- **Murmur2 partition calculator:** Simulates Kafka's default partitioning algorithm for any string key and partition count:
  $$\text{partition} = (\text{murmur2}(\text{key}) \ \& \ 0x7fffffff) \pmod{\text{partition\_count}}$$
- **Exporting records:** Serializes message datasets into JSON or multi-topic ZIP bundles.

---

## 2. MCP Server Architecture

The Model Context Protocol standard defines three primary primitives:
1. **Tools:** Callable routines with validated JSON Schemas that execute operations and return structured results.
2. **Resources:** URI-addressable, cacheable data endpoints (e.g., cluster topologies, topic schemas, or consumer lag snapshots) that provide context to an LLM without invoking an active task.
3. **Prompts:** Pre-defined conversational workflows that guide the LLM through complex multi-step diagnostics.

```
┌────────────────────────────────────────────────────────┐
│             LLM Client (Cursor / Claude)               │
└──────────────────────────┬─────────────────────────────┘
                           │ MCP Protocol (JSON-RPC 2.0 / stdio or SSE)
┌──────────────────────────▼─────────────────────────────┐
│                 Kafkalyzer MCP Server                  │
│                                                        │
│  ┌──────────────────┐ ┌────────────────┐ ┌──────────┐  │
│  │    MCP Tools     │ │ MCP Resources  │ │ Prompts  │  │
│  └────────┬─────────┘ └───────┬────────┘ └────┬─────┘  │
│           │                   │               │        │
│  ┌────────▼───────────────────▼───────────────▼─────┐  │
│  │               Core Dispatch Layer                │  │
│  │   • Token Truncation & Paging Guard             │  │
│  │   • Credential Redaction & Security Filter       │  │
│  └────────────────────────┬─────────────────────────┘  │
└───────────────────────────┼────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│         Native Engine (`kafkalyzer-kafka`)             │
│   • rdkafka (Kafka Consumer / Admin Client)            │
│   • Schema Registry Converter (Avro, Proto, JSON)      │
│   • kafkalyzer-core (AS400 Decoding & Murmur2)         │
└────────────────────────────────────────────────────────┘
```

### Implementation Recommendation: Native Rust Binary vs Flutter Service
- **Primary Recommendation: Native Rust CLI/Daemon (`kafkalyzer-mcp`).**
  Because `kafkalyzer-kafka` and `kafkalyzer-core` are pure Rust crates decoupled from Flutter UI code, a dedicated binary (`cargo build --bin kafkalyzer-mcp`) can run directly via standard I/O (`stdio`) or local HTTP/SSE. It has zero GUI dependencies, boots in milliseconds, uses minimal memory, and runs easily in headless CI/CD, Docker, Kubernetes pods, or local developer workstations.
- **Secondary Mode: Embedded in Desktop App.**
  The Flutter desktop app can optionally spawn the internal MCP listener when enabled in Settings, sharing local cluster profiles and active cache state.

---

## 3. Comprehensive MCP Tools Specification

Below is the complete inventory of proposed MCP tools, categorized by operational domain.

### 3.1 Cluster & Connection Tools

#### `kafka_list_clusters`
- **Description:** Lists all configured Kafka cluster profiles stored in Kafkalyzer, including their bootstrap servers and security protocol types. Credentials and passwords are automatically redacted.
- **Input Parameters:** *(None)*
- **Output:**
  ```json
  {
    "clusters": [
      {
        "name": "production-eu",
        "bootstrap_servers": "kafka1.prod:9092,kafka2.prod:9092",
        "security_protocol": "SASL_SSL",
        "mechanism": "SCRAM-SHA-512",
        "has_schema_registry": true,
        "is_active": true
      }
    ]
  }
  ```
- **Read-Only:** Yes

---

#### `kafka_test_connection`
- **Description:** Validates connectivity to a Kafka cluster and optional Schema Registry using a named profile or custom connection configuration.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Name of an existing configured cluster profile" },
      "bootstrap_servers": { "type": "string", "description": "Override or ad-hoc bootstrap servers" },
      "timeout_seconds": { "type": "integer", "default": 5, "description": "Max timeout for the probe" }
    }
  }
  ```
- **Output:**
  ```json
  {
    "connected": true,
    "broker_count": 3,
    "schema_registry_connected": true,
    "latency_ms": 18
  }
  ```
- **Read-Only:** Yes

---

### 3.2 Topic & Metadata Tools

#### `kafka_list_topics`
- **Description:** Lists all topics in the cluster with partition count, replication factor, retention time, cleanup policy, and optional name filtering.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Target cluster profile name" },
      "filter_pattern": { "type": "string", "description": "Optional substring or regex to filter topic names" },
      "include_internal": { "type": "boolean", "default": false, "description": "Whether to include Kafka internal topics like __consumer_offsets" }
    },
    "required": ["cluster_name"]
  }
  ```
- **Output:**
  ```json
  {
    "topics": [
      {
        "name": "orders.v1",
        "partition_count": 12,
        "replication_factor": 3,
        "cleanup_policy": "delete",
        "retention_ms": "604800000"
      }
    ],
    "total_count": 1
  }
  ```
- **Read-Only:** Yes

---

#### `kafka_get_topic_details`
- **Description:** Returns detailed partition metadata for a specific topic, including per-partition leader broker, replicas, ISR (in-sync replicas), earliest offset, and high watermark (log end offset).
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Target cluster profile name" },
      "topic": { "type": "string", "description": "Name of the topic" }
    },
    "required": ["cluster_name", "topic"]
  }
  ```
- **Output:**
  ```json
  {
    "topic": "orders.v1",
    "total_partitions": 3,
    "total_messages_available": 1420500,
    "partitions": [
      {
        "partition": 0,
        "leader": 101,
        "earliest_offset": 0,
        "high_watermark": 473500,
        "message_count": 473500,
        "replicas": [101, 102, 103],
        "isr": [101, 102, 103]
      }
    ]
  }
  ```
- **Read-Only:** Yes

---

### 3.3 Message Querying & Search Tools

#### `kafka_consume_messages`
- **Description:** Consumes a bounded window of messages from a topic with flexible starting positions (earliest, latest, tail N, specific offset, or timestamp) and optional partition targeting. Ideal for reading the latest events or inspecting records at a specific point in time.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Target cluster profile name" },
      "topic": { "type": "string", "description": "Name of the topic" },
      "partition": { "type": "integer", "description": "Optional specific partition. If omitted, consumes across all partitions" },
      "start_strategy": {
        "type": "string",
        "enum": ["latest", "earliest", "tail", "offset", "timestamp"],
        "default": "tail",
        "description": "Where to begin consuming"
      },
      "start_offset": { "type": "integer", "description": "Starting offset when start_strategy is 'offset'" },
      "start_timestamp": { "type": "integer", "description": "Starting epoch ms when start_strategy is 'timestamp'" },
      "limit": { "type": "integer", "default": 20, "maximum": 200, "description": "Maximum number of messages to return" },
      "projected_fields": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Optional list of JSONPaths to extract (e.g. ['id', 'status.code']) to save context tokens"
      }
    },
    "required": ["cluster_name", "topic"]
  }
  ```
- **Output:**
  ```json
  {
    "topic": "orders.v1",
    "messages_returned": 1,
    "messages": [
      {
        "partition": 2,
        "offset": 98124,
        "timestamp": 1727600000000,
        "key": "ORDER-9912",
        "headers": { "correlation-id": "a8f3b-11c" },
        "payload": {
          "id": "ORDER-9912",
          "amount": 149.50,
          "currency": "EUR",
          "status": "COMPLETED"
        },
        "is_tombstone": false,
        "wire_format": "avro_schema_registry"
      }
    ]
  }
  ```
- **Read-Only:** Yes

---

#### `kafka_search_messages`
- **Description:** Performs high-speed server-side filtering across topic partitions using exact match, substring, or regular expressions. Supports key search, payload search, or JSONPath-targeted field filtering. Supports `fast_trace_key` to skip unrelated partitions.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Target cluster profile name" },
      "topic": { "type": "string", "description": "Name of the topic" },
      "filter_terms": { "type": "array", "items": { "type": "string" }, "description": "Terms to search for" },
      "filter_type": { "type": "string", "enum": ["contains", "regex", "exact"], "default": "contains" },
      "search_scope": { "type": "string", "enum": ["key", "value", "both"], "default": "both" },
      "filter_field": { "type": "string", "description": "Optional JSONPath field to target (e.g. 'customer.id')" },
      "start_offset": { "type": "integer", "description": "Optional start offset" },
      "start_timestamp": { "type": "integer", "description": "Optional start timestamp (epoch ms)" },
      "end_timestamp": { "type": "integer", "description": "Optional end timestamp (epoch ms)" },
      "fast_trace_key": { "type": "string", "description": "If provided, computes Murmur2 key hash to directly scan only the single relevant partition" },
      "max_results": { "type": "integer", "default": 20, "maximum": 100, "description": "Max matching messages to return" },
      "scan_timeout_seconds": { "type": "integer", "default": 15, "description": "Timeout to prevent unbounded scans" }
    },
    "required": ["cluster_name", "topic"]
  }
  ```
- **Output:**
  ```json
  {
    "matches_found": 3,
    "scanned_partitions": [2],
    "scan_completed": true,
    "messages": [
      {
        "partition": 2,
        "offset": 104230,
        "timestamp": 1727601200000,
        "key": "CUST-4029",
        "payload": "{\"orderId\":\"ORD-881\",\"customerId\":\"CUST-4029\",\"amount\":99.0}"
      }
    ]
  }
  ```
- **Read-Only:** Yes

---

### 3.4 Message Inspection & Diff Tools

#### `kafka_diff_messages`
- **Description:** Computes structural JSON differences and textual diffs between two messages. Useful for comparing consecutive message revisions for an entity, investigating state transitions, or comparing messages across environments (e.g., staging vs prod).
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Target cluster profile name" },
      "topic": { "type": "string", "description": "Topic name" },
      "partition_a": { "type": "integer", "description": "Partition of baseline message" },
      "offset_a": { "type": "integer", "description": "Offset of baseline message" },
      "partition_b": { "type": "integer", "description": "Partition of comparison message" },
      "offset_b": { "type": "integer", "description": "Offset of comparison message" }
    },
    "required": ["cluster_name", "topic", "partition_a", "offset_a", "partition_b", "offset_b"]
  }
  ```
- **Output:**
  ```json
  {
    "message_a": { "partition": 1, "offset": 100, "timestamp": 1727600000000 },
    "message_b": { "partition": 1, "offset": 101, "timestamp": 1727600050000 },
    "has_changes": true,
    "added_fields": { "shipping.status": "IN_TRANSIT" },
    "removed_fields": {},
    "changed_fields": {
      "status": { "old": "PENDING", "new": "SHIPPED" },
      "version": { "old": 1, "new": 2 }
    }
  }
  ```
- **Read-Only:** Yes

---

#### `kafka_extract_json_path`
- **Description:** Evaluates a JSONPath query or dot-notation path (including array indexes like `items[0].id`) on a specific Kafka message payload or key.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Target cluster profile name" },
      "topic": { "type": "string", "description": "Topic name" },
      "partition": { "type": "integer", "description": "Partition index" },
      "offset": { "type": "integer", "description": "Message offset" },
      "json_path": { "type": "string", "description": "Path expression (e.g. 'customer.address.zipCode' or 'payments[0].amount')" },
      "source": { "type": "string", "enum": ["payload", "key"], "default": "payload" }
    },
    "required": ["cluster_name", "topic", "partition", "offset", "json_path"]
  }
  ```
- **Output:**
  ```json
  {
    "path": "customer.address.zipCode",
    "resolved_value": "80331",
    "value_type": "string"
  }
  ```
- **Read-Only:** Yes

---

### 3.5 Consumer Group & Lag Diagnostics Tools

#### `kafka_list_consumer_groups`
- **Description:** Lists all consumer groups in the cluster with their current state (`Stable`, `PreparingRebalance`, `Empty`, `Dead`), protocol type, active members count, and total topic count.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Target cluster profile name" },
      "state_filter": { "type": "string", "description": "Optional filter by state: Stable, Empty, Dead, etc." }
    },
    "required": ["cluster_name"]
  }
  ```
- **Output:**
  ```json
  {
    "groups": [
      {
        "group_id": "order-billing-service",
        "state": "Stable",
        "protocol_type": "consumer",
        "members_count": 4,
        "topics_count": 2
      }
    ]
  }
  ```
- **Read-Only:** Yes

---

#### `kafka_get_consumer_lag`
- **Description:** Returns the complete partition-by-partition consumer lag for a consumer group, comparing the committed consumer offset against the broker log end offset.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Target cluster profile name" },
      "group_id": { "type": "string", "description": "Consumer group ID" },
      "topic": { "type": "string", "description": "Optional filter for a specific topic" }
    },
    "required": ["cluster_name", "group_id"]
  }
  ```
- **Output:**
  ```json
  {
    "group_id": "order-billing-service",
    "state": "Stable",
    "total_lag": 45210,
    "partition_lags": [
      {
        "topic": "orders.v1",
        "partition": 0,
        "current_offset": 501200,
        "log_end_offset": 546410,
        "lag": 45210
      },
      {
        "topic": "orders.v1",
        "partition": 1,
        "current_offset": 498000,
        "log_end_offset": 498000,
        "lag": 0
      }
    ]
  }
  ```
- **Read-Only:** Yes

---

#### `kafka_inspect_lagging_message`
- **Description:** Directly fetches the message at `current_offset` for a lagging consumer group partition. This is the primary tool for diagnosing "poison pills" where an unparseable message or application bug prevents the consumer from advancing its offset.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Target cluster profile name" },
      "group_id": { "type": "string", "description": "Consumer group ID" },
      "topic": { "type": "string", "description": "Topic name" },
      "partition": { "type": "integer", "description": "Lagging partition index" }
    },
    "required": ["cluster_name", "group_id", "topic", "partition"]
  }
  ```
- **Output:**
  ```json
  {
    "group_id": "order-billing-service",
    "partition": 0,
    "stuck_at_offset": 501201,
    "message": {
      "offset": 501201,
      "timestamp": 1727600892000,
      "key": "ERR-PAYLOAD-001",
      "headers": { "retry-count": "5" },
      "payload": "{\"invalid_syntax\": true,,}",
      "deserialization_error": "Unexpected character ',' at line 1 column 23"
    }
  }
  ```
- **Read-Only:** Yes

---

### 3.6 Deep Content & Statistical Analysis Tools

#### `kafka_analyze_topic`
- **Description:** Performs a deep statistical analysis of a topic by sampling up to $N$ messages. Computes message size distributions (min, max, avg), tombstone ratios, partition distribution balance, key distributions, hourly throughput histograms, and field discovery with frequencies and top values.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Target cluster profile name" },
      "topic": { "type": "string", "description": "Topic name" },
      "max_messages": { "type": "integer", "default": 5000, "maximum": 50000, "description": "Sample size" },
      "sample_from_latest": { "type": "boolean", "default": true, "description": "True to sample newest messages, False for earliest" }
    },
    "required": ["cluster_name", "topic"]
  }
  ```
- **Output:**
  ```json
  {
    "topic": "orders.v1",
    "scanned_messages": 5000,
    "scan_duration_ms": 342,
    "metrics": {
      "total_bytes": 12489000,
      "avg_message_size_bytes": 2497.8,
      "min_message_size_bytes": 312,
      "max_message_size_bytes": 14200,
      "tombstones_count": 12,
      "tombstones_percentage": 0.24,
      "null_keys_count": 0,
      "is_compacted": false
    },
    "partition_balance": [
      { "partition": 0, "message_count": 1650, "percentage": 33.0 },
      { "partition": 1, "message_count": 1700, "percentage": 34.0 },
      { "partition": 2, "message_count": 1650, "percentage": 33.0 }
    ],
    "top_keys": [
      { "key": "RESELLER-EU", "count": 482, "percentage": 9.64 }
    ],
    "field_frequencies": [
      {
        "field_name": "status",
        "count": 5000,
        "percentage": 100.0,
        "top_values": [
          { "value": "COMPLETED", "count": 3800, "percentage": 76.0 },
          { "value": "PENDING", "count": 1200, "percentage": 24.0 }
        ]
      }
    ]
  }
  ```
- **Read-Only:** Yes

---

### 3.7 Schema Registry Tools

#### `kafka_list_schemas`
- **Description:** Lists all registered subjects in the Confluent Schema Registry associated with the cluster profile.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Target cluster profile name" }
    },
    "required": ["cluster_name"]
  }
  ```
- **Output:**
  ```json
  {
    "subjects": [
      "orders.v1-key",
      "orders.v1-value",
      "customers-value"
    ]
  }
  ```
- **Read-Only:** Yes

---

#### `kafka_get_schema`
- **Description:** Retrieves the schema definition for a given subject (or numerical schema ID) from the Schema Registry, formatted as JSON (for Avro / JSON Schema) or Proto text.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Target cluster profile name" },
      "subject": { "type": "string", "description": "Subject name in Schema Registry" }
    },
    "required": ["cluster_name", "subject"]
  }
  ```
- **Output:**
  ```json
  {
    "subject": "orders.v1-value",
    "schema_type": "AVRO",
    "schema": {
      "type": "record",
      "name": "OrderEvent",
      "namespace": "com.company.events",
      "fields": [
        { "name": "orderId", "type": "string" },
        { "name": "amount", "type": "double" }
      ]
    }
  }
  ```
- **Read-Only:** Yes

---

### 3.8 Cascading Investigation & Scripting Tools

#### `kafka_list_saved_scripts`
- **Description:** Lists all investigation scripts saved in Kafkalyzer, including their IDs, names, step counts, and defined variables.
- **Input Parameters:** *(None)*
- **Output:**
  ```json
  {
    "scripts": [
      {
        "id": "c1f7f18b-5777-4b47-b2f4-a5585b2111de",
        "name": "Trace Order to Delivery",
        "concurrency_limit": 2,
        "variables": [
          { "name": "order_id", "type": "string" }
        ],
        "steps_count": 2
      }
    ]
  }
  ```
- **Read-Only:** Yes

---

#### `kafka_get_script`
- **Description:** Retrieves the full JSON specification of a saved script by ID or name, including all step configurations, filters, strategy settings, and JSONPath extraction rules.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "script_id": { "type": "string", "description": "ID of the script" },
      "script_name": { "type": "string", "description": "Name of the script (used if script_id is omitted)" }
    }
  }
  ```
- **Output:** Full `Script` JSON object matching Kafkalyzer's domain schema.
- **Read-Only:** Yes

---

#### `kafka_save_script`
- **Description:** Creates a new investigation script or updates an existing one (including modifying its steps, variables, and JSONPath extraction rules). The script immediately appears in Kafkalyzer's UI.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "id": { "type": "string", "description": "Script UUID. If omitted or new, a UUID is generated." },
      "name": { "type": "string", "description": "Name of the investigation script" },
      "concurrency_limit": { "type": "integer", "default": 2 },
      "variables": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "name": { "type": "string" },
            "type": { "type": "string", "enum": ["string", "numeric", "timestamp", "date"] }
          },
          "required": ["name"]
        }
      },
      "steps": {
        "type": "array",
        "description": "Sequential steps to execute",
        "items": {
          "type": "object",
          "properties": {
            "id": { "type": "string" },
            "name": { "type": "string" },
            "cluster_name": { "type": "string" },
            "topic_names": { "type": "array", "items": { "type": "string" } },
            "filter_template": { "type": "string" },
            "filter_type": { "type": "string", "enum": ["contains", "regex", "exact"], "default": "contains" },
            "scope": { "type": "string", "enum": ["key", "value", "both"], "default": "both" },
            "start_strategy": { "type": "string", "enum": ["latest", "earliest", "offset", "timestamp"], "default": "latest" },
            "end_strategy": { "type": "string", "enum": ["latest", "eof", "offset", "timestamp", "maxResults", "live"], "default": "latest" },
            "max_results": { "type": "string" },
            "extractions": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "json_path": { "type": "string" },
                  "variable_name": { "type": "string" },
                  "topic": { "type": "string" },
                  "source": { "type": "string", "enum": ["value", "key"], "default": "value" }
                },
                "required": ["json_path", "variable_name"]
              }
            }
          },
          "required": ["name", "cluster_name", "topic_names"]
        }
      }
    },
    "required": ["name", "steps"]
  }
  ```
- **Output:**
  ```json
  {
    "success": true,
    "script_id": "c1f7f18b-5777-4b47-b2f4-a5585b2111de",
    "name": "Trace Order to Delivery",
    "steps_count": 2
  }
  ```
- **Read-Only:** No (Mutating operation)

---

#### `kafka_delete_script`
- **Description:** Deletes a saved investigation script by ID.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "script_id": { "type": "string", "description": "ID of the script to delete" }
    },
    "required": ["script_id"]
  }
  ```
- **Output:** `{"success": true, "deleted_id": "..."}`
- **Read-Only:** No (Mutating operation)

---

#### `kafka_run_investigation_pipeline`
- **Description:** Executes a multi-step query pipeline across topics and clusters. Extracts variables from matching messages in step $N$ via JSONPath and substitutes them into step $N+1$ queries. Mimics Kafkalyzer's built-in `ScriptRunner` workflow.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "cluster_name": { "type": "string", "description": "Target cluster profile name" },
      "steps": {
        "type": "array",
        "description": "Sequential steps to execute",
        "items": {
          "type": "object",
          "properties": {
            "name": { "type": "string" },
            "topic": { "type": "string" },
            "filter_template": { "type": "string", "description": "Filter template, e.g. '{{extracted_id}}'" },
            "extractions": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "variable_name": { "type": "string" },
                  "json_path": { "type": "string" },
                  "source": { "type": "string", "enum": ["value", "key"], "default": "value" }
                },
                "required": ["variable_name", "json_path"]
              }
            }
          },
          "required": ["name", "topic"]
        }
      },
      "initial_variables": {
        "type": "object",
        "description": "Initial key-value pairs (e.g. {'order_id': '10492'})"
      }
    },
    "required": ["cluster_name", "steps"]
  }
  ```
- **Output:**
  ```json
  {
    "pipeline_success": true,
    "steps_executed": 2,
    "extracted_variables": {
      "order_id": "10492",
      "delivery_id": "DEL-9921"
    },
    "results_by_step": {
      "Find Order": { "matches": 1, "topic": "orders" },
      "Find Delivery": { "matches": 1, "topic": "shipments" }
    }
  }
  ```
- **Read-Only:** Yes

---

### 3.9 Utility & Simulation Tools

#### `kafka_calculate_partition`
- **Description:** Computes the deterministic target partition index for a given message key string and topic partition count using Kafka's official Murmur2 partitioner algorithm.
- **Input Parameters:**
  ```json
  {
    "type": "object",
    "properties": {
      "key": { "type": "string", "description": "The message key string" },
      "partition_count": { "type": "integer", "description": "Total number of partitions in the topic" }
    },
    "required": ["key", "partition_count"]
  }
  ```
- **Output:**
  ```json
  {
    "key": "user_49102",
    "partition_count": 16,
    "murmur2_hash": 284192841,
    "target_partition": 9
  }
  ```
- **Read-Only:** Yes

---

## 4. MCP Resources Specification

MCP Resources allow LLMs to read persistent or semi-static contextual data via URI references without invoking an active tool execution.

| URI Scheme | Description | MIME Type |
|---|---|---|
| `kafka://{cluster}/metadata` | Overview of cluster brokers, security mode, and topic counts. | `application/json` |
| `kafka://{cluster}/topics` | Complete list of all topics with partitions and cleanup policies. | `application/json` |
| `kafka://{cluster}/topic/{topic}/metadata` | Detailed partition breakdown, watermarks, and broker leadership. | `application/json` |
| `kafka://{cluster}/topic/{topic}/schema` | Registered Schema Registry schema for topic value. | `application/json` |
| `kafka://{cluster}/topic/{topic}/analysis` | Cached or latest statistical analysis report for the topic. | `application/json` |
| `kafka://{cluster}/consumer-groups` | Summary list of all consumer groups and their states. | `application/json` |
| `kafka://{cluster}/consumer-group/{group_id}/lag` | Active partition lag metrics for the specified group. | `application/json` |
| `kafka://scripts` | List of all saved automation and investigation scripts. | `application/json` |
| `kafka://scripts/{script_id}` | Complete definition and steps of a specific saved script. | `application/json` |

---

## 5. MCP Prompts Specification

Pre-built prompt workflows allow the LLM to guide operators through standardized troubleshooting runbooks.

### Prompt: `diagnose-consumer-lag`
- **Arguments:** `cluster_name` (string), `group_id` (string)
- **Workflow:**
  1. Calls `kafka_get_consumer_lag` to locate partitions with high or non-zero lag.
  2. If a partition has stagnant lag, calls `kafka_inspect_lagging_message` to fetch the record at `current_offset`.
  3. Checks the payload for schema errors, unexpected nulls, or corrupt formatting.
  4. Summarizes findings: identifies whether lag is caused by slow throughput vs. a fatal poison pill error.

### Prompt: `trace-event-flow`
- **Arguments:** `cluster_name` (string), `starting_topic` (string), `correlation_id` (string)
- **Workflow:**
  1. Searches `starting_topic` for the `correlation_id`.
  2. Extracts child identifiers (e.g., `paymentId`, `fulfillmentId`).
  3. Sequentially scans downstream event topics.
  4. Generates an end-to-end timeline of the event journey with latency deltas.

### Prompt: `audit-topic-hygiene`
- **Arguments:** `cluster_name` (string), `topic` (string)
- **Workflow:**
  1. Calls `kafka_get_topic_details` to check replica balance and partition count.
  2. Calls `kafka_analyze_topic` to sample records.
  3. Evaluates:
     - Is partition balance skewed? (Indicates uneven key hashing).
     - Are there high tombstone counts on non-compacted topics?
     - Are there unexpected null keys?
     - What are the peak production hours?
  4. Produces a topic hygiene score and recommendations.

### Prompt: `generate-investigation-script`
- **Arguments:** `description` (string, e.g. "Trace orders from checkout to warehouse fulfillment across topics `orders`, `inventory`, and `shipments`")
- **Workflow:**
  1. Discovers cluster topics and fetches sample payloads via `kafka_consume_messages`.
  2. Inspects Schema Registry schemas to identify correlation IDs (`orderId`, `trackingNumber`).
  3. Formulates a multi-step `Script` definition with appropriate `startStrategy`, `filterTemplate`, and `extractions`.
  4. Calls `kafka_save_script` to persist it directly into the user's Kafkalyzer app.

---

## 6. Context Window & Token Optimization Strategies

Kafka messages frequently contain large multi-megabyte payloads. If an MCP server returns raw 2 MB payloads into an LLM context, it will immediately exceed token limits and degrade inference quality.

The Kafkalyzer MCP server implements five defensive token-safety measures:

1. **Selective Field Projection (`projected_fields`):**
   - Callers can request specific JSONPaths (e.g., `["id", "status", "timestamp"]`).
   - The native layer extracts only these fields and discards the rest of the payload before returning to the model.
2. **Hard Payload Truncation Cap:**
   - Any single message payload exceeding a configurable limit (default: 4 KB) is truncated with an indicator:
     `{"_truncated": true, "original_byte_size": 248910, "preview": "{...first 2000 chars...}"}`.
3. **Paging & Strict Limits:**
   - Default return count is capped at 10–20 messages; hard maximum is 100 messages per call.
4. **Summary Aggregation First:**
   - When users ask about topic contents, the server guides the LLM to call `kafka_analyze_topic` (returning statistical distributions) rather than dumping raw messages.
5. **Credential Masking:**
   - Passwords, Kerberos keytab contents, SASL credentials, and private keys in cluster profiles are permanently redacted (`[REDACTED]`) before being serialized.

---

## 7. Security, Safety & Governance Model

To prevent accidental data loss or unauthorized cluster changes:

- **Strict Read-Only Enforcement:**
  - All Phase 1 MCP tools are strictly read-only (`validate_connection`, `fetch_topics`, `consume_with_filter`, `fetch_lags`, `fetch_schema`).
  - No destructive administrative tools (`delete_topic`, `alter_configs`, `reset_offsets`) are exposed without explicit operator confirmation flags and smart-mode approval barriers.
- **Controlled Message Production (Future Phase):**
  - If a produce tool (`kafka_produce_message`) is added for testing DLQ reprocessing, it must require explicit confirmation tokens and cluster-level write permissions.
- **Local Credential Storage:**
  - MCP requests reference clusters by `cluster_name`. Credentials are read from the local encrypted/protected storage and are never accepted over MCP tool inputs from the LLM.

---

## 8. Implementation Roadmap

### Phase 1: Core Engine & Read-Only Tools (Rust Crate `kafkalyzer-mcp`)
- [ ] Create `rust/kafkalyzer-mcp` binary crate.
- [ ] Implement MCP JSON-RPC 2.0 protocol over `stdio` using `tokio` and `serde_json`.
- [ ] Implement Cluster, Topic Metadata, Consumer, and Lag tools wrapping `kafkalyzer-kafka`.
- [ ] Implement Murmur2 partition calculation wrapping `kafkalyzer-core`.
- [ ] Add payload size truncation and token budgeting safeguards.

### Phase 2: Schema Registry & Statistical Analysis
- [ ] Add Schema Registry subject and schema fetch tools.
- [ ] Wrap `analyze_topic_content` for on-demand topic health audits.
- [ ] Implement JSON diffing and JSONPath extraction tools.

### Phase 3: High-Level Workflows & Prompts
- [ ] Implement MCP Resource templates (`kafka://...`).
- [ ] Implement MCP Prompts (`diagnose-consumer-lag`, `trace-event-flow`, `audit-topic-hygiene`).
- [ ] Package as a standalone executable and add integration toggle in the Kafkalyzer Flutter UI Settings.
