# command-palette Specification

## Purpose

Lets the user reach cluster profiles, topics, consumer groups, saved scripts and the main destinations by name from
anywhere in the main window, using only the keyboard and only data that is already loaded.

## Requirements

### Requirement: Open the Command Palette
Pressing `Cmd+K` on macOS or `Ctrl+K` on Linux and Windows SHALL open the command palette from every main
destination, wherever keyboard focus is in the main window, including in a text field. On macOS, `Ctrl+K` SHALL
also open it unless a text field has focus, where it keeps its native text-editing meaning. The palette SHALL NOT
open over another dialog, and SHALL NOT open twice.

#### Scenario: Open from any destination
- **WHEN** the Explorer, Consumer Lag, Scripts or Settings view is shown and the user presses the palette shortcut
- **THEN** the command palette opens with an empty, focused search field

#### Scenario: Open while a text field has focus
- **WHEN** the Explorer topic filter has focus on Linux or Windows and the user presses `Ctrl+K`
- **THEN** the command palette opens and no character is inserted into the topic filter

#### Scenario: Native text command on macOS is kept
- **WHEN** a text field has focus on macOS and the user presses `Ctrl+K`
- **THEN** the palette does not open and the text field handles the key as before
- **WHEN** the user presses `Cmd+K` instead
- **THEN** the command palette opens

#### Scenario: Another dialog is open
- **WHEN** a dialog (for example Quick Jump, the shortcut overview or a profile editor) is open and the user presses
  the palette shortcut
- **THEN** no palette opens

#### Scenario: Palette already open
- **WHEN** the palette is open and the user presses the palette shortcut again
- **THEN** no second palette opens

### Requirement: Palette Shortcut Does Not Trigger Other Shortcuts
A palette shortcut press SHALL NOT also trigger another shortcut. The message view's single-letter shortcuts
(`J`, `K`, `F`) SHALL act only when no `Ctrl`, `Cmd` or `Alt` key is held.

#### Scenario: Inspector open
- **WHEN** a message inspector is open with a message selected and the user presses `Ctrl+K` or `Cmd+K`
- **THEN** the command palette opens and the selected message does not change

#### Scenario: Plain letter shortcuts unchanged
- **WHEN** a message inspector is open, no text field has focus and the user presses `K` without a modifier
- **THEN** the previous message is selected as before and the palette does not open

### Requirement: Palette Shortcut in the Shortcut Catalogue
The palette shortcut SHALL be declared in the application's central shortcut catalogue as a global shortcut. It
SHALL appear in the shortcut overview with a localized description, and the catalogue's conflict rules SHALL apply
to it.

#### Scenario: Listed in the overview
- **WHEN** the user opens the shortcut overview
- **THEN** the command palette shortcut is listed in the global group, rendered as `⌘K` on macOS and `Ctrl+K` on Linux
  and Windows

### Requirement: Palette Sources
The palette SHALL search these entries: all cluster profiles; all topics of the active cluster (regardless of the
sidebar filter and the internal/stream topic visibility); the consumer groups that the Consumer Lag view has loaded
for the active cluster in this session; all saved scripts; and the four main navigation destinations. Every result
SHALL show its name and its kind as text and an icon.

#### Scenario: Not connected
- **WHEN** no cluster is active and the user opens the palette
- **THEN** the palette offers cluster profiles, saved scripts and navigation destinations, and no topics or consumer
  groups

#### Scenario: Connected
- **WHEN** a cluster is active, its topic list has loaded and the user types part of a topic name
- **THEN** the matching topics of that cluster appear, labelled as topics

#### Scenario: Topic hidden in the sidebar
- **WHEN** the sidebar topic filter or the internal-topic visibility hides a topic and the user types its name in the
  palette
- **THEN** the topic still appears in the palette

#### Scenario: Consumer groups not loaded yet
- **WHEN** a cluster is active but the Consumer Lag view has not loaded its consumer groups in this session
- **THEN** the palette lists no consumer groups and shows a note that consumer groups appear after Consumer Lag has
  loaded them

#### Scenario: Topic list failed to load
- **WHEN** the active cluster's topic list failed to load or is still loading
- **THEN** the palette lists no topics for it and does not show the cluster as having no topics

### Requirement: Palette Uses Only Loaded Data
Typing in the palette SHALL NOT start any network request. The palette SHALL search only lists that are already in
memory, and SHALL NOT start, stop or change anything on a Kafka cluster or a Schema Registry by itself.

#### Scenario: Typing makes no request
- **WHEN** the user types a query of any length into the palette
- **THEN** no Kafka, Schema Registry or other network request is made, and results update from in-memory lists

#### Scenario: Read-only actions
- **WHEN** the user runs any palette entry
- **THEN** the resulting action uses only the application's existing read-only connect, browse and lag paths

### Requirement: Fuzzy Matching and Ranking
A result SHALL match when every character of the query appears in its name in order, ignoring case. Results SHALL be
ranked so that exact, prefix, contiguous and word-start matches come before scattered matches. Ties keep a fixed
kind order, then sort alphabetically. An empty query SHALL list the navigation destinations first.

#### Scenario: Subsequence match
- **WHEN** the user types `ordevt` and a topic `orders.events` exists
- **THEN** `orders.events` is listed

#### Scenario: Better match ranks first
- **WHEN** the user types `orders` and the topics `orders`, `orders.events` and `ops-reader-dlq-events` exist
- **THEN** `orders` is listed before `orders.events`, and `orders.events` before `ops-reader-dlq-events`

#### Scenario: No match
- **WHEN** the query matches no entry
- **THEN** the palette shows a "no results" message and `Enter` does nothing

#### Scenario: Large topic list
- **WHEN** the active cluster has many thousands of topics
- **THEN** the palette shows at most a bounded number of results and says that more matches exist

### Requirement: Keyboard-Only Operation
The palette SHALL be fully usable with the keyboard. The first result SHALL be highlighted after every change of the
query. `ArrowDown`/`ArrowUp` SHALL move the highlight and keep it visible, `Enter` SHALL run the highlighted entry
and close the palette, and `Escape` SHALL close the palette without any action. Mouse clicks on a result SHALL work
the same as `Enter`.

#### Scenario: Navigate and run
- **WHEN** the user types a query, presses `ArrowDown` twice and presses `Enter`
- **THEN** the third result runs and the palette closes

#### Scenario: Cancel
- **WHEN** the user presses `Escape` in the palette
- **THEN** the palette closes, nothing changes, and focus returns to where it was before

### Requirement: Palette Entry Actions
Running an entry SHALL do the following. A cluster profile connects to that cluster with the usual progress
feedback and shows the Explorer; if it is already active, the Explorer is shown. A topic opens its tab in the
Explorer, or focuses the tab if it is already open. A consumer group shows Consumer Lag with that group's details
open. A navigation destination is selected.

#### Scenario: Connect to a profile
- **WHEN** the user runs a cluster profile entry for a cluster that is not active
- **THEN** the Explorer is shown and the connection starts with the usual progress feedback

#### Scenario: Connection fails
- **WHEN** the connection started from the palette fails
- **THEN** the error is shown the same way as for a connection started from the Explorer

#### Scenario: Focus an open topic tab
- **WHEN** a tab for topic `orders` is already open and the user runs the `orders` topic entry
- **THEN** the Explorer is shown with the existing `orders` tab active, and no second tab opens

#### Scenario: Open consumer group details
- **WHEN** the user runs a consumer group entry
- **THEN** Consumer Lag is shown with that group visible and its details expanded

#### Scenario: Consumer group no longer exists
- **WHEN** the group from the palette is not in the list the Consumer Lag view loads
- **THEN** the view shows that the group was not found instead of an empty or zero-lag entry

#### Scenario: Navigation destination
- **WHEN** the user runs the "Settings" entry
- **THEN** the Settings view is shown and the rail marks Settings as selected

### Requirement: Scripts Open Without Starting
Running a saved-script entry SHALL show the Scripts view with that script selected and its Run tab shown. The script
SHALL NOT start. A script run that is already in progress SHALL continue unchanged.

#### Scenario: Open a script
- **WHEN** the user runs the entry for script `daily-check`
- **THEN** the Scripts view shows `daily-check` on its Run tab and no run starts

#### Scenario: Another script is running
- **WHEN** script `A` is running and the user runs the palette entry for script `B`
- **THEN** script `B` is shown on its Run tab and the run of `A` continues

### Requirement: Hand-off to Quick Jump
When the palette query is a valid message reference link, the palette SHALL offer, as its first result, an entry
that opens the Quick Jump dialog with that link filled in. Quick Jump SHALL keep its own shortcut and behaviour.

#### Scenario: Pasted reference
- **WHEN** the user pastes a valid `kafkalyzer://` reference into the palette and presses `Enter`
- **THEN** the palette closes and the Quick Jump dialog opens with the reference filled in and parsed

#### Scenario: Ordinary text
- **WHEN** the query is not a valid reference link
- **THEN** no Quick Jump entry is offered
