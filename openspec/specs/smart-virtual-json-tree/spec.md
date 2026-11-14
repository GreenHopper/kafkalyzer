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
The JSON tree viewer SHALL automatically detect and format ISO-8601 date-time strings into localized, readable date-time presentations, and SHALL make integer numbers in a plausible epoch range readable as dates through a tooltip without replacing the number, while preserving access to exact raw values.

#### Scenario: Inline localized timestamp rendering
- **WHEN** a leaf string value matches ISO-8601 date/time patterns (e.g. `2026-09-29T19:00:00+01:00`)
- **THEN** the value SHALL render with a clock/calendar icon and formatted localized date-time text (e.g. `29.09.2026 19:00:00 (+01:00)`)
- **AND** the original raw value SHALL NOT be mutated in the underlying message data

#### Scenario: Timestamp tooltip and raw value inspection
- **WHEN** a user hovers over or taps a formatted timestamp value
- **THEN** a tooltip or popover SHALL display the exact raw timestamp, UTC equivalent, and local timezone offset
- **AND** the row copy action SHALL allow copying either the raw timestamp or formatted string

#### Scenario: Epoch number date tooltip
- **WHEN** a leaf integer lies between 2000-01-01 and 2100-01-01 UTC when read as epoch seconds, milliseconds, microseconds or nanoseconds, for example `1768812660123`
- **THEN** the row SHALL still display the number unchanged
- **AND** hovering it SHALL show a tooltip with the date in the global time display mode (local or UTC), the same instant in the other zone as ISO-8601, and the assumed unit (for example "epoch milliseconds")

#### Scenario: Numbers outside the epoch range
- **WHEN** a leaf number is not an integer or lies outside every epoch range above, for example `42` or `3.5`
- **THEN** the row SHALL show no date tooltip

#### Scenario: Time display mode change
- **WHEN** the global time display mode changes from local to UTC while a tree is shown
- **THEN** the next epoch tooltip SHALL show the date in UTC first

### Requirement: Enhanced Timeline Card Preview Formatting
The timeline message cards in the stream view SHALL present clean, uncluttered payload previews that omit null properties.

#### Scenario: Clean payload preview in timeline cards
- **WHEN** a message with a JSON payload containing null fields is displayed in the timeline view
- **THEN** the payload preview SHALL filter out null-valued keys before generating the 3-line summary preview
- **AND** the card preview SHALL prioritize non-null business identifiers and active status values over empty fields

### Requirement: Copy Tree Node Value as JSON
The copy action on a tree row SHALL copy object and array nodes as valid, indented JSON of the complete subtree, independent of how far the node is expanded. Primitive nodes SHALL copy their plain value: strings without surrounding quotes, numbers and booleans in their JSON form, and null as `null`. A confirmation SHALL be shown after copying.

#### Scenario: Copying an object node
- **WHEN** the user activates the copy action on a row whose value is an object
- **THEN** the clipboard SHALL contain valid JSON that parses to the same object, including all nested fields

#### Scenario: Copying an array node
- **WHEN** the user activates the copy action on a row whose value is an array
- **THEN** the clipboard SHALL contain valid JSON that parses to the same array, including items hidden by context windowing

#### Scenario: Copying a primitive node
- **WHEN** the user activates the copy action on a row whose value is the string `abc`
- **THEN** the clipboard SHALL contain `abc` without quotes

### Requirement: Copy Field Path from Tree Row
A secondary click on a tree row SHALL open a context menu with "Copy value" and "Copy field path" (plus "Pin as column" where pinning is available). The copied path SHALL use the canonical field-path language, without internal tree prefixes, and SHALL resolve to the same field when used as a projected column or filter path.

#### Scenario: Copy a nested path
- **WHEN** the user chooses "Copy field path" on the `transportId` row inside the first entry of `leistungen`
- **THEN** the clipboard SHALL contain `leistungen[0].transportId`

#### Scenario: Key that cannot be written in dot form
- **WHEN** the user copies the path of a field whose key contains `.`, `[`, `]` or `/`, such as the key `a.b` inside `meta`
- **THEN** the clipboard SHALL contain the JSON Pointer form `/meta/a.b`, with `/` and `~` in keys escaped as `~1` and `~0`

#### Scenario: Path of a compound breadcrumb row
- **WHEN** the user copies the path of a row that shows a flattened single-child chain such as `order.customer`
- **THEN** the clipboard SHALL contain the full path of the innermost node of that chain

#### Scenario: Path round-trips through a projected column
- **WHEN** a copied path is added as a projected table column
- **THEN** the column SHALL show the value of the row the path was copied from

#### Scenario: Root row has no path
- **WHEN** the user opens the context menu on the root row of the tree
- **THEN** "Copy field path" SHALL NOT be offered

### Requirement: On-Demand Decoding of Tree Text Values
Every string row in the tree SHALL offer a "Decode as…" action with the options JSON, Base64 and gzip (Base64 text that is gunzipped). The decoded result SHALL appear in place as a child subtree of that row. The row SHALL keep showing the original value, and the user SHALL be able to remove the decoded view. Nothing SHALL be decoded without an explicit user action.

#### Scenario: Decode a JSON string field
- **WHEN** a row holds the string `{"id":7,"tags":["a"]}` and the user chooses "Decode as JSON"
- **THEN** the row SHALL become expandable and show a decoded subtree with `id: 7` and `tags` as an array
- **AND** the row SHALL still show the original string value and a marker that names the applied decoding

#### Scenario: Decode Base64 to text
- **WHEN** a row holds `aGVsbG8gd29ybGQ=` and the user chooses "Decode as Base64"
- **THEN** the decoded subtree SHALL contain the text `hello world`
- **AND** that text row SHALL itself offer "Decode as…" so that decodings can be chained, for example Base64 then JSON

#### Scenario: Base64 accepts common variants
- **WHEN** the value uses the URL-safe alphabet, lacks padding, or contains line breaks
- **THEN** "Decode as Base64" SHALL decode it the same way as standard padded Base64

#### Scenario: Decode Base64 to binary bytes
- **WHEN** a Base64 value decodes to bytes that are not valid UTF-8
- **THEN** the decoded subtree SHALL show the byte count and a hex preview of the first bytes
- **AND** the byte row SHALL offer gzip decompression and copying all bytes as hex

#### Scenario: Decode gzip-compressed Base64
- **WHEN** a row holds Base64 of gzip-compressed JSON and the user chooses "Decode as gzip"
- **THEN** the value SHALL be Base64-decoded and decompressed, and the decompressed text SHALL appear as a text row that can be decoded as JSON

#### Scenario: Remove a decoded view
- **WHEN** the user chooses "Show original only" on a decoded row
- **THEN** the decoded subtree SHALL disappear and the row SHALL look as before the decoding

#### Scenario: No automatic decoding
- **WHEN** a message is opened whose string fields contain JSON, Base64 or gzip data
- **THEN** every string row SHALL show its original value and no row SHALL be decoded until the user requests it

### Requirement: Bounded Off-Thread Decoding with Error Display
Decoding SHALL run off the UI thread and the row SHALL show a progress state while it runs. Input SHALL be limited to 8 MiB of text and decoded output to 16 MiB. A failed or over-limit decoding SHALL show a localized error on that row naming the reason, SHALL leave the original value unchanged and SHALL NOT look like an empty result.

#### Scenario: Large value stays responsive
- **WHEN** the user decodes a value of several megabytes
- **THEN** the UI SHALL stay responsive and the row SHALL show a progress indicator until the result or an error is shown

#### Scenario: Invalid Base64
- **WHEN** the user chooses "Decode as Base64" on a value that is not Base64
- **THEN** the row SHALL show an inline error "not valid Base64" and SHALL NOT show a decoded subtree

#### Scenario: Not gzip data
- **WHEN** the user chooses "Decode as gzip" on Base64 data that has no gzip header
- **THEN** the row SHALL show an inline error "not gzip data"

#### Scenario: Invalid JSON
- **WHEN** the user chooses "Decode as JSON" on `{"a":`
- **THEN** the row SHALL show an inline error that the value is not valid JSON

#### Scenario: Decompression exceeds the output limit
- **WHEN** a gzip value would decompress to more than 16 MiB
- **THEN** decompression SHALL stop at the limit without holding the full output in memory
- **AND** the row SHALL show an error naming the limit instead of a partial result

#### Scenario: Dismiss a decoding error
- **WHEN** a decoding error is shown on a row and the user dismisses it
- **THEN** the row SHALL return to its original state and the user SHALL be able to try another decoding

### Requirement: Decoded Subtrees Are View-Only
Decoded subtrees SHALL be part of the tree view: search SHALL find matches in them, and copying a decoded node SHALL copy the decoded content. Rows inside a decoded subtree SHALL NOT offer pinning as a column, filtering by field or copying a field path, because such content cannot be addressed by a field path. Decoded views SHALL be discarded when another message is shown.

#### Scenario: Search finds text inside a decoded subtree
- **WHEN** a string row was decoded as JSON and the active search query occurs only inside the decoded content
- **THEN** the match SHALL be highlighted in the decoded subtree and included in the match count

#### Scenario: Field actions are not offered inside decoded content
- **WHEN** the user looks at a row inside a decoded subtree
- **THEN** the row SHALL NOT offer "Pin as column", "Filter by field" or "Copy field path"
- **AND** the decoded row itself, whose original value is a field of the message, SHALL keep these actions

#### Scenario: Copy a decoded object
- **WHEN** the user copies an object node inside a decoded subtree
- **THEN** the clipboard SHALL contain that decoded object as valid JSON

#### Scenario: Next message clears decoded views
- **WHEN** decoded views are open and the user steps to another message
- **THEN** the new message SHALL show no decoded views and results of decodings still running for the old message SHALL be dropped

### Requirement: Whole-Value Decoding in the Payload Viewer
When the payload viewer shows a value that is not a JSON object or array, it SHALL offer the same "Decode as…" action for the whole value: Base64 and gzip for text, gzip for binary data shown in the hex view. The decoded result SHALL be shown as tree, text or hex view, and a "Show original" control SHALL return to the original view. The same limits and error display SHALL apply.

#### Scenario: Decode a Base64 header value
- **WHEN** the viewer shows the text value `eyJhIjoxfQ==` and the user chooses "Decode as Base64"
- **THEN** the viewer SHALL show the decoded text `{"a":1}` with the option to decode it further as JSON
- **AND** a banner SHALL name the applied decoding and offer "Show original"

#### Scenario: Decompress a binary gzip payload
- **WHEN** the viewer shows a binary payload in the hex view whose bytes are gzip data and the user chooses "Decode as gzip"
- **THEN** the decompressed content SHALL be shown as a tree if it is a JSON object or array, otherwise as text or hex

#### Scenario: Copy keeps the original value
- **WHEN** a decoded whole value is shown and the user activates the viewer's copy action
- **THEN** the original, undecoded value SHALL be copied, and a separate action SHALL copy the decoded content
