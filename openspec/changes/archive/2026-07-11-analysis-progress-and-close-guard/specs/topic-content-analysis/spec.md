# topic-content-analysis Delta

## MODIFIED Requirements

### Requirement: Analysis Scan Progress and Cancellation

The system SHALL provide real-time visual progress feedback during scanning, including a remaining time estimate, and allow the user to cancel or pause an ongoing analysis scan at any time.

#### Scenario: Real-time scan progress feedback

- **WHEN** an analysis scan is actively running
- **THEN** the system SHALL display the number of messages scanned out of total messages to scan, the percentage progress, the current throughput in messages per second, and an estimated remaining time with live updates

#### Scenario: Estimated remaining time display

- **WHEN** an analysis scan is actively running and a total message count is known
- **THEN** the system SHALL compute and display an estimated remaining time based on the current scan throughput and the number of messages remaining to scan
- **AND** the estimate SHALL update in real time as the scan progresses
- **AND** the estimate SHALL be displayed in a human-readable format (e.g. "~45 s" for under one minute, "~3 m" for minutes)

#### Scenario: Indeterminate remaining time when total is unknown

- **WHEN** an analysis scan is actively running but the total number of messages to scan is not yet known
- **THEN** the system SHALL display the current throughput in messages per second without a specific remaining time estimate
- **AND** the progress bar SHALL display in indeterminate (indeterminate sweep) mode

#### Scenario: User cancels an ongoing scan

- **WHEN** the user presses the cancel/stop button while a scan is in progress
- **THEN** the system SHALL immediately halt consumer scanning and display the partial analysis results aggregated up to the point of cancellation
