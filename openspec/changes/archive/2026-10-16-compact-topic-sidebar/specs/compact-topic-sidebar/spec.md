# compact-topic-sidebar Specification Delta

## Purpose

Provides high-density topic list items with hierarchical name formatting, compact metadata badges, and streamlined filter controls in the Explorer sidebar to maximize visible topic count and accelerate topic discovery.

## ADDED Requirements

### Requirement: High-Density Topic List Items

Each item in the Explorer topic list SHALL render in a compact, high-density layout (approximately 44–48px vertical height) displaying the topic name with hierarchical styling and at most two compact micro-badges (partition count `<N>P` and schema type badge `Avro`), omitting low-priority broker configuration tags (`RF`, `cleanup.policy`, `retention.ms`, and the inline `[Schema]` button) from the base card layout.

#### Scenario: Hierarchical topic name formatting with dot-separated segments
- **WHEN** a topic name containing dot-separated segments (e.g., `kaenup.pmxcor.temp.incomingOutlookMessage`) is rendered in the topic sidebar
- **THEN** the namespace prefix segments (`kaenup.pmxcor.temp.`) SHALL be displayed with dimmed or secondary text styling
- **AND** the terminal leaf segment (`incomingOutlookMessage`) SHALL be visually emphasized with bold text styling
- **AND** single-segment topic names without dots SHALL be rendered entirely in bold text styling

#### Scenario: Compact micro-badges display partition count and schema
- **WHEN** a topic having 12 partitions and an associated Avro schema is rendered in the sidebar
- **THEN** the list item SHALL display a compact partition badge `12P`
- **AND** display a schema badge `Avro`
- **AND** omit individual tags for replication factor (`RF: 3`), cleanup policy (`delete`), retention duration (`90.0 days`), and the inline `[Schema]` button from the card face

#### Scenario: Broker configuration details accessible via hover tooltip
- **WHEN** the user hovers over a topic item in the sidebar
- **THEN** a tooltip or contextual overlay SHALL display the full metadata details including partition count, replication factor, retention duration, and cleanup policy without expanding the card height

#### Scenario: Preserving interaction workflows
- **WHEN** the user interacts with a compact topic item
- **THEN** single-clicking SHALL select the topic and open it in the active or new tab
- **AND** double-clicking SHALL immediately initiate bounded message streaming
- **AND** clicking the trailing "open in new tab" icon button SHALL open a separate tab for the topic

---

### Requirement: Compact Topic Filter Controls

The topic sidebar filter section SHALL render topic filtering options (internal topics and Kafka Streams changelog/repartition topics) as compact inline filter chips rather than multi-row switch toggles, minimizing vertical header overhead above the topic list.

#### Scenario: Toggling internal topics filter chip
- **WHEN** the user clicks the "Internal Topics" filter chip in the sidebar header
- **THEN** the active connection controller SHALL toggle the internal topics visibility setting
- **AND** the filter chip SHALL visually reflect its active or inactive state with tonal color and selection checkmark

#### Scenario: Toggling stream topics filter chip
- **WHEN** the user clicks the "Stream Topics" filter chip in the sidebar header
- **THEN** the active connection controller SHALL toggle the stream topics visibility setting
- **AND** the filter chip SHALL visually reflect its active or inactive state with tonal color and selection checkmark

#### Scenario: Compact layout preserves vertical space
- **WHEN** the topic filter controls are rendered
- **THEN** both filter chips SHALL be arranged in a horizontal row or wrap directly below the search bar, occupying minimal vertical height compared to multi-line switches
