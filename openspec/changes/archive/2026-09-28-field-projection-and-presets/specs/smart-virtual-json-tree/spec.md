## ADDED Requirements

### Requirement: Pin Field to Table Columns from Virtual Tree
The virtual JSON tree SHALL provide an affordance on node rows allowing users to project any selected field as a column in the master message table.

#### Scenario: Calculate normalized JSON path
- **WHEN** the user triggers the "Pin as Column" action on a tree node
- **THEN** the system SHALL resolve the node's hierarchy into a normalized dot-and-bracket JSON path (e.g. `customer.address.city` or `leistungen[0].transportId`) without internal virtual tree prefixes (e.g. stripping `root.`)
- **AND** the system SHALL invoke the `onPinToColumn` callback with the resolved JSON path

#### Scenario: Visual feedback on pinning
- **WHEN** a field path is pinned to table columns
- **THEN** the application SHALL display a feedback message (e.g. SnackBar) indicating that the column was pinned
- **AND** if the column is already present in the active table columns, the system SHALL inform the user without creating duplicate columns
