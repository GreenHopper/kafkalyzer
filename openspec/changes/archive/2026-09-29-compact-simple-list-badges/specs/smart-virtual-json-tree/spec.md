## MODIFIED Requirements

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
