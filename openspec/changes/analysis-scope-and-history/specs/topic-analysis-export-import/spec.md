## MODIFIED Requirements

### Requirement: Export an analysis report to a portable file

The system SHALL allow a user to export the currently available analysis report to a single self-contained file in a portable format. The exported file SHALL contain the complete report — summary statistics, hourly distribution, hourly production timeline with scan moment and coverage start, per-partition statistics, key frequencies, content-type distribution, per-field frequencies (including nested field paths) with their top values, the value filter result when a filter was active, duplicate message detection metrics and top occurrences, the analysis scope summary, and the analysis limits with their reached state — together with provenance metadata (the source cluster name and the export timestamp) and a stable format identifier with a version number. The user SHALL be able to choose the destination location through the standard save-file dialog, and SHALL receive clear success or failure feedback.

#### Scenario: Export a finished report

- **WHEN** a complete analysis report is available in the topic analysis view and the user activates export
- **THEN** the system SHALL present a save-file dialog
- **AND** on confirmation, write a single file containing the full report plus the source cluster name, export timestamp, and a format identifier with a version number
- **AND** confirm the export to the user

#### Scenario: Export a partial (cancelled) report

- **WHEN** the available report is a partial result (the scan was cancelled before completing) and the user activates export
- **THEN** the system SHALL export that partial report using the same file format and provenance metadata
- **AND** the imported result SHALL reflect that it is a partial report

#### Scenario: No report available to export

- **WHEN** no analysis report is currently available in the view
- **THEN** the export action SHALL be unavailable to the user

#### Scenario: Export and re-import a filtered report with timeline

- **WHEN** the user exports a report produced with the value filter `status` = `FAILED` and imports the file again
- **THEN** the imported report SHALL show the same recent hours view, daily distribution, coverage indication and filter matches section as before the export
- **AND** the recent hours window SHALL end at the scan moment stored in the file

#### Scenario: Export and re-import report with duplicate detection

- **WHEN** the user exports an analysis report that includes duplicate message analysis and imports it
- **THEN** the imported report SHALL restore duplicate metrics and the top duplicated messages list exactly as analyzed

#### Scenario: Export and re-import scope and limits

- **WHEN** the user exports a report of the newest 10,000 messages of partitions 0 and 3 whose field limit was reached, and imports the file again
- **THEN** the imported report SHALL show the same scope summary, the same limits with the field limit marked as reached, and the same duplicate estimate label as before the export

### Requirement: Previous Format Version Remains Importable

After the format version is raised for newer analysis features, files written in previous format versions SHALL still be imported. Sections that the older file does not contain SHALL be shown as not available instead of as zero values.

#### Scenario: Importing a previous-version file

- **WHEN** the user imports a file written in the previous format version
- **THEN** the report SHALL render all sections contained in the file
- **AND** the recent hours view and the daily distribution SHALL show a "not available for this report" notice
- **AND** no filter matches section SHALL be shown

#### Scenario: Importing report without duplicate analysis data

- **WHEN** the user imports an analysis report that does not contain duplicate detection metrics
- **THEN** the duplicate analysis section SHALL display a notice that duplicate detection was not performed or is unavailable for this report
- **AND** other report metrics SHALL render normally

#### Scenario: Comparing with a previous-version file

- **WHEN** the user compares a current report with an imported previous-version file
- **THEN** the comparison SHALL work as before for all metrics both files contain

#### Scenario: Importing a file without scope and limits

- **WHEN** the user imports a file written before scope and limits were recorded
- **THEN** the scope summary SHALL show "scope not recorded" and the limits section SHALL show the "not available for this report" notice
- **AND** the report SHALL NOT be presented as a full scan merely because no scope is recorded

## ADDED Requirements

### Requirement: Automatic Local Report History

When a live analysis completes without error, the system SHALL save its report automatically in the application's local data directory, grouped by cluster and topic, using the same file format as the export. Per cluster and topic only the newest N saved reports SHALL be kept; N SHALL be a setting with default 10, and 0 SHALL turn automatic saving off.

#### Scenario: Completed scan is saved

- **WHEN** a live analysis of topic `orders` on cluster `prod` completes without error
- **THEN** its report SHALL be saved to the local history of `prod` / `orders` without any dialog

#### Scenario: Cancelled or failed scan is not saved

- **WHEN** a live analysis is cancelled or ends with an error
- **THEN** no report SHALL be added to the history

#### Scenario: Count-based cleanup

- **WHEN** 10 reports are kept for `prod` / `orders`, the setting is 10 and an 11th analysis completes
- **THEN** the oldest saved report of `prod` / `orders` SHALL be deleted
- **AND** saved reports of other topics or clusters SHALL NOT be touched

#### Scenario: History turned off

- **WHEN** the setting is 0 and an analysis completes
- **THEN** no report SHALL be saved
- **AND** existing saved reports SHALL stay until deleted by the user

#### Scenario: Names with special characters

- **WHEN** the cluster or topic name contains characters such as `/`, `..` or `:`
- **THEN** the report SHALL be saved inside the history directory and nowhere else
- **AND** two different names SHALL NOT share one history

#### Scenario: Saving fails

- **WHEN** the report cannot be written to the history
- **THEN** the displayed report SHALL stay unchanged
- **AND** the user SHALL see a non-blocking localized message that the report was not saved to the history

### Requirement: Saved Reports Offered In Import

The import action SHALL offer the saved reports of the current cluster and topic, newest first, each labelled with its scan moment, scope summary and message count, next to importing from a file. Opening a saved report SHALL behave like importing that file.

#### Scenario: Opening a saved report

- **WHEN** the user opens the import menu in the analysis of `orders` on `prod` and selects a saved report
- **THEN** that report SHALL be displayed with the imported indicator, its cluster name and its scan moment

#### Scenario: No saved reports

- **WHEN** no report is saved for the current cluster and topic
- **THEN** the import menu SHALL state that no saved reports exist and still offer importing from a file

#### Scenario: Unreadable saved report

- **WHEN** a saved report file cannot be read or is not a valid report
- **THEN** it SHALL NOT be offered as a report
- **AND** the menu SHALL state how many saved reports could not be read

#### Scenario: History directory unavailable

- **WHEN** the local history cannot be listed
- **THEN** the menu SHALL show a localized error instead of "no saved reports" and still offer importing from a file

### Requirement: Deleting Saved Reports

The settings SHALL offer an action that deletes all saved analysis reports after a confirmation, and SHALL report success or failure.

#### Scenario: Deleting all saved reports

- **WHEN** the user confirms deleting saved analysis reports in the settings
- **THEN** every saved analysis report of every cluster and topic SHALL be deleted
- **AND** the user SHALL see a confirmation

#### Scenario: Deletion fails

- **WHEN** a saved report cannot be deleted
- **THEN** the user SHALL see a localized error naming that not all saved reports were deleted
