# unified-results-toolbar Specification Delta

## Purpose

Provides an ergonomic, context-aware results toolbar in `MessagesView` with clear in-memory search indication, dynamic loaded message counters, context-sensitive sort controls, and labeled view mode buttons to eliminate search confusion and sorting redundancy.

## ADDED Requirements

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
