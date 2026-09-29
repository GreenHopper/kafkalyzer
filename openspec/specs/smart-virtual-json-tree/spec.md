# smart-virtual-json-tree Specification

## Purpose

Provides a high-performance, virtualized JSON tree visualization (`SmartVirtualJsonTree`) that transforms complex, deeply nested JSON documents into a flat list of visible rows ($O(\text{visible})$), incorporates an extensible heuristics engine (`EntityFormatterRegistry`) for progressive disclosure via inline smart badges (`SmartCompositeBadge`), offers interactive copyable popovers, and supports deep search match jumping.

## Requirements

### Requirement: Virtualized Flattened JSON Tree Rendering
The viewer SHALL flatten arbitrary JSON objects (Maps and Lists) into a linear list of visible node entries rendered via a virtualized list view (`ListView.builder` or `ScrollablePositionedList`), rendering only items currently within the viewport bounds.

#### Scenario: High performance on large JSON structures
- **WHEN** a JSON document containing over 1,000 nodes or nested array entries is loaded into the viewer
- **THEN** the system SHALL instantiate widgets only for the visible viewport rows
- **AND** the viewer SHALL maintain smooth scrolling performance without freezing the UI thread

#### Scenario: Full horizontal width utilization
- **WHEN** a JSON tree is rendered in the viewer
- **THEN** the tree SHALL span the full available width of its container
- **AND** the layout SHALL NOT partition the screen into fixed multi-column masonry columns

#### Scenario: Type styling and indentation guides
- **WHEN** JSON nodes are rendered in the tree
- **THEN** keys, strings, numbers, booleans, and null values SHALL display distinct syntax coloring
- **AND** nested nodes SHALL display indentation guide lines indicating hierarchy depth

### Requirement: Node Expansion and Collapsing
The viewer SHALL allow users to expand and collapse object and array nodes, dynamically updating the flattened list of visible rows while preserving the user's scroll position, and SHALL automatically expand single-entry collections by default unless they are formatted as compact composite badges.

#### Scenario: Toggle node expansion
- **WHEN** a user clicks on an expandable node's chevron or header
- **THEN** the node SHALL toggle between expanded and collapsed states
- **AND** the flattened list SHALL immediately reflect the added or removed descendant rows
- **AND** the expansion state of sibling and unaffected nodes SHALL remain intact

#### Scenario: Expand and collapse depth control
- **WHEN** a user initiates an expand-all or collapse-all action
- **THEN** all non-primitive nodes in the tree SHALL transition to the chosen state

#### Scenario: Automatic expansion of single-item collections
- **WHEN** a JSON list contains exactly one item (or an object contains exactly one property)
- **AND** the node has not been explicitly collapsed by the user
- **AND** the node is not eligible for compact badge rendering
- **THEN** the viewer SHALL automatically expand the single-item node by default
- **AND** its child element SHALL be immediately visible in the tree without requiring a manual click

#### Scenario: Single-item primitive list collapsed badge rendering
- **WHEN** a JSON list contains 1 to 3 primitive values eligible for compact badge formatting
- **AND** the node is rendered collapsed
- **THEN** the viewer SHALL display the compact composite badge on a single row without expanding into individual index items

### Requirement: Entity Formatter Engine for Composite Badges
The system SHALL provide an extensible heuristics engine (`EntityFormatterRegistry`) that inspects Map and List structures to detect semantic composite entities before rendering them as multi-line trees, evaluating non-null/non-empty properties to maximize badge recognition on sparse objects and compact primitive lists.

#### Scenario: Address entity recognition
- **WHEN** a JSON Map contains keys matching address semantics (e.g. `ort`, `city`, `plz`, `zip`, `strasse`, or `street`)
- **THEN** `EntityFormatterRegistry` SHALL produce a `FormattedBadgeData` object with a location icon, formatted single-line address text, and accent styling
- **AND** the node SHALL render as a composite badge rather than expanding into multiple key-value rows

#### Scenario: Time-window entity recognition
- **WHEN** a JSON Map contains keys matching date/time range semantics (e.g. `startDate`/`validFrom`/`planTimestampVon`/`von` and `endDate`/`validTo`/`planTimestampBis`/`bis`)
- **THEN** `EntityFormatterRegistry` SHALL produce a `FormattedBadgeData` object with a date/time icon and formatted range string (`$start → $end`)
- **AND** the heuristic SHALL support values that are either date strings or nested timestamp objects (extracting the timestamp property)

#### Scenario: Geo-coordinates entity recognition
- **WHEN** a JSON Map contains keys matching geographic coordinates (`lat`/`latitude` and `lon`/`lng`/`longitude`)
- **THEN** `EntityFormatterRegistry` SHALL produce a `FormattedBadgeData` object with a map pin icon and formatted coordinate string (`$lat, $lon`)

#### Scenario: Generic compact flat object recognition
- **WHEN** a JSON Map does not match specific domain entities (address, time-window, geo) but consists of 1 to 4 non-null, non-empty flat primitive fields (even if additional keys with null or empty values are present, such as 5 fields where 3 are null)
- **AND** the combined formatted string length is within compact badge limits (<= 80 characters)
- **THEN** `EntityFormatterRegistry` SHALL produce a `FormattedBadgeData` object with a generic object icon (`Icons.data_object`) and a compact summary label joining key-value pairs (or highlighting dominant fields like `id`, `art`, `type`, `code`, and `name`)
- **AND** the node SHALL render as a compact `SmartCompositeBadge` with full detail view in its popover

#### Scenario: Standalone timestamp entity recognition
- **WHEN** a JSON Map represents a timestamp with metadata (e.g. contains a primary timestamp key such as `timestamp` or `zeit` alongside secondary metadata like `zeitQuelle` or `source`)
- **THEN** `EntityFormatterRegistry` SHALL produce a `FormattedBadgeData` object with a clock icon, human-readable formatted timestamp, and optional metadata tag
- **AND** the node SHALL render as a single-line composite badge with full key-value details in its popover

#### Scenario: Route and transport leg entity recognition
- **WHEN** a JSON Map contains paired directional keys (e.g. `von...` and `nach...`, `from` and `to`, `origin` and `destination`, or `source` and `target`)
- **THEN** `EntityFormatterRegistry` SHALL produce a `FormattedBadgeData` object with a transport/route icon and arrow-formatted string (`$origin → $destination`)

#### Scenario: Compact primitive list recognition
- **WHEN** a JSON List contains between 1 and 3 items
- **AND** all items are non-null primitive values (strings, numbers, or booleans)
- **AND** the combined formatted string representation (e.g. `["ENTLADESTELLE"]` or `["A", "B"]`) does not exceed 80 characters
- **THEN** `EntityFormatterRegistry` SHALL produce a `FormattedBadgeData` object with a list/collection icon, formatted list summary label, and accent styling
- **AND** the node SHALL render as a compact `SmartCompositeBadge` when collapsed

#### Scenario: Fallback to standard node rendering
- **WHEN** a JSON Map or List does not match any registered entity heuristic, contains complex nested structures (nested maps or lists), or exceeds compact limits
- **THEN** `EntityFormatterRegistry` SHALL return null
- **AND** the node SHALL render as a standard expandable JSON object or array

### Requirement: Progressive Disclosure via SmartCompositeBadge
Recognized composite entities and compact primitive lists SHALL render as an inline `SmartCompositeBadge` chip that provides full progressive disclosure through an interactive popover overlay.

#### Scenario: Inline badge rendering
- **WHEN** an entity or list is formatted by `EntityFormatterRegistry`
- **THEN** it SHALL render on a single line containing an icon, the property key, and the summarized badge label

#### Scenario: Interactive popover on hover
- **WHEN** a user hovers the cursor over a `SmartCompositeBadge`
- **THEN** an `OverlayPortal` popover SHALL appear adjacent to the badge displaying the structured key-value pairs of the underlying Map or the indexed entries of the underlying List

#### Scenario: Click-to-pin popover for selection and copy
- **WHEN** a user clicks on a `SmartCompositeBadge`
- **THEN** the popover SHALL become pinned (locked open)
- **AND** the user SHALL be able to move the cursor into the popover to select and copy text using `SelectableText` without the popover closing
- **AND** clicking the badge again or clicking the close button SHALL unpin and close the popover

#### Scenario: Copy full composite object
- **WHEN** a user clicks the copy button in the popover header
- **THEN** the complete JSON or string representation of the composite object or list SHALL be copied to the clipboard
- **AND** a confirmation toast or snackbar SHALL be displayed

### Requirement: In-Tree Search Highlighting and Match Navigation
The tree viewer SHALL highlight matching search terms, support seamless jumping between search results with vertical center-alignment, and emphasize the currently active match with distinct visual styling.

#### Scenario: Highlight matching keys and values
- **WHEN** an active search query is provided to `SmartVirtualJsonTree`
- **THEN** occurrences of the query substring in keys and values SHALL be highlighted with a distinctive background color
- **AND** ancestor nodes enclosing the matches SHALL be automatically expanded so matches are visible

#### Scenario: Programmatic match jumping with vertical centering
- **WHEN** the viewer's `jumpToMatch(index)` method is called with a valid match index
- **THEN** the virtualized list SHALL scroll smoothly to position the matching row at the vertical center (`alignment: 0.5`) of the visible viewport

#### Scenario: Active match cursor emphasis
- **WHEN** a match is the currently focused match from `jumpToMatch`
- **THEN** the matching row SHALL display an active focus indicator (such as an accent border or target match indicator) distinguishing it from passive search matches

### Requirement: Context Windowing for Array Lists
The viewer SHALL calculate visibility segments around matching items within array structures during search, displaying immediate neighbor items within a defined context radius (default ±1) while collapsing non-matching index ranges into compact, interactive placeholder rows.

#### Scenario: Array segmentation around search matches
- **WHEN** an array contains multiple items and a search query matches an item at index `i`
- **AND** context windowing is active
- **THEN** the viewer SHALL display items at `[i - 1]`, `[i]`, and `[i + 1]` (clamped to array bounds)
- **AND** preceding items `[0 .. i - 2]` SHALL be collapsed into a single placeholder row indicating the hidden item count and index span
- **AND** succeeding items `[i + 2 .. N - 1]` SHALL be collapsed into a single placeholder row indicating the hidden item count and index span

#### Scenario: Expand collapsed range on tap
- **WHEN** a user clicks on a collapsed range placeholder row
- **THEN** the hidden items within that range SHALL expand inline in the virtual tree
- **AND** the placeholder SHALL display an option or affordance to re-collapse the range

#### Scenario: Toggle between match context and full array view
- **WHEN** an array contains collapsed ranges
- **AND** the user toggles the array view mode to "Show all"
- **THEN** all elements in the array SHALL be rendered without collapsed range placeholders
- **AND** toggling to "Focus matches" SHALL re-apply the context window segmentation

### Requirement: Indentation Flattening for Single-Child Chains
The tree flattener SHALL detect unbranched single-child hierarchy chains in JSON objects and arrays, compressing intermediate hierarchy steps into a single compound breadcrumb row to reduce indentation depth and preserve horizontal space.

#### Scenario: Unbranched object-to-object flattening
- **WHEN** an object node contains exactly one child key whose value is another object
- **THEN** the flattener SHALL combine the parent key and child key into a compound breadcrumb key (e.g. `parent.child`)
- **AND** the node SHALL render at the parent's indentation depth without introducing an additional indentation step

#### Scenario: Unbranched array-to-object flattening
- **WHEN** an array element node contains an object with a single child
- **THEN** the flattener SHALL combine the index and child key into a compound breadcrumb key (e.g. `[i].child`)
- **AND** the node SHALL render at the array element's indentation depth

#### Scenario: Expand and collapse on compound nodes
- **WHEN** a user clicks the expansion toggle on a compound breadcrumb node
- **THEN** all descendants of the innermost child in the chain SHALL toggle expansion together

### Requirement: Retirement of Unvirtualized Cards Viewer
The legacy `JsonCardViewer` SHALL be removed entirely from Kafkalyzer, and `JsonOrStringViewer` SHALL support `Tree` (powered by `SmartVirtualJsonTree`) and `Raw` view modes.

#### Scenario: View mode selection
- **WHEN** a valid JSON payload is loaded in `JsonOrStringViewer`
- **THEN** the viewer SHALL display mode toggles for `Tree` and `Raw`
- **AND** the `Cards` mode toggle SHALL NOT be present
- **AND** `Tree` mode SHALL be selected by default

### Requirement: Pin Field to Table Columns from Virtual Tree
The virtual JSON tree SHALL provide an affordance on node rows allowing users to project any selected field as a column in the master message table.

#### Scenario: Calculate normalized JSON path
- **WHEN** the user triggers the "Pin as Column" action on a tree node
- **THEN** the system SHALL resolve the node's hierarchy into a normalized dot-and-bracket JSON path (e.g. `customer.address.city` or `leistungen[0].transportId`) without internal virtual tree prefixes (e.g. stripping `root.`)
- **AND** the system SHALL invoke the `onPinToColumn` callback with the resolved JSON path

#### Scenario: Visual feedback on pinning
- **WHEN** a field path is pinned to table columns
- **THEN** the application SHALL display a feedback message (e.g. SnackBar) indicating that the column was pinned
- **AND** if the column is already present in the active table columns, the system SHALL inform the user without creating duplicate columns

### Requirement: Filter and Hide Empty Null Fields
The JSON tree viewer SHALL provide a user-controllable filter to hide properties whose values are `null` (and optionally empty collections), eliminating vertical clutter on sparse payloads.

#### Scenario: Toggle hide empty fields
- **WHEN** a user clicks the "Hide empty fields" toggle in the viewer toolbar
- **THEN** the tree SHALL immediately refresh to exclude rows whose values are `null`
- **AND** the toolbar button SHALL visually reflect the active filter state
- **AND** a counter or indicator SHALL communicate that empty fields are hidden

#### Scenario: Expandable objects with all-null children
- **WHEN** an object node contains only null properties and empty-field filtering is active
- **THEN** the object SHALL be represented as empty or collapsed with an indication that all child fields are null
- **AND** unhiding empty fields SHALL immediately restore the full hierarchy

#### Scenario: Persistence of hide-null preference
- **WHEN** the user changes the "Hide empty fields" toggle setting
- **THEN** the preference SHALL be persisted in local storage (`SharedPreferences`)
- **AND** subsequent messages inspected in the session SHALL preserve the chosen visibility mode

### Requirement: Human-Readable Smart Timestamp Formatting
The JSON tree viewer SHALL automatically detect and format temporal values (ISO-8601 strings and epoch timestamps) into localized, readable date-time presentations while preserving access to exact raw values.

#### Scenario: Inline localized timestamp rendering
- **WHEN** a leaf string value matches ISO-8601 date/time patterns (e.g. `2026-09-29T19:00:00+01:00`) or an integer represents an epoch millisecond timestamp associated with a temporal key
- **THEN** the value SHALL render with a clock/calendar icon and formatted localized date-time text (e.g. `29.09.2026 19:00:00 (+01:00)`)
- **AND** the original raw value SHALL NOT be mutated in the underlying message data

#### Scenario: Timestamp tooltip and raw value inspection
- **WHEN** a user hovers over or taps a formatted timestamp value
- **THEN** a tooltip or popover SHALL display the exact raw timestamp, UTC equivalent, and local timezone offset
- **AND** the row copy action SHALL allow copying either the raw timestamp or formatted string

### Requirement: Enhanced Timeline Card Preview Formatting
The timeline message cards in the stream view SHALL present clean, uncluttered payload previews that omit null properties.

#### Scenario: Clean payload preview in timeline cards
- **WHEN** a message with a JSON payload containing null fields is displayed in the timeline view
- **THEN** the payload preview SHALL filter out null-valued keys before generating the 3-line summary preview
- **AND** the card preview SHALL prioritize non-null business identifiers and active status values over empty fields
