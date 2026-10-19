# compact-topic-sidebar Specification

## Purpose

Provides high-density topic list items with hierarchical name formatting, compact metadata badges, and streamlined filter controls in the Explorer sidebar to maximize visible topic count and accelerate topic discovery.

## Requirements

### Requirement: Single-Line Topic List Items with Comprehensive Tooltip

Each item in the Explorer topic list SHALL render in a compact, single-line layout displaying the topic name with hierarchical styling and only essential trailing action controls. All inline metadata badges (including partition count and schema badges) SHALL be omitted from the card row, and all topic metadata SHALL be presented inside the hover tooltip alongside the full topic name.

#### Scenario: Hierarchical topic name formatting with dot-separated segments
- **WHEN** a topic name containing dot-separated segments (e.g., `kaenup.pmxcor.temp.incomingOutlookMessage`) is rendered in the topic sidebar
- **THEN** the namespace prefix segments (`kaenup.pmxcor.temp.`) SHALL be displayed with dimmed or secondary text styling
- **AND** the terminal leaf segment (`incomingOutlookMessage`) SHALL be visually emphasized with bold text styling
- **AND** single-segment topic names without dots SHALL be rendered entirely in bold text styling

#### Scenario: Omitting inline metadata badges from the card row
- **WHEN** a topic having 12 partitions and an associated Avro schema is rendered in the sidebar
- **THEN** the list item SHALL NOT render inline `<N>P` partition badges or `Avro` schema badges on the card face
- **AND** the full horizontal width between the leading margin and the trailing action icon SHALL be allocated to the topic name

#### Scenario: Comprehensive metadata and full topic name in hover tooltip
- **WHEN** the user hovers over a topic item in the sidebar
- **THEN** a tooltip SHALL display the full untruncated topic name on the first line
- **AND** the tooltip SHALL display the partition count, replication factor, retention duration, cleanup policy, and schema indicator (`Schema: Avro` when an Avro schema is registered for the topic's key or value)

#### Scenario: Preserving interaction workflows
- **WHEN** the user interacts with a compact topic item
- **THEN** single-clicking SHALL select the topic and open it in the active or new tab
- **AND** double-clicking SHALL immediately initiate bounded message streaming
- **AND** clicking the trailing "open in new tab" icon button SHALL open a separate tab for the topic

---

### Requirement: Middle-Ellipsis Topic Name Truncation and Search Match Highlighting

When a topic name exceeds the available single-line width in `TopicListItem`, the system SHALL truncate the middle of the topic name using an ellipsis (`…`) rather than truncating the terminal leaf segment at the end. When a search filter query is active, matching substrings within the displayed topic name SHALL be visually highlighted.

#### Scenario: Middle-ellipsis truncation preserves prefix start and terminal leaf segment
- **WHEN** a long hierarchical topic name (e.g., `dataops.cdc.db2.jdbc.LKW_TRANSPORT_ORDER_HEADER`) exceeds the available single-line width of `TopicListItem`
- **THEN** the rendered text SHALL remain on a single line (`maxLines: 1`)
- **AND** the middle portion of the name SHALL be replaced with `…` (e.g., `dataops.cdc…LKW_TRANSPORT_ORDER_HEADER`) so that both the leading namespace context and the bold terminal suffix remain visible and distinguishable from sibling topics

#### Scenario: Highlighting active search filter matches in topic names
- **WHEN** the user enters a search filter query (e.g., `db2.` or `migration`) in the topic filter input
- **THEN** each matching substring in the rendered `TopicListItem` title SHALL be rendered with a distinct highlight style (accented background and/or primary highlight color)
- **AND** matching is evaluated case-insensitively while preserving the original casing of the topic name

---

### Requirement: Resizable Topic Sidebar

The Explorer topic sidebar SHALL provide an interactive vertical resize handle along its right border when expanded, allowing the user to adjust the sidebar width within ergonomic bounds and persisting the chosen width across application restarts.

#### Scenario: Dragging the sidebar resize handle adjusts width
- **WHEN** the Explorer sidebar is expanded and the user drags the vertical resize divider horizontally
- **THEN** the sidebar width SHALL update immediately within the allowed bounds (minimum `260px`, default `360px`, maximum `700px`)
- **AND** the `TopicListItem` rows SHALL dynamically recompute their single-line middle-ellipsis layout to reveal more of the topic names

#### Scenario: Persisting custom sidebar width
- **WHEN** the user resizes the Explorer sidebar and restarts or rebuilds the Explorer view
- **THEN** the sidebar width SHALL be restored from `SharedPreferences` (`explorer_sidebar_width`)

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
