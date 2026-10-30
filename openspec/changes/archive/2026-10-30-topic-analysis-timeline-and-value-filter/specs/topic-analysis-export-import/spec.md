# Spec Delta

## MODIFIED Requirements

### Requirement: Export an analysis report to a portable file

The system SHALL allow a user to export the currently available analysis report to a single self-contained file in a portable format. The exported file SHALL contain the complete report — summary statistics, hourly distribution, hourly production timeline with scan moment and coverage start, per-partition statistics, key frequencies, content-type distribution, per-field frequencies (including nested field paths) with their top values, and the value filter result when a filter was active — together with provenance metadata (the source cluster name and the export timestamp) and a stable format identifier with a version number. The user SHALL be able to choose the destination location through the standard save-file dialog, and SHALL receive clear success or failure feedback.

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

## ADDED Requirements

### Requirement: Previous Format Version Remains Importable

After the format version is raised for the timeline and filter data, files written in the previous format version SHALL still be imported. Sections that the older file does not contain SHALL be shown as not available instead of as zero values.

#### Scenario: Importing a previous-version file

- **WHEN** the user imports a file written in the previous format version
- **THEN** the report SHALL render all sections contained in the file
- **AND** the recent hours view and the daily distribution SHALL show a "not available for this report" notice
- **AND** no filter matches section SHALL be shown

#### Scenario: Comparing with a previous-version file

- **WHEN** the user compares a current report with an imported previous-version file
- **THEN** the comparison SHALL work as before for all metrics both files contain
