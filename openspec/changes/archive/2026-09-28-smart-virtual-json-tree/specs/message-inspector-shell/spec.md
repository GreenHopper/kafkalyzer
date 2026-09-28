## Purpose

Updates payload viewing in the message inspector to use the virtualized `SmartVirtualJsonTree` with progressive disclosure smart badges and retires the legacy unvirtualized Cards view.

## MODIFIED Requirements

### Requirement: Default Viewer Mode Performance
When viewing JSON payloads in `JsonOrStringViewer` within the inspector, the system SHALL render the payload using the virtualized `SmartVirtualJsonTree` by default, and SHALL NOT display or support the deprecated unvirtualized Cards view mode.

#### Scenario: Initial view mode for valid JSON
- **WHEN** a message containing valid JSON is rendered in `JsonOrStringViewer` without a previously saved preference
- **THEN** the viewer SHALL display the `SmartVirtualJsonTree` view
- **AND** the viewer SHALL NOT provide an option to switch to an unvirtualized Cards view

### Requirement: Structured Multi-Tab Inspection
The inspector panel SHALL organize detailed message contents into tabs:
1. `Payload`: displays the message payload using `SmartVirtualJsonTree` with progressive disclosure smart badges, in-tree search, formatting, and copy controls.
2. `Key & Headers`: displays the full message key and a structured list of all Kafka headers with an item count badge.
3. `Raw JSON`: displays the serialized representation of the complete message for export.
