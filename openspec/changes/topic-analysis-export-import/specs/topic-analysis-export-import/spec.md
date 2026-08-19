<!-- markdownlint-disable MD041 -->
## Purpose

Lets a user persist the result of a topic content analysis as a portable file, re-open that file later to view the full dashboard without re-running the scan, and share the file with another user or instance.

## ADDED Requirements

### Requirement: Export an analysis report to a portable file

The system SHALL allow a user to export the currently available analysis report to a single self-contained file in a portable format. The exported file SHALL contain the complete report — summary statistics, hourly distribution, per-partition statistics, key frequencies, content-type distribution, and per-field frequencies with their top values — together with provenance metadata (the source cluster name and the export timestamp) and a stable format identifier with a version number. The user SHALL be able to choose the destination location through the standard save-file dialog, and SHALL receive clear success or failure feedback.

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

### Requirement: Import and view a report without re-running the scan

The system SHALL allow a user to import a previously exported analysis report file and render the full analysis dashboard from it, without connecting to a Kafka cluster or re-running any scan. A valid report SHALL be importable and viewable even if its source topic no longer exists or is unreachable from the current environment. Importing a new report SHALL replace the report currently displayed in the view.

#### Scenario: Import a valid report file

- **WHEN** the user selects a valid, supported analysis report file through the standard open-file dialog
- **THEN** the system SHALL deserialize the report and render the full analysis dashboard (summary statistics, hourly distribution, per-partition statistics, key frequencies, content-type distribution, and per-field frequencies with top values)
- **AND** SHALL NOT require an active cluster connection or attempt to re-scan the topic

#### Scenario: Import a report whose topic is unreachable

- **WHEN** the imported report references a topic that is not reachable from any currently configured cluster
- **THEN** the system SHALL still render the full report for viewing
- **AND** SHALL NOT fail because the topic cannot be resolved

#### Scenario: Re-import replaces the displayed report

- **WHEN** a report is currently displayed and the user imports a different report file
- **THEN** the newly imported report SHALL replace the previously displayed report and become the report available for export

### Requirement: Distinguish imported reports from live reports

The system SHALL make it visually clear whether the displayed report was imported from a file or computed by a scan performed in the current session. For an imported report, the view SHALL present the provenance recorded in the file (source cluster name and export timestamp).

#### Scenario: Imported report is labelled as imported

- **WHEN** the displayed report was imported from a file
- **THEN** the view SHALL show a clear "imported" indicator together with the source cluster name and the export timestamp recorded in the file

#### Scenario: Live report is not labelled as imported

- **WHEN** the displayed report was produced by a scan in the current session
- **THEN** the view SHALL NOT show the "imported" indicator
- **AND** SHALL present it as the result of the current scan

### Requirement: Reject invalid or incompatible import files gracefully

The system SHALL validate the structure and the format version of an import file before rendering, and SHALL reject a file that is malformed, truncated, not a recognized analysis report, or uses an unsupported format version. Every rejection SHALL surface a clear, localized error message to the user and SHALL NOT crash the application or leave a partially rendered or corrupted report.

#### Scenario: Malformed or truncated file

- **WHEN** the user selects a file that cannot be parsed as a complete, well-formed analysis report
- **THEN** the system SHALL present a clear error message
- **AND** SHALL NOT render a report from that file

#### Scenario: Unrecognized file type

- **WHEN** the user selects a file that does not carry the expected analysis-report format identifier
- **THEN** the system SHALL present a clear "not a valid analysis report file" error message

#### Scenario: Unsupported format version

- **WHEN** the user selects a file whose format version is not supported by the current version of the application
- **THEN** the system SHALL present a clear message that the file is not compatible, identifying the version mismatch

#### Scenario: Supported older file still imports

- **WHEN** the user selects a file whose format version is supported by the current application
- **THEN** the system SHALL import and render the report successfully

### Requirement: Portable sharing without cluster access

The exported file SHALL be a single self-contained artifact that a colleague can import into their own instance of the application and view the complete report, without needing access to the original Kafka cluster or the original topic, and without any network transfer of the data beyond the file itself.

#### Scenario: Colleague imports a shared file

- **WHEN** a user opens an analysis report file received from a colleague in their own application instance
- **THEN** the full analysis dashboard SHALL render from the file alone
- **AND** no connection to the original cluster SHALL be required to view the report

### Requirement: Localize new export/import user-facing text

All user-facing text introduced by this capability — action labels, the imported-report indicator, the source provenance labels, and all success and error messages — SHALL be localized through the application's localization system for each supported language.

#### Scenario: Application language is German

- **WHEN** the application language is set to German and the user performs an export or an import
- **THEN** all new labels, indicators, and messages for the export/import flow SHALL be displayed in German
