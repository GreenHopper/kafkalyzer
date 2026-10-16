# ergonomic-script-workspace Specification

## Purpose

Provides a secure, self-documenting, and ergonomic scripting execution workspace with confirmation guards for script deletion, searchable script catalog, constrained parameter forms, and read-only pipeline step preview.

## Requirements

### Requirement: Confirmation Guard for Script Deletion
Deleting a script from `ScriptManagerView` SHALL require explicit user confirmation via an `AlertDialog` before removing the script from storage.

#### Scenario: User clicks delete on a script in the sidebar
- **WHEN** the user triggers the delete action on a script item in `ScriptManagerView`
- **THEN** a confirmation dialog SHALL be displayed naming the script to be deleted
- **AND** the script SHALL only be deleted from storage if the user explicitly confirms the dialog action

#### Scenario: User cancels script deletion
- **WHEN** the deletion confirmation dialog is displayed and the user cancels or dismisses it
- **THEN** the script SHALL remain intact in storage and in the sidebar list

---

### Requirement: Constrained Parameter Form and Pipeline Preview in ScriptRunView
The `ScriptRunView` form SHALL constrain parameter input widths to an ergonomic maximum (<= 560px), place the primary "Run Script" button directly below the inputs, and display a read-only overview of the script's configured execution steps and target topics alongside the form in a responsive two-column layout.

#### Scenario: Viewing a multi-step script in the Run tab
- **WHEN** a user selects a script in `ScriptManagerView` on the "Run" tab
- **THEN** the view SHALL display a two-column workspace on desktop viewports (>= 900px)
- **AND** the left column SHALL contain the target cluster selection, typed variable input fields with clean visual badges, and the primary run button
- **AND** the right column SHALL display a read-only pipeline preview detailing each step's name, target topics, filter template, and extracted variables

#### Scenario: Responsive adaptation on narrow viewports
- **WHEN** the window width is narrower than 900px
- **THEN** the parameter form and pipeline preview SHALL stack vertically into a single scrollable column

---

### Requirement: Inline Script Search in ScriptManagerView
The `ScriptManagerView` sidebar SHALL provide an inline search field to filter the script list by script name in real-time.

#### Scenario: Filtering scripts by name
- **WHEN** the user enters a search query in the script sidebar filter field
- **THEN** only scripts whose names case-insensitively match the query SHALL be visible in the list

#### Scenario: Clearing search query
- **WHEN** the search query is cleared
- **THEN** all available scripts SHALL be displayed in the list
