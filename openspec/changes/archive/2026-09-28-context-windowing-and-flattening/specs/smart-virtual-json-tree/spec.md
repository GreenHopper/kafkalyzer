## ADDED Requirements

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

## MODIFIED Requirements

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
