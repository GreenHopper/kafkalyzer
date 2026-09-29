## MODIFIED Requirements

### Requirement: Node Expansion and Collapsing
The viewer SHALL allow users to expand and collapse object and array nodes, dynamically updating the flattened list of visible rows while preserving the user's scroll position, and SHALL automatically expand single-entry collections by default.

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
- **THEN** the viewer SHALL automatically expand the single-item node by default
- **AND** its child element SHALL be immediately visible in the tree without requiring a manual click

### Requirement: Entity Formatter Engine for Composite Badges
The system SHALL provide an extensible heuristics engine (`EntityFormatterRegistry`) that inspects Map structures to detect semantic composite entities before rendering them as multi-line trees, evaluating non-null/non-empty properties to maximize badge recognition on sparse objects.

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

#### Scenario: Fallback to standard node rendering
- **WHEN** a JSON Map does not match any registered entity heuristic and its non-null entries exceed compact limits (e.g. contains multiple nested non-empty objects, non-empty lists, or more than 4 non-null keys)
- **THEN** `EntityFormatterRegistry` SHALL return null
- **AND** the node SHALL render as a standard expandable JSON object

## ADDED Requirements

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
