# Spec Delta

## MODIFIED Requirements

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

#### Scenario: Tooltip while the configuration is still loading
- **WHEN** the user hovers over a topic whose configuration has not been loaded yet
- **THEN** the tooltip SHALL show partition count and replication factor
- **AND** it SHALL show retention and cleanup policy as "loading" and SHALL NOT show a made-up or default value

#### Scenario: Tooltip for a configuration that is not readable
- **WHEN** the configuration of a topic could not be read because the broker denied it or returned no entries
- **THEN** the tooltip SHALL show retention and cleanup policy as "not readable — permission?"

#### Scenario: Tooltip for a configuration that failed to load
- **WHEN** loading the configuration of a topic failed for another reason, for example a timeout
- **THEN** the tooltip SHALL show retention and cleanup policy as "could not be loaded"

#### Scenario: Tooltip for a topic with a metadata error
- **WHEN** the broker reported an error in the metadata of a topic
- **THEN** the tooltip SHALL show the error and SHALL show partition count, replication factor and partition health as unknown

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
- **WHEN** the user enters a search filter query (e.g., `db2.` or `migration`) in the topic filter input in substring mode
- **THEN** each matching substring in the rendered `TopicListItem` title SHALL be rendered with a distinct highlight style (accented background and/or primary highlight color)
- **AND** matching is evaluated case-insensitively while preserving the original casing of the topic name

#### Scenario: Highlighting regular expression matches
- **WHEN** the filter is in regex mode and the pattern `v[0-9]+$` matches the end of `orders.v2`
- **THEN** the matched part `v2` SHALL be highlighted in the same style as a substring match

#### Scenario: No highlighting in glob mode
- **WHEN** the filter is in glob mode
- **THEN** topic names SHALL be shown without match highlighting, because a glob matches the whole name

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

#### Scenario: Only changelog and repartition topics count as stream topics
- **WHEN** the stream topics chip is off and the cluster has `app-store-changelog`, `app-agg-repartition` and `orders-topic`
- **THEN** `app-store-changelog` and `app-agg-repartition` SHALL be hidden
- **AND** `orders-topic` SHALL be shown, because the suffix `-topic` does not mark a Kafka Streams topic

#### Scenario: Internal topics are recognised by a leading underscore
- **WHEN** the internal topics chip is off
- **THEN** topics whose name starts with `_` (for example `__consumer_offsets` or `_schemas`) SHALL be hidden

## ADDED Requirements

### Requirement: Metadata-First Topic List Loading

The topic list SHALL appear as soon as the cluster metadata is read, without waiting for topic configurations. Configurations SHALL then load in the background in bounded chunks. The configuration of an opened topic SHALL load before the remaining chunks. One failed chunk SHALL affect only the topics in that chunk.

#### Scenario: List appears before configurations
- **WHEN** the user connects to a cluster
- **THEN** the sidebar SHALL list all topics from the metadata response before any configuration has been loaded
- **AND** configurations SHALL fill in while the list stays usable

#### Scenario: Opened topic loads its configuration first
- **WHEN** the user opens a topic whose configuration has not been loaded yet while background loading is still running
- **THEN** the configuration of that topic SHALL be requested before the next background chunk
- **AND** the topic header SHALL show retention and cleanup policy as loading until it arrives

#### Scenario: A failed chunk does not hide other configurations
- **WHEN** one configuration chunk times out
- **THEN** only the topics of that chunk SHALL be marked "could not be loaded"
- **AND** configurations already loaded and later chunks SHALL still be shown

#### Scenario: Retrying a configuration that could not be loaded
- **WHEN** the user opens a topic whose configuration is marked "could not be loaded" and activates "Retry" in the topic header
- **THEN** the system SHALL request the configuration of that topic again and show it as loading

#### Scenario: Refresh or disconnect stops background loading
- **WHEN** the user refreshes the topic list or disconnects while configuration chunks are still loading
- **THEN** no result of an earlier load SHALL be applied to the new list or to another cluster

### Requirement: Topic List Age and Refresh

The sidebar SHALL show when the topic list was last loaded, as a relative age that updates while the list is shown. Refreshing the topic list SHALL NOT depend on the Schema Registry state, and the previous list SHALL stay visible while a refresh runs.

#### Scenario: Showing the list age
- **WHEN** the topic list was loaded 5 minutes ago
- **THEN** the sidebar header SHALL show "updated 5 min ago" in the active locale
- **AND** the text SHALL advance without user interaction while the sidebar is open

#### Scenario: Refresh while Schema Registry subjects are loading
- **WHEN** the Schema Registry subjects of the active cluster are still loading or failed
- **THEN** the topic list refresh action SHALL stay enabled and SHALL reload the topic list

#### Scenario: Previous list stays visible during refresh
- **WHEN** the user refreshes a topic list that is already shown
- **THEN** the previous list SHALL stay visible and usable with a visible progress indicator until the new list arrives
- **AND** the refresh action SHALL be disabled only while the topic list itself is loading

### Requirement: Topic Filter Modes

The topic filter SHALL offer three modes: substring (default), glob (`*` and `?`, matched against the whole name) and regular expression (matched anywhere in the name). All modes SHALL ignore letter case. An invalid pattern SHALL be reported at the input and SHALL NOT filter the list.

#### Scenario: Glob filter
- **WHEN** the filter mode is glob and the user enters `orders.*.v?`
- **THEN** `orders.eu.v1` SHALL be shown and `orders.eu.v10` and `archive.orders.eu.v1` SHALL be hidden

#### Scenario: Regular expression filter
- **WHEN** the filter mode is regex and the user enters `^(orders|payments)\.`
- **THEN** only topics whose name starts with `orders.` or `payments.` SHALL be shown

#### Scenario: Invalid regular expression
- **WHEN** the filter mode is regex and the user enters `orders(`
- **THEN** the filter input SHALL show a localized "invalid pattern" error
- **AND** the list SHALL be shown without a text filter, and the hidden count SHALL not include a text filter

#### Scenario: Switching the mode keeps the text
- **WHEN** the user switches the filter mode while text is entered
- **THEN** the text SHALL be kept and applied under the new mode

### Requirement: Hidden Topic Count

When the internal topics switch, the stream topics switch or the text filter hide topics, the sidebar SHALL show how many topics are hidden and by which filter. It SHALL offer an action that shows all topics again.

#### Scenario: Hidden count by reason
- **WHEN** 3 internal topics are hidden by the internal topics switch and 40 topics do not match the text filter
- **THEN** the sidebar SHALL show "43 hidden"
- **AND** its tooltip SHALL list 3 internal topics and 40 topics not matching the filter

#### Scenario: Show all hidden topics
- **WHEN** the user activates "Show all" on the hidden count
- **THEN** the text filter SHALL be cleared and both switches SHALL be set to show internal and stream topics

#### Scenario: Nothing hidden
- **WHEN** no topic is hidden
- **THEN** no hidden count SHALL be shown

### Requirement: Topic List Sorting

The user SHALL be able to sort the topic list by name (default, ascending), by partition count (descending) or by health. Health order SHALL be: topics with a metadata error, then topics with leaderless or under-replicated partitions (most affected first), then topics with unknown health, then healthy topics. Ties SHALL be ordered by name.

#### Scenario: Sort by partition count
- **WHEN** the user selects sorting by partitions
- **THEN** the topic with the most partitions SHALL be listed first and topics with equal counts SHALL be ordered by name

#### Scenario: Sort by health
- **WHEN** the user selects sorting by health and the cluster has a topic with 2 leaderless partitions, a topic with a metadata error and healthy topics
- **THEN** the topic with the metadata error SHALL be first, the topic with leaderless partitions second and the healthy topics last

#### Scenario: Unknown partition data in sorting
- **WHEN** a topic has a metadata error and the list is sorted by partitions
- **THEN** that topic SHALL be listed after all topics with a known partition count and SHALL NOT be treated as having 0 partitions

### Requirement: Topic Name Prefix Grouping

When grouping is on, topics SHALL be grouped by the first segment of their name, split at the first `.`, `-` or `_` after any leading underscores. A group SHALL be shown only when at least two visible topics share it; other topics SHALL appear as ungrouped rows. Groups SHALL be collapsible and show their topic count.

#### Scenario: Grouping by first name segment
- **WHEN** grouping is on and the visible topics are `orders.eu`, `orders.us`, `orders-dlq` and `billing`
- **THEN** a group `orders` with 3 topics SHALL be shown
- **AND** `billing` SHALL be shown as an ungrouped row

#### Scenario: Collapsing a group
- **WHEN** the user collapses the group `orders`
- **THEN** its topics SHALL be hidden and its header SHALL still show the topic count

#### Scenario: Grouping respects sort order and filters
- **WHEN** grouping is on, the list is sorted by partitions and a text filter is active
- **THEN** groups SHALL be ordered by name, the topics in each group SHALL follow the selected sort order, and only matching topics SHALL be counted and shown

#### Scenario: Failure topics inside sorted or grouped lists
- **WHEN** a primary topic has associated retry or DLQ topics and the list is sorted or grouped
- **THEN** the primary topic SHALL still show its failure-topic count and expandable sub-tree

### Requirement: Favourite Topics

The user SHALL be able to mark topics as favourites from the topic row. Favourites SHALL be shown in a section at the top of the list, independent of the internal and stream switches but subject to the text filter. A favourite that is not in the loaded list SHALL stay in the section, marked "not in topic list".

#### Scenario: Marking a favourite
- **WHEN** the user activates the favourite control on the row of `orders.eu`
- **THEN** `orders.eu` SHALL appear in the favourites section at the top of the list
- **AND** the control SHALL show the favourite state with an icon and a tooltip, not by colour alone

#### Scenario: Favourite missing from the list
- **WHEN** a favourite topic is not in the loaded topic list
- **THEN** the favourites section SHALL show it marked "not in topic list" with unknown metadata
- **AND** opening it SHALL load its metadata by name as for any topic not in the list

#### Scenario: Removing a favourite
- **WHEN** the user activates the favourite control of a favourite topic
- **THEN** the topic SHALL be removed from the favourites section

### Requirement: Per-Cluster Topic List Preferences

The internal and stream switches, filter mode, sort order, grouping on or off, and favourites SHALL be saved per cluster profile and restored on the next connection to that cluster. The filter text SHALL NOT be saved. Unreadable saved preferences SHALL be reported and preserved, not silently replaced.

#### Scenario: Preferences restored per cluster
- **WHEN** the user turns on internal topics and regex mode for cluster A, then connects to cluster B and back to A
- **THEN** cluster B SHALL use its own saved settings or the defaults
- **AND** cluster A SHALL again show internal topics with regex mode

#### Scenario: Defaults without saved preferences
- **WHEN** a cluster has no saved preferences
- **THEN** internal and stream topics SHALL be hidden, the mode SHALL be substring, sorting SHALL be by name, grouping SHALL be off and there SHALL be no favourites

#### Scenario: Unreadable saved preferences
- **WHEN** the saved preferences of a cluster cannot be parsed
- **THEN** the sidebar SHALL show a localized notice that the saved list settings were unreadable, and the defaults SHALL be used
- **AND** the unreadable value SHALL be backed up before it is overwritten, and SHALL NOT be overwritten if the backup fails

### Requirement: Not Readable Topics and Configurations

A topic whose metadata has an error SHALL be listed with that error instead of being left out. Configurations the broker denies or returns empty SHALL be marked "not readable — permission?". Configurations that fail for another reason SHALL be marked "could not be loaded" with the cause. Missing values SHALL never look like real values.

#### Scenario: Topic with a metadata error
- **WHEN** the metadata response contains a topic with an error, for example "topic authorization failed" or "leader not available"
- **THEN** the topic SHALL be listed with a warning icon and the error in its tooltip
- **AND** its partition count, replication factor and health SHALL be shown as unknown

#### Scenario: Configuration denied
- **WHEN** reading the configuration of a topic is denied or returns no entries
- **THEN** the topic header and tooltip SHALL show retention and cleanup policy as "not readable — permission?"
- **AND** they SHALL NOT be hidden or shown with a default value

#### Scenario: Topics not visible to the principal
- **WHEN** the broker leaves topics out of the list because the principal may not describe them
- **THEN** the system SHALL NOT invent entries for them
- **AND** such a topic SHALL still be openable by name, where its error is shown

### Requirement: Topic List Performance

The filtered, sorted and grouped topic list SHALL be computed once per change of its inputs (topic list, filter text, mode, switches, sort order, grouping, favourites), not when rows are built. With 10 000 topics, filtering and building the list SHALL stay within the bounds in the scenarios.

#### Scenario: One computation per input change
- **WHEN** the list inputs do not change and the sidebar rebuilds or reads the visible list any number of times
- **THEN** the list SHALL NOT be filtered, sorted or grouped again

#### Scenario: Computing a list of 10 000 topics
- **WHEN** 10 000 topics are filtered by a regular expression, sorted by health and grouped by prefix
- **THEN** the computation SHALL finish in under 100 ms in the automated test run

#### Scenario: Building a list of 10 000 topics
- **WHEN** the sidebar shows 10 000 topics in an 800 px high window
- **THEN** at most 60 topic rows SHALL be built
- **AND** typing one character into the filter SHALL rebuild at most 60 topic rows

### Requirement: Read-only Topic List Loading

Loading the topic list, single-topic metadata and topic configurations SHALL use only read-only metadata and describe requests. No topic SHALL be created, changed or deleted, including when a topic is requested by name that does not exist.

#### Scenario: Requesting a topic that does not exist
- **WHEN** the system loads the metadata of a topic name that does not exist on the cluster
- **THEN** the topic SHALL be reported as "topic not found"
- **AND** the request SHALL NOT create the topic

#### Scenario: Read-only gate
- **WHEN** the read-only verification script runs on the code of this capability
- **THEN** it SHALL pass without a new exception
