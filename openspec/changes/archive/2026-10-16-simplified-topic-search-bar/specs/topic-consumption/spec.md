# Spec Delta

## ADDED Requirements

### Requirement: Preset-Based Scan Mode Selector

The topic search configuration SHALL provide four primary scan mode presets ("Latest N Messages", "Live Tail Stream", "Time Range", and "Offset / Earliest") that automatically configure consumer start and stop strategies without requiring manual configuration of independent start and stop matrices.


#### Scenario: Selecting "Latest N Messages" preset
- **WHEN** the user selects the "Latest N Messages" scan mode preset
- **THEN** the start strategy SHALL be set to `latest` and the stop strategy to `latest`
- **AND** the primary action button label SHALL reflect a bounded fetch (e.g. "Fetch 200 Messages")
- **AND** the consumer SHALL stop upon reaching partition high watermarks or the result limit

#### Scenario: Selecting "Live Tail Stream" preset
- **WHEN** the user selects the "Live Tail Stream" scan mode preset
- **THEN** the start strategy SHALL be set to `latest` and the stop strategy to `stream`
- **AND** the primary action button label SHALL reflect an ongoing stream (e.g. "Start Live Stream")
- **AND** the consumer SHALL continue polling for newly arriving messages until manually stopped

#### Scenario: Selecting "Time Range" preset
- **WHEN** the user selects the "Time Range" scan mode preset
- **THEN** the search bar SHALL display start and end timestamp input controls
- **AND** consumption SHALL be bounded between the specified timestamps

#### Scenario: Selecting "Offset / Earliest" preset
- **WHEN** the user selects the "Offset / Earliest" scan mode preset
- **THEN** the search bar SHALL display offset selection controls with options for earliest or explicit custom partition offsets

---

### Requirement: Progressive Disclosure for Advanced Topic Search Filters

The topic search bar SHALL default to a compact, single-row primary control layout. Advanced filter parameters (`Field`, `Filter Type: Contains | Regex | Exact`, `Search Scope: Key | Value | Both`, `Partition`, and `Fast Trace`) SHALL be collapsed by default behind an "Advanced Filters" toggle. When collapsed, any non-default active advanced filter parameters SHALL be visibly summarized as removable or clickable filter chips in the compact bar.

#### Scenario: Initial display in collapsed mode
- **WHEN** a topic view is opened
- **THEN** advanced filter controls (`Field`, `Filter Type`, `Search Scope`, `Partition`, `Fast Trace`) SHALL be hidden in a collapsed panel
- **AND** the toggle button SHALL indicate the collapsed state (e.g. "Advanced" or "⚙️ Erweitert")

#### Scenario: Expanding advanced filters
- **WHEN** the user activates the advanced filters toggle
- **THEN** the advanced filter controls panel SHALL expand smoothly without disrupting the existing message list or active stream

#### Scenario: Non-default filter chips when collapsed
- **WHEN** the user has configured a partition filter (e.g. Partition `3`) or exact regex filter and collapses the advanced panel
- **THEN** compact chips displaying the active values (e.g. `Partition: 3`, `Regex`) SHALL appear in the compact search bar
- **AND** clicking a chip or its removal icon SHALL allow quick editing or clearing of the parameter

---

### Requirement: Context-Sensitive Form-Integrated Action Button

The primary trigger for starting message consumption SHALL be positioned directly within the search bar control row and SHALL dynamically reflect the selected mode and result limit.

#### Scenario: Bounded fetch button label
- **WHEN** the "Latest N Messages" preset is active with a limit of 200
- **THEN** the action button SHALL display a label indicating message fetch with the limit count (e.g. "Fetch 200 Messages" / "200 Nachrichten abrufen")
- **AND** clicking the button SHALL initiate bounded consumption without leaving the topic view

#### Scenario: Live tail button label
- **WHEN** the "Live Tail Stream" preset is active
- **THEN** the action button SHALL display a streaming indicator (e.g. "Start Live Stream" / "Live-Stream starten")

#### Scenario: Stream in progress action
- **WHEN** message streaming or fetching is actively in progress
- **THEN** the action button SHALL display a prominent "Stop" control with danger/warning styling to halt consumption

---

### Requirement: Visual Dirty-State Indication for Search Parameters

When messages are already loaded in the topic view and the user modifies any scan mode preset, query filter, result limit, or advanced setting, the search action button SHALL visually highlight the dirty state to make it obvious that the active results reflect previous parameters and a new fetch must be initiated.

#### Scenario: User changes filter after loading messages
- **WHEN** the topic message list contains messages from a prior fetch
- **AND** the user edits the quick filter text or changes the scan mode preset
- **THEN** the search action button SHALL adopt an accented dirty-state visual indicator (e.g. distinct highlight color and tooltip: "Filter changed – Click to fetch")
- **AND** initiating the new fetch SHALL clear the dirty-state indicator
