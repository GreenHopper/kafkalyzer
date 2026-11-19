## ADDED Requirements

### Requirement: Single-Line Topic Facts Strip

The topic header SHALL show its facts in one line. The partition count, the replication factor, the message estimate and
the schema SHALL stay visible as long as they fit; other facts that do not fit SHALL be collapsed into a "+N" overflow
chip whose popover lists them with the same texts, tooltips and actions as in the strip.

#### Scenario: Laptop-width header
- **WHEN** the topic detail pane is 900 logical pixels wide and the topic shows partitions, RF, estimate, cleanup policy, retention time, retention size, the time-range action and a schema
- **THEN** the facts SHALL occupy a single line
- **AND** the facts that do not fit SHALL be reachable through a "+N" chip, where N is the number of collapsed facts

#### Scenario: Wide header
- **WHEN** all facts fit into the available width
- **THEN** no overflow chip SHALL be shown

#### Scenario: Overflow popover keeps actions
- **WHEN** the "Load time range" action or a "Retry" action is collapsed and the user opens the overflow popover
- **THEN** the popover SHALL offer the same action, and activating it SHALL behave as in the strip

#### Scenario: Keyboard and screen reader access
- **WHEN** a screen reader focuses the overflow chip
- **THEN** it SHALL announce a localized label naming the number of further facts, and the popover SHALL be operable with the keyboard

### Requirement: Warnings and Unknown Facts Are Never Collapsed

Facts that report a problem SHALL always stay visible in the strip and SHALL take precedence over regular facts:
unhealthy partitions, "not readable", "unknown" and "could not be loaded" states, and a failed time-range read.

#### Scenario: Unhealthy topic on a narrow header
- **WHEN** a topic has under-replicated partitions and the header is too narrow for all facts
- **THEN** the unhealthy-partitions fact SHALL remain visible in the strip
- **AND** regular facts SHALL be collapsed into the overflow chip first

#### Scenario: Configuration not readable
- **WHEN** reading the topic configuration was denied
- **THEN** the "not readable" fact SHALL remain visible in the strip and SHALL NOT be moved into the overflow popover

#### Scenario: Estimate unknown
- **WHEN** the message estimate is unknown because a partition could not be read
- **THEN** the "Messages: unknown" fact SHALL remain visible with its reason on hover
