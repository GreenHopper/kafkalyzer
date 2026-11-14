# Spec Delta

## MODIFIED Requirements

### Requirement: Constrained Settings View Layout and Clear Configuration Scope

The `SettingsView` SHALL constrain its content to an ergonomic maximum desktop reading width (max width 960 px, horizontally centered), arrange numeric settings in a multi-column row, and visually distinguish global application configuration backup/restore from cluster ZIP export/import. It SHALL group its content into titled sections in this order: Appearance, General, Configuration, Cluster configuration, followed by the diagnostics and About sections.

#### Scenario: Displaying constrained settings layout
- **WHEN** the user opens `SettingsView` on a desktop display wider than 960 px
- **THEN** the settings form content SHALL be centered with a maximum width constraint of 960 px
- **AND** the numeric fields for max script runs and max concurrent lag queries SHALL be rendered in a side-by-side row

#### Scenario: Distinguishing configuration backup from cluster export
- **WHEN** viewing the configuration management sections in `SettingsView`
- **THEN** the global configuration section SHALL explicitly indicate that it exports or imports the complete application settings state
- **AND** the cluster configuration section SHALL indicate that it exports or imports selected cluster profiles and certificates as a ZIP bundle

#### Scenario: Section order
- **WHEN** the user opens `SettingsView`
- **THEN** the Appearance section with theme, language, text size and time display SHALL come first
- **AND** the General section SHALL follow it, before the Configuration section

## ADDED Requirements

### Requirement: Validated Numeric Settings
Every numeric field on the Settings page SHALL accept only whole numbers within its documented range. The helper text SHALL show the range and default. Invalid input SHALL show an inline error at the field and SHALL NOT be stored; the last valid value stays in effect. Ranges: max script run history 0–1,000 (default 30, 0 keeps all runs), max concurrent lag queries 1–20 (default 5), lag warning threshold 0–1,000,000,000,000 (default 0, off).

#### Scenario: Value above the range
- **WHEN** the user enters 50 into max concurrent lag queries
- **THEN** the field SHALL show an error naming the range 1–20
- **AND** the stored value SHALL stay unchanged

#### Scenario: Non-numeric input
- **WHEN** the user enters "abc" into the lag warning threshold
- **THEN** the field SHALL show an error and the stored value SHALL stay unchanged

#### Scenario: Valid value
- **WHEN** the user enters 10 into max concurrent lag queries
- **THEN** the value 10 SHALL be stored and used for the next lag refresh

### Requirement: Out-of-Range Stored Settings Fall Back to Defaults
A stored numeric setting that is missing, of the wrong type or outside its range, for example after a configuration import, SHALL be ignored wherever the application uses it, and the default SHALL be used. The Settings page SHALL show the value in effect. The stored value SHALL NOT be rewritten until the user enters a valid value.

#### Scenario: Imported configuration sets zero concurrent lag queries
- **WHEN** the stored max concurrent lag queries value is 0
- **THEN** the Consumer Lag view SHALL use 5 concurrent queries
- **AND** the Settings page SHALL show 5

### Requirement: Configurable Default Result Limit
The General section SHALL offer a default result limit, range 1–100,000, default 200. Opening a topic with default settings (for example by double-clicking it in the Explorer) SHALL stop after this many messages, and a new topic search configuration SHALL start with this limit. Saved searches and script steps SHALL keep their own stored limits.

#### Scenario: Open a topic with a changed default
- **WHEN** the default result limit is 1,000 and the user double-clicks a topic in the Explorer
- **THEN** the topic SHALL stream from the tail and stop after 1,000 messages

#### Scenario: Saved search keeps its limit
- **WHEN** the default result limit is 1,000 and the user applies a saved search stored with a limit of 50
- **THEN** the search configuration SHALL use 50

### Requirement: Reset Settings Section to Defaults
The Appearance and General sections SHALL each offer "Reset to defaults". After a confirmation it SHALL set every setting of that section to its default and apply it at once. It SHALL NOT change cluster profiles, secrets, scripts, script runs, saved searches, the saved window state or settings of other sections. Cancelling the confirmation SHALL change nothing.

#### Scenario: Reset the General section
- **WHEN** the user confirms "Reset to defaults" in the General section
- **THEN** the default result limit SHALL be 200, max script run history 30, max concurrent lag queries 5, the lag warning threshold 0, tab restoration on, and the output directory the default output directory
- **AND** the theme mode, language and cluster profiles SHALL be unchanged

#### Scenario: Reset the Appearance section
- **WHEN** the user confirms "Reset to defaults" in the Appearance section
- **THEN** the theme mode SHALL be System, the language System, the text size 100 % and the time display local time

#### Scenario: Cancel the reset
- **WHEN** the user opens the reset confirmation and cancels it
- **THEN** no setting SHALL change
