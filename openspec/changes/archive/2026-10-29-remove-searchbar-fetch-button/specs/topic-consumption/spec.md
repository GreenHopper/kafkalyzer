# Spec Delta

## MODIFIED Requirements

### Requirement: Preset-Based Scan Mode Selector

The topic search configuration SHALL provide four primary scan mode presets ("Latest N Messages", "Live Tail Stream", "Time Range", and "Offset / Earliest") that automatically configure consumer start and stop strategies without requiring manual configuration of independent start and stop matrices.

#### Scenario: Selecting "Latest N Messages" preset
- **WHEN** the user selects the "Latest N Messages" scan mode preset
- **THEN** the start strategy SHALL be set to `latest` and the stop strategy to `latest`
- **AND** the consumer SHALL stop upon reaching partition high watermarks or the result limit

#### Scenario: Selecting "Live Tail Stream" preset
- **WHEN** the user selects the "Live Tail Stream" scan mode preset
- **THEN** the start strategy SHALL be set to `latest` and the stop strategy to `stream`
- **AND** the consumer SHALL continue polling for newly arriving messages until manually stopped

#### Scenario: Selecting "Time Range" preset
- **WHEN** the user selects the "Time Range" scan mode preset
- **THEN** the search bar SHALL display start and end timestamp input controls
- **AND** consumption SHALL be bounded between the specified timestamps

#### Scenario: Selecting "Offset / Earliest" preset
- **WHEN** the user selects the "Offset / Earliest" scan mode preset
- **THEN** the search bar SHALL display offset selection controls with options for earliest or explicit custom partition offsets

## REMOVED Requirements

### Requirement: Context-Sensitive Form-Integrated Action Button
**Reason**: Message consumption is initiated and halted using the primary action controls in the topic header progress tile. Displaying a duplicate action button in the search bar control row creates unnecessary visual clutter, consumes valuable horizontal space, and causes confusion with duplicate triggers.
**Migration**: Trigger or stop message retrieval via the header progress tile ("Stream" / "Stop" button), or press Enter in the quick filter input.

### Requirement: Visual Dirty-State Indication for Search Parameters
**Reason**: The dirty-state badge and icon were tied directly to the search bar integrated action button, which has been removed.
**Migration**: Triggering a new fetch from the header action controls or by pressing Enter in the quick filter input executes with the currently configured parameters.
