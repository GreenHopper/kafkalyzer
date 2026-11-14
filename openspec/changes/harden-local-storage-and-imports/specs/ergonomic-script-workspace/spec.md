# Spec Delta

## ADDED Requirements

### Requirement: Unreadable Script Store Is Reported And Preserved

When stored scripts cannot be read, the system SHALL NOT present them as an empty script list and SHALL NOT
overwrite them silently. A single unreadable script SHALL NOT hide the readable ones and SHALL be kept unchanged on the
next save. If the whole store is unreadable, its raw content SHALL be backed up and saving scripts SHALL be refused
until the user explicitly discards the unreadable data.

#### Scenario: One corrupt script among valid ones
- **WHEN** the stored script list contains a script that cannot be read next to two readable scripts
- **THEN** the two readable scripts SHALL be listed in the script sidebar
- **AND** a notice SHALL state that one stored script could not be read
- **AND** after the user saves another script, the stored data SHALL still contain the unreadable entry unchanged

#### Scenario: Whole script store is corrupt
- **WHEN** the stored script data is not a readable script list
- **THEN** the Scripts view SHALL show a persistent notice that the stored scripts could not be read, including the location of a backup copy of the raw content
- **AND** creating, saving, duplicating or deleting a script SHALL be refused with an error message while the store is unreadable
- **AND** the raw stored content SHALL remain unchanged

#### Scenario: User discards the unreadable script store
- **WHEN** the whole script store is unreadable and the user chooses to discard it and confirms the warning
- **THEN** the script list SHALL start empty and saving SHALL be possible again
- **AND** the backup copy SHALL be kept

#### Scenario: Headless run with an unreadable script store
- **WHEN** a headless script run looks up a script by name and the whole script store is unreadable
- **THEN** the run SHALL fail with a message that the script store could not be read, not that the script was not found
- **AND** the process SHALL exit with a non-zero status
