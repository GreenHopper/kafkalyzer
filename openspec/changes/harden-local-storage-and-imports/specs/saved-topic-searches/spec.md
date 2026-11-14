# Spec Delta

## ADDED Requirements

### Requirement: Unreadable Search Presets Are Preserved

A stored search preset that cannot be read SHALL NOT be offered for selection, SHALL NOT hide the readable presets of
the same topic, and SHALL be kept unchanged when the user saves, updates or deletes another preset of that topic.

#### Scenario: Saving a preset next to an unreadable one
- **WHEN** the stored presets of a topic contain one unreadable entry and the user saves a new preset for that topic
- **THEN** the preset selector SHALL list the readable presets and the new one
- **AND** the stored data SHALL still contain the unreadable entry unchanged

#### Scenario: Deleting a preset next to an unreadable one
- **WHEN** the user deletes a readable preset of a topic that also has an unreadable stored entry
- **THEN** only the deleted preset SHALL be removed from storage
