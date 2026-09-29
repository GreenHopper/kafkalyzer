## Purpose

Provides collapsible and expandable sidebar panels across primary Kafkalyzer views to reduce horizontal visual clutter and maximize message investigation real estate on compact laptop displays and small viewports.

## ADDED Requirements

### Requirement: Collapsible Topic Explorer Sidebar
The Topic Explorer view (`ExplorerView`) SHALL allow users to collapse and expand the cluster and topic selection sidebar to maximize horizontal space for topic messages, tables, and message inspection.

#### Scenario: Collapse topic sidebar via toggle button
- **WHEN** the user is viewing the Topic Explorer and activates the sidebar collapse control
- **THEN** the system SHALL smoothly collapse the cluster and topic list sidebar
- **AND** the main topic detail view SHALL expand horizontally to utilize the freed space
- **AND** a compact expand control SHALL remain accessible to restore the sidebar

#### Scenario: Expand topic sidebar from collapsed state
- **WHEN** the topic sidebar is collapsed
- **AND** the user activates the sidebar expand control
- **THEN** the system SHALL expand the cluster and topic list sidebar to its standard width
- **AND** the cluster and topic list SHALL become fully interactive again

#### Scenario: Keyboard shortcut toggles topic sidebar
- **WHEN** the Topic Explorer view is active
- **AND** the user presses `Ctrl+B` (or `Cmd+B` on macOS)
- **THEN** the system SHALL toggle the collapsed state of the topic sidebar

#### Scenario: Topic sidebar state persistence
- **WHEN** the user collapses or expands the topic sidebar
- **THEN** the system SHALL persist the collapsed state in local preferences
- **AND** returning to the Topic Explorer view SHALL restore the saved collapsed state

### Requirement: Collapsible Script List Sidebar
The Script Manager view (`ScriptManagerView`) SHALL allow users to collapse and expand the script catalog sidebar when editing scripts, running scripts, or viewing execution histories.

#### Scenario: Collapse script list sidebar
- **WHEN** a script is selected in the Script Manager
- **AND** the user activates the script catalog collapse control
- **THEN** the system SHALL collapse the script list sidebar
- **AND** the active script tab view (Run, History, or Editor) SHALL expand to occupy the full width

#### Scenario: Expand script list sidebar
- **WHEN** the script list sidebar is collapsed
- **AND** the user activates the script catalog expand control
- **THEN** the system SHALL restore the script list sidebar to view and select other scripts

#### Scenario: Script list state persistence
- **WHEN** the user changes the collapsed state of the script list sidebar
- **THEN** the system SHALL persist the preference
- **AND** restore it upon subsequent visits to the Script Manager

### Requirement: Collapsible Script Run Overview Sidebar
The script execution results view (`ScriptRunDetailsView`) SHALL allow users to collapse and expand the script run overview sidebar (containing total examined metrics, parameter summaries, and step topic trees).

#### Scenario: Collapse script run overview sidebar
- **WHEN** inspecting script execution results in `ScriptRunDetailsView`
- **AND** the user activates the run overview toggle in `ScriptRunHeader`
- **THEN** the system SHALL collapse the `ScriptRunSidebar`
- **AND** the message results container (`MessagesView`) SHALL expand to fill the full remaining width

#### Scenario: Expand script run overview sidebar
- **WHEN** the script run overview sidebar is collapsed
- **AND** the user activates the run overview toggle in `ScriptRunHeader`
- **THEN** the system SHALL expand `ScriptRunSidebar` back to its standard width

#### Scenario: Stepper and side-docking maintain spacious viewport when run sidebar is collapsed
- **WHEN** the script run overview sidebar and script catalog sidebar are both collapsed
- **AND** the message inspector panel is docked to the side
- **THEN** the message stream and the side-docked inspector panel SHALL each have sufficient width without horizontal squeeze or line-wrapping collisions
