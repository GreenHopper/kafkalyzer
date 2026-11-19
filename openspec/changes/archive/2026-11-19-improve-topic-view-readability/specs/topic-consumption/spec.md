## MODIFIED Requirements

### Requirement: Progressive Disclosure for Advanced Topic Search Filters

The topic search bar SHALL default to a compact, single-row primary control layout. The fetch filter field SHALL offer `Search Scope: Key | Value | Both` and `Filter Type: Contains | Regex | Exact` through a compact inline menu inside the field that always shows the current choice. The remaining parameters (`Field`, `Partition`, `Fast Trace` and `Expression`) SHALL be reachable through a single "More filters" button that opens a popover overlaying the results instead of pushing them down. The button SHALL show the number of active parameters. While the popover is closed, any non-default parameter SHALL be visibly summarized as removable or clickable filter chips in the compact bar.

#### Scenario: Initial display in collapsed mode
- **WHEN** a topic view is opened
- **THEN** the search bar SHALL occupy a single row containing the scan mode, the limit, the fetch filter field with its scope and type menu, and the "More filters" button
- **AND** the `Field`, `Partition`, `Fast Trace` and `Expression` controls SHALL be hidden

#### Scenario: Scope and type visible in the field
- **WHEN** the user sets the scope to `Key` and the type to `Exact`
- **THEN** the fetch filter field SHALL show "Key · Exact" (localized) in its inline menu without opening any panel
- **AND** the fetch filter field's placeholder SHALL name the selected scope

#### Scenario: Expanding advanced filters
- **WHEN** the user activates the "More filters" button
- **THEN** a popover with `Field`, `Partition`, `Fast Trace` with its partition preview, and the expression editor SHALL open below the button
- **AND** the message list and an active stream SHALL keep their position and SHALL NOT be pushed down

#### Scenario: Closing more filters
- **WHEN** the popover is open and the user presses Escape, clicks outside it or activates the button again
- **THEN** the popover SHALL close and its entered values SHALL be kept

#### Scenario: Active filter count
- **WHEN** a partition filter and a filter expression are set
- **THEN** the "More filters" button SHALL show the count 2, conveyed by text and not by colour alone

#### Scenario: Non-default filter chips when collapsed
- **WHEN** the user has configured a partition filter (e.g. Partition `3`) and closes the popover
- **THEN** compact chips displaying the active values (e.g. `Partition: 3`) SHALL appear in the compact search bar
- **AND** clicking a chip or its removal icon SHALL allow quick editing or clearing of the parameter

#### Scenario: Active expression chip when collapsed
- **WHEN** the user has entered a filter expression and closes the popover
- **THEN** a chip SHALL show the expression's canonical text, shortened with an ellipsis when long and complete in its tooltip
- **AND** the chip SHALL indicate an invalid expression by an icon and text, not by colour alone
- **AND** clicking the chip SHALL open the popover with the expression editor and its removal icon SHALL clear the expression

#### Scenario: Popover on a small window
- **WHEN** the window is too low to show the whole popover below the button
- **THEN** the popover content SHALL scroll within the visible window area and its controls SHALL stay reachable

#### Scenario: Restored session and saved search
- **WHEN** a tab session or saved search with field, type, scope, partition, Fast Trace and expression values is restored
- **THEN** every value SHALL be applied unchanged and reflected in the inline menu, the button count and the chips

### Requirement: Filter Pattern Validation Feedback

The search configuration SHALL validate a regular-expression filter term before a scan starts and whenever the term changes, and SHALL report an invalid pattern to the user in the active UI language at the input that caused it.

#### Scenario: Invalid pattern blocks the scan
- **WHEN** the user enters the filter term `orders[` with filter type `Regex` and triggers the scan
- **THEN** the scan SHALL be refused
- **AND** the filter input SHALL show a localized inline error naming the invalid term
- **AND** the inline scope and type menu of the field SHALL indicate the invalid state by an icon, not by colour alone

#### Scenario: Valid pattern produces no validation message
- **WHEN** the user enters a syntactically valid regular expression and triggers the scan
- **THEN** the scan SHALL start and no validation error SHALL be shown

## ADDED Requirements

### Requirement: Compact Scan Bounds Row

When the scan mode needs bounds (Time Range or Offset / Earliest), the search bar SHALL show them in one additional row
directly below the primary row. Relative time presets SHALL be offered through one menu per bound instead of rows of
preset chips. The row SHALL wrap onto a second line only when the pane is too narrow for both bounds.

#### Scenario: Time range on a laptop
- **WHEN** the user selects the "Time Range" scan mode in a pane 1000 logical pixels wide
- **THEN** start and end time SHALL be shown side by side in a single row, each with a preset menu
- **AND** no row of preset chips SHALL be shown

#### Scenario: Applying a preset
- **WHEN** the user picks "Last 1 hour" from the start time preset menu
- **THEN** the start time SHALL be set exactly as the former preset chip did

#### Scenario: Narrow pane
- **WHEN** the pane is narrower than both bound inputs together
- **THEN** the end bound SHALL move onto a second line and both inputs SHALL remain fully usable

#### Scenario: Invalid bound
- **WHEN** the entered end time lies before the start time or cannot be parsed
- **THEN** the affected input SHALL show a localized inline error and the scan SHALL NOT start

### Requirement: Distinct Labels for Fetch-Time and Loaded-Message Filtering

The fetch filter field in the search bar and the in-memory filter of the results toolbar SHALL be labelled so that
users can tell them apart: the fetch filter SHALL name that it is applied while reading from the topic, and SHALL show
a tooltip explaining that it limits which messages are fetched.

#### Scenario: Both fields visible
- **WHEN** a topic view with 200 loaded messages is shown
- **THEN** the search bar field SHALL carry a localized label that it filters while fetching, with an explanatory tooltip
- **AND** the results toolbar field SHALL keep stating that it filters the 200 loaded messages

#### Scenario: German UI
- **WHEN** the UI language is German
- **THEN** both labels and the tooltip SHALL be rendered from German localized strings
