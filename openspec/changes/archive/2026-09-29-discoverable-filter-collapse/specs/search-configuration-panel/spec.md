## Purpose

Defines the collapsible Search Configuration filter panel on the topic search view, including clear expand and collapse affordances so users can reclaim vertical space for message results.

## ADDED Requirements

### Requirement: Discoverable Expand and Collapse Affordance

The Search Configuration panel header SHALL present a visual expand/collapse control that clearly indicates whether the filter area is expanded or collapsed. The control MUST use a standard expand/collapse chevron (or equivalent stateful disclosure icon) that changes with panel state. A static settings or tune icon MUST NOT be the sole trailing affordance that replaces the expand/collapse indicator.

#### Scenario: Expanded panel shows collapse affordance

- **WHEN** the Search Configuration panel is expanded
- **THEN** the header SHALL display a visual affordance that communicates the panel can be collapsed (for example an upward or expanded-state chevron)
- **AND** the filter controls within the panel SHALL be visible

#### Scenario: Collapsed panel shows expand affordance

- **WHEN** the Search Configuration panel is collapsed
- **THEN** the header SHALL remain visible
- **AND** the header SHALL display a visual affordance that communicates the panel can be expanded (for example a downward or collapsed-state chevron)
- **AND** the filter controls within the panel SHALL be hidden

### Requirement: Header Toggle Interaction

Activating the Search Configuration header (title row or expand/collapse affordance) SHALL toggle the panel between expanded and collapsed states. The interaction SHALL expose an accessible tooltip that describes the collapse or expand action based on the current state.

#### Scenario: Collapse via header

- **WHEN** the Search Configuration panel is expanded
- **AND** the user activates the header
- **THEN** the panel SHALL collapse and hide its filter controls
- **AND** the results area SHALL gain the vertical space previously occupied by the filter controls

#### Scenario: Expand via header

- **WHEN** the Search Configuration panel is collapsed
- **AND** the user activates the header
- **THEN** the panel SHALL expand and show its filter controls

#### Scenario: Tooltip describes toggle action

- **WHEN** the user focuses or hovers the Search Configuration header toggle
- **THEN** the system SHALL show a localized tooltip indicating collapse when expanded, or expand when collapsed

### Requirement: Localized Panel Title

The Search Configuration panel title and related expand/collapse tooltips SHALL be localized via the application localization system. Hardcoded user-facing strings for these labels MUST NOT be used.

#### Scenario: Localized title is displayed

- **WHEN** the topic search view is shown
- **THEN** the Search Configuration panel title SHALL be rendered from a localized string
