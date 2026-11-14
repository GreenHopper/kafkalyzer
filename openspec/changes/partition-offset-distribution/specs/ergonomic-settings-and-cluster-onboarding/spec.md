## MODIFIED Requirements

### Requirement: Validated Numeric Settings
Every numeric field on the Settings page SHALL accept only whole numbers within its documented range. The helper text SHALL show the range and default. Invalid input SHALL show an inline error at the field and SHALL NOT be stored; the last valid value stays in effect. Ranges: max script run history 0–1,000 (default 30, 0 keeps all runs), max concurrent lag queries 1–20 (default 5), lag warning threshold 0–1,000,000,000,000 (default 0, off), partition skew threshold 1–100 % (default 50, 100 never shows the hint).

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

#### Scenario: Partition skew threshold out of range
- **WHEN** the user enters 0 or 150 into the partition skew threshold
- **THEN** the field SHALL show an error naming the range 1–100
- **AND** the stored value SHALL stay unchanged

#### Scenario: Stored partition skew threshold out of range
- **WHEN** the stored partition skew threshold is 0, for example after a configuration import
- **THEN** the offset distribution SHALL use 50 %
- **AND** the Settings page SHALL show 50

### Requirement: Reset Settings Section to Defaults
The Appearance and General sections SHALL each offer "Reset to defaults". After a confirmation it SHALL set every setting of that section to its default and apply it at once. It SHALL NOT change cluster profiles, secrets, scripts, script runs, saved searches, the saved window state or settings of other sections. Cancelling the confirmation SHALL change nothing.

#### Scenario: Reset the General section
- **WHEN** the user confirms "Reset to defaults" in the General section
- **THEN** the default result limit SHALL be 200, max script run history 30, max concurrent lag queries 5, the lag warning threshold 0, the partition skew threshold 50 %, tab restoration on, and the output directory the default output directory
- **AND** the theme mode, language and cluster profiles SHALL be unchanged

#### Scenario: Reset the Appearance section
- **WHEN** the user confirms "Reset to defaults" in the Appearance section
- **THEN** the theme mode SHALL be System, the language System, the text size 100 % and the time display local time

#### Scenario: Cancel the reset
- **WHEN** the user opens the reset confirmation and cancels it
- **THEN** no setting SHALL change
