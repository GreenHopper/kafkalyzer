# Design

## Context

See `proposal.md` for motivation and background.

Currently:
1. `TopicDetailView` unconditionally renders `TopicPartitionHealthTable` as a full-width block between the topic header and `TopicSearchBar`. In topics with 1 or many partitions, this takes up 60–140px of vertical height and interrupts the flow between the header and message search/stream controls.
2. `MessageMetadataCard` appends `_schemaLines()` which renders full text lines for both key and value schemas (e.g. `Schlüssel: kein Registry-Schema` and `Wert: delivery-vehicle-positions-value v1 (#9)`). Since topic messages almost always share identical schemas and keys rarely use registry schemas, this creates severe visual repetition across every card in the timeline.
3. `MessageInspectorPanel` already provides comprehensive schema provenance details with clickable links to jump to the schema in the schema inspector.

## Goals / Non-Goals

**Goals:**
- Eliminate vertical clutter in the topic messages view, maximizing screen real estate for search controls and message streaming.
- Integrate partition replication status seamlessly into the topic header via interactive tags/chips and a clean modal dialog.
- Embed partition replication health into `TopicAnalysisView` where deep diagnostic inspection belongs.
- Simplify `MessageMetadataCard` to display schema provenance compactly (e.g. inline `#<id>` or `v<version>` only when present) without negative placeholders or redundant subject names.
- Keep rich schema provenance details and schema inspector navigation in `MessageInspectorPanel`.

**Non-Goals:**
- Modifying Rust backend code or bridge types (`kafka_metadata.rs`, `kafka_consumer.rs`). The backend already delivers all necessary metadata efficiently.
- Modifying the underlying data models for `TopicPartitionDetails` or `MessageSchema`.

## Decisions

### 1. Partition Health Access: Header Interaction & Modal Dialog

- **Choice**: Remove `TopicPartitionHealthTable` from the top of the messages tab. Make the header's `TopicTag` for partitions (e.g., `1 Partitions`) and the health warning tag interactive (`onTap`). Clicking opens `TopicPartitionHealthDialog`.
- **Details**:
  - In `TopicDetailView._buildTopicTags`:
    - The partition count tag (`N Partitions`) gains an `onTap` callback that displays `TopicPartitionHealthDialog`. A tooltip informs the user: e.g. "View partition & replication details".
    - If `unhealthy > 0`, the existing warning tag (`X Unhealthy`) also opens the dialog with unhealthy partitions highlighted.
  - Create `TopicPartitionHealthDialog` using Material 3 dialog styling (`material_ui`), wrapping the partition table with clear broker endpoint resolution and refresh capabilities.
- **Alternatives Considered**:
  - *Collapsible Accordion / ExpansionTile above search bar*: Still occupies vertical height and adds visual borders/dividers in the primary message workspace even when collapsed.
  - *Header Popover / Menu*: Tends to feel cramped for topics with dozens of partitions. A modal dialog provides ample horizontal and vertical room for partition columns (`#`, `Leader`, `Replicas`, `ISR`) and scrolls comfortably.

### 2. Deep Partition Health in Topic Analysis View

- **Choice**: Embed partition health as a dedicated card in `TopicAnalysisView`.
- **Details**:
  - When users switch to the `Topic-Analyse` view, deep diagnostic metrics (hourly throughput, partition balance, key distribution) are already displayed.
  - Adding partition replication status here complements the existing `PartitionBalanceView`, giving engineers a unified topic health dashboard.

### 3. Compact Schema Provenance in Message Cards

- **Choice**: Refactor `MessageMetadataCard` to show schema provenance as a compact inline item, only when a schema is present.
- **Details**:
  - Remove `Schlüssel: kein Registry-Schema` (negative information is completely omitted).
  - Do not render the full subject name on every card (`delivery-vehicle-positions-value` is redundant with the topic name already on the card).
  - Format the presence of registry schemas compactly:
    - If only value schema is present: display inline or as a subtle pill: e.g. `P: 0 | O: 119999 • #9` (or `v1 (#9)`).
    - If key schema is also present: display `K: #<id> | V: #<id>`.
  - Clicking on a message still opens `MessageInspectorPanel`, where full subject names, versions, schema IDs, and "Jump to Schema" actions are displayed in full detail.
- **Alternatives Considered**:
  - *Completely removing schema information from `MessageMetadataCard`*: While removing it entirely would save space, showing a compact `#<id>` or `v<version>` indicator allows users to spot schema version transitions and schema drift at a glance while scrolling without ballooning card height.

## Risks / Trade-offs

- **[Risk]** Users accustomed to seeing partition replication table immediately above search may wonder where it moved.
  → **Mitigation**: Add a tooltip to the partition tag in the header, and ensure the warning tag is prominently styled when partitions are unhealthy.
- **[Risk]** Existing widget tests expect `partition_health_unavailable` or `metadata_card_schema_key` in specific places.
  → **Mitigation**: Update tests in `topic_detail_view_test.dart` and `message_metadata_card_test.dart` to assert the new interactive dialog and compact schema representation.
