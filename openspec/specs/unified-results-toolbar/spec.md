# unified-results-toolbar Specification

## Purpose

Provides an ergonomic, context-aware results toolbar in `MessagesView` with clear in-memory search indication, dynamic loaded message counters, context-sensitive sort controls, and labeled view mode buttons to eliminate search confusion and sorting redundancy.

## Requirements

### Requirement: Explicit In-Memory Search Labeling and Loaded Message Counter

The message results search bar in `MessagesView` SHALL explicitly identify itself as an in-memory filter over the currently loaded messages, displaying a dynamic placeholder referencing the total loaded message count, and SHALL display the total count of loaded messages and matching messages.

#### Scenario: Displaying dynamic search hint with loaded message count
- **WHEN** 200 messages are loaded in `MessagesView`
- **THEN** the search bar hint text SHALL state that it filters within the 200 loaded messages (e.g., "Filter in 200 loaded messages...")
- **AND** when zero search phrase is entered, the toolbar SHALL indicate that 200 messages are loaded

#### Scenario: Displaying matching results count during active search
- **WHEN** a user enters a search phrase matching 14 out of 200 loaded messages
- **THEN** the toolbar SHALL display the match count in relation to the total (e.g., "14 matches")
- **AND** provide an instant clear action to reset the filter

---

### Requirement: Context-Aware Sort Controls in Results Toolbar

The `MessagesView` toolbar SHALL conditionally display the toolbar sort-field selector and sort-order toggle button only in views where native column-based sorting is unavailable (such as Timeline and Diff views), and SHALL hide them when the Table view is active.

#### Scenario: Sort controls hidden in Table view
- **WHEN** the user switches `MessagesView` to Table mode (`table`)
- **THEN** the toolbar sort-field selector dropdown and sort-order toggle button SHALL NOT be rendered in the toolbar
- **AND** message sorting SHALL be managed exclusively through interactive table column headers

#### Scenario: Sort controls visible in Timeline and Diff views
- **WHEN** the user switches `MessagesView` to Timeline mode (`timeline`) or Diff mode (`diff`)
- **THEN** the toolbar sort-field selector dropdown and sort-order toggle button SHALL be rendered and interactive in the toolbar

---

### Requirement: Labeled View Mode Switcher

The `ViewModeSwitcher` in `MessagesView` SHALL render text labels alongside icons for each available view mode segment to ensure unambiguous visual discovery.

#### Scenario: Rendering labeled view mode segments
- **WHEN** `ViewModeSwitcher` is rendered in `MessagesView`
- **THEN** each segment SHALL display both an icon and a localized text label:
  - Table view segment with table icon and label ("Table" / "Tabelle")
  - Timeline view segment with list/clock icon and label ("Timeline" / "Zeitverlauf")
  - Diff view segment with difference icon and label ("Diff" / "Vergleich")
  - Schema view segment (when enabled) with schema icon and label ("Schema")

---

### Requirement: Quick Filter Covers Headers, Partition and Offset

The in-memory quick filter SHALL match a message when the case-insensitive query occurs in its key, value, topic, step name (scripting views), a header key or a header value. A query that is a whole number SHALL also match messages whose partition or offset equals that number. Match count, row dimming and the filtered list SHALL use the same rule.

#### Scenario: Match on a header value
- **WHEN** a loaded message has header `traceId: abc-123` and its key and value do not contain `abc-123`
- **AND** the user types `abc-123` into the quick filter
- **THEN** the message SHALL be counted as a match and SHALL remain visible

#### Scenario: Numeric query matches offset exactly
- **WHEN** the user types `1042`
- **THEN** the message at offset 1042 SHALL match
- **AND** a message at offset 10420 SHALL NOT match unless `1042` occurs in its key, value, topic or headers

#### Scenario: Numeric query matches partition
- **WHEN** the user types `3`
- **THEN** every message in partition 3 SHALL match

#### Scenario: Dimmed non-matches agree with the count
- **WHEN** "show non-matches" is active and the quick filter has a query
- **THEN** exactly the messages counted as matches SHALL be shown undimmed

### Requirement: Diff Ignore-List Control in the Results Toolbar

While the diff view is active, the results toolbar SHALL render the "Ignored fields (n)" control inline next to the
view-mode switcher instead of in a separate row above the timeline. When results span more than one topic, the topic
selector for the ignore list SHALL sit next to the button in the toolbar, and when the stored ignore list is unreadable,
the toolbar SHALL show an inline warning. In all other view modes the ignore-list control SHALL NOT be shown.

#### Scenario: Diff view shows ignored fields in toolbar
- **WHEN** the user switches `MessagesView` to Diff mode (`diff`) on a single topic with 2 ignored fields
- **THEN** the results toolbar SHALL show "Ignored fields (2)" inline with the view-mode switcher
- **AND** no extra row or divider SHALL be rendered between the results toolbar and the diff timeline

#### Scenario: Switching away from Diff mode hides the control
- **WHEN** the user switches from Diff mode to Table or Timeline mode
- **THEN** the "Ignored fields" control SHALL NOT be rendered in the toolbar

#### Scenario: Multi-topic diff results
- **WHEN** the loaded messages in Diff mode belong to two or more topics
- **THEN** a compact topic selector SHALL appear in the results toolbar next to the "Ignored fields (n)" button
- **AND** selecting a topic SHALL update the shown count and the dialog target to that topic's ignore list

#### Scenario: Unreadable ignore list warning in toolbar
- **WHEN** the stored ignore list of the active topic is unreadable while Diff mode is shown
- **THEN** the toolbar SHALL show a warning indicator with the localized warning message next to the "Ignored fields" button
