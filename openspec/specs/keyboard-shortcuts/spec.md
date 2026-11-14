# keyboard-shortcuts Specification

## Purpose

Keeps every keyboard shortcut of the application in one catalogue that both the key bindings and a discoverable,
localized shortcut overview (`F1` / `?`) are built from, so shortcuts stay documented, conflict-free and consistent.

## Requirements

### Requirement: Central Shortcut Catalogue
Every application keyboard shortcut SHALL be declared once in a central catalogue with a stable identifier, the
context in which it is active, its key combinations and a localized description (English and German). Key bindings
SHALL take their key combinations from the catalogue. Two entries SHALL NOT share a key combination in the same
context or in a context and the global context.

#### Scenario: Binding and overview cannot drift
- **WHEN** the key combination of a catalogue entry is changed
- **THEN** the binding in the view and the entry in the shortcut overview both use the new combination

#### Scenario: Conflicting declaration is rejected
- **WHEN** a new entry declares a key combination that another entry already uses in the same context or globally
- **THEN** the automated catalogue check fails and names both entries

#### Scenario: Missing translation is rejected
- **WHEN** an entry has no English or no German description
- **THEN** the automated catalogue check fails

### Requirement: Existing Shortcuts Are Catalogued
The catalogue SHALL contain the shortcuts that already exist: toggle sidebar (`Ctrl+B`/`Cmd+B`, Explorer and
Scripts), Quick Jump (`Ctrl+G`/`Cmd+G`, Explorer), next/previous message (`J`/`ArrowDown`, `K`/`ArrowUp`),
toggle Focus Mode (`F`), exit Focus Mode or close the inspector (`Escape`), next/previous match in the inspector
search (`Enter`/`Shift+Enter`), close the inspector search (`Escape`) and the overview itself (`F1`, `?`).

#### Scenario: Overview lists existing shortcuts
- **WHEN** the user opens the shortcut overview
- **THEN** every shortcut listed in this requirement appears with its context and description

#### Scenario: Existing behaviour is unchanged
- **WHEN** the user presses `Ctrl+B` in the Explorer or `J` with the inspector open after this change
- **THEN** the sidebar toggles or the next message is selected exactly as before

### Requirement: Shortcut Overview
Pressing `F1` anywhere in the main window, or `?` while no text input has focus, SHALL open a dialog that lists all
catalogue entries grouped by context with their key combinations and descriptions. Settings SHALL also offer a
control that opens it. Pressing `Escape` SHALL close the dialog. Pressing the keys again while it is open SHALL NOT
open a second one.

#### Scenario: Open with F1
- **WHEN** the user presses `F1` while the main window has focus, including while a text field has focus
- **THEN** the shortcut overview opens

#### Scenario: Question mark in a text field is typed, not intercepted
- **WHEN** a text input has focus and the user types `?`
- **THEN** the character is inserted into the text field and the overview does not open

#### Scenario: Question mark outside text fields
- **WHEN** no text input has focus and the user types `?` (on any keyboard layout)
- **THEN** the shortcut overview opens

#### Scenario: Overview already open
- **WHEN** the overview is open and the user presses `F1` again
- **THEN** no second overview is opened

### Requirement: Platform-Specific Modifier Display
The overview SHALL render the primary modifier as `⌘` on macOS and as `Ctrl` on Linux and Windows, and SHALL use the
localized names of special keys (for example `Escape`, `Enter`, arrow keys).

#### Scenario: macOS rendering
- **WHEN** the overview is shown on macOS
- **THEN** the sidebar toggle is displayed as `⌘B`

#### Scenario: Linux or Windows rendering
- **WHEN** the overview is shown on Linux or Windows
- **THEN** the sidebar toggle is displayed as `Ctrl+B`
