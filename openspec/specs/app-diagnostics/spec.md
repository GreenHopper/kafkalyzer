# app-diagnostics Specification

## Purpose

Makes failures of the desktop application visible and supportable: uncaught errors are captured and shown to the
user, startup failures get an error screen, Dart and Rust write one redacted rotating log, and the user can open the
log folder and copy a secret-free diagnostics report.

## Requirements

### Requirement: Uncaught Error Capture and Notification
The application SHALL capture every uncaught error from the UI framework, the platform dispatcher and asynchronous
code, write it to the application log at error level, and notify the user with a non-blocking message that offers
a details view. Identical errors (same type and message) SHALL produce at most one notification per 10 seconds,
while every occurrence is still logged.

#### Scenario: Uncaught asynchronous error is reported
- **WHEN** an asynchronous operation throws an error that no code catches while the main window is shown
- **THEN** the error is written to the application log with its type, message and stack trace
- **AND** a SnackBar informs the user that an unexpected error occurred and offers a "Details" action

#### Scenario: Framework error during build or layout is reported
- **WHEN** the UI framework reports an error that is not marked as silent
- **THEN** the error is logged and the user is notified as for an uncaught asynchronous error

#### Scenario: Repeated identical error is throttled
- **WHEN** the same error type with the same message occurs 50 times within 10 seconds
- **THEN** all 50 occurrences are written to the log
- **AND** the user sees exactly one notification for them

#### Scenario: Error occurs before the main window is ready
- **WHEN** an uncaught error occurs after startup succeeded but before the main window has been shown
- **THEN** the error is logged and the notification is shown once the main window is visible

### Requirement: Copyable Error Details
The details view of a reported error SHALL show the error type, message, time (UTC) and stack trace after redaction,
and SHALL offer a "Copy details" action that puts this text plus the application version and operating system on
the clipboard and confirms the copy.

#### Scenario: User copies error details
- **WHEN** the user opens "Details" on an error notification and activates "Copy details"
- **THEN** the clipboard contains the redacted error type, message, UTC time, stack trace, application version and
  operating system
- **AND** a confirmation message is shown

#### Scenario: Clipboard is unavailable
- **WHEN** writing to the clipboard fails
- **THEN** the user is told that the details could not be copied and the details stay visible for manual selection

### Requirement: Startup Failure Screen
If any startup step of the graphical application fails, the application SHALL show a localized error screen instead
of an empty or blank window. The screen SHALL state that Kafkalyzer could not start, show the redacted error,
and offer "Copy details" and "Open log folder".

#### Scenario: Native library fails to load
- **WHEN** the native analysis library cannot be loaded during startup
- **THEN** the startup failure screen is shown with the error message
- **AND** the error is written to the application log

#### Scenario: Log directory is also unavailable
- **WHEN** startup fails and the application log could not be opened
- **THEN** the startup failure screen is still shown
- **AND** the log location is shown as unavailable, and "Open log folder" reports that the folder cannot be opened
  instead of failing silently

### Requirement: Single Rotating Application Log
Dart and native (Rust, including the Kafka client library) log records SHALL be written to one active log file in a
`logs` folder inside the per-user application support directory. When the active file exceeds 5 MB it SHALL be
rotated, and at most 3 rotated files SHALL be kept. No log or debug file SHALL be written to the temporary directory.

#### Scenario: Dart and native records share one file
- **WHEN** the application logs a Dart warning and the native layer logs a warning during the same session
- **THEN** both records appear in the same active log file, each with a UTC timestamp, level and origin

#### Scenario: Log size is bounded
- **WHEN** logging continues after the active file has exceeded 5 MB
- **THEN** a new active file is started
- **AND** the log folder never contains more than the active file plus 3 rotated files

#### Scenario: Legacy temporary debug log is removed
- **WHEN** the application starts and the legacy native debug file exists in the temporary directory
- **THEN** that file is deleted
- **AND** creating a Kafka client configuration does not write to any file

#### Scenario: Native fatal error is recorded
- **WHEN** the native layer hits a fatal error that terminates the process
- **THEN** a single line with the error location and a truncated message is appended to the active log file before
  the process ends

#### Scenario: Log file cannot be written
- **WHEN** the log folder cannot be created or written
- **THEN** the application keeps running without file logging
- **AND** Settings → Diagnostics shows that file logging is unavailable

### Requirement: Log Redaction and Payload Exclusion
Log records SHALL NOT contain secrets or message payloads. Before a record is written, values of credential-like
keys (passwords, secrets, tokens, key passwords, basic-auth user info), authorization headers, private key blocks
and user info in URLs SHALL be masked, and each record SHALL be truncated to at most 4,096 characters. Message keys,
values and header values SHALL NOT be passed to the log.

#### Scenario: Credential in an error message is masked
- **WHEN** an error message containing `sasl.password=hunter2` or `Authorization: Bearer abc.def` is logged
- **THEN** the log file contains the key with a masked value and does not contain `hunter2` or `abc.def`

#### Scenario: Private key material is masked
- **WHEN** a record contains a PEM block whose header names a private key
- **THEN** the block is replaced by a placeholder in the log

#### Scenario: Oversized record is truncated
- **WHEN** a record longer than 4,096 characters is logged
- **THEN** the written record is cut to 4,096 characters and marked as truncated

#### Scenario: Partition hint does not log the message key
- **WHEN** a key-based partition lookup is performed for a search
- **THEN** the log records the topic and the computed partition but not the key

### Requirement: Headless Output Separation
When the application runs in headless script mode, standard output SHALL contain only the script report. Log
records SHALL go to the application log; warnings and errors SHALL also go to standard error. An uncaught error SHALL
be written to standard error and the log, and the process SHALL exit with code 3.

#### Scenario: JSON report stays parseable
- **WHEN** a script is run headless with JSON output and the native layer and Dart services emit log records
- **THEN** standard output contains exactly the JSON report and can be parsed as JSON

#### Scenario: Uncaught error in headless mode
- **WHEN** an uncaught error occurs while a headless script is running
- **THEN** the error is written to standard error and to the log
- **AND** the process exits with code 3

### Requirement: Open Log Folder
Settings SHALL contain a Diagnostics section with an "Open log folder" action that opens the log folder in the
operating system's file manager and selects the active log file where the platform supports it.

#### Scenario: User opens the log folder
- **WHEN** the user activates "Open log folder" in Settings → Diagnostics
- **THEN** the platform file manager opens the log folder

#### Scenario: Log folder cannot be opened
- **WHEN** the log folder does not exist or the file manager cannot be launched
- **THEN** an error message states that the log folder could not be opened and shows its path

### Requirement: Copy Diagnostics Report
Settings → Diagnostics SHALL offer "Copy diagnostics", which copies a plain-text report with the application version,
operating system and version, UI locale, log file path, a summary of the active cluster profile and the 20 most recent
redacted error records. The profile summary SHALL contain only the security protocol, SASL mechanism, TLS verification
state, Schema Registry configured (yes/no), truststore and keystore configured (yes/no) and the number of bootstrap
servers.

#### Scenario: Report with an active profile
- **WHEN** a cluster is connected and the user activates "Copy diagnostics"
- **THEN** the clipboard contains the report with the profile summary
- **AND** the report contains no password, token, user name, host name, profile name or file path of the profile
- **AND** a confirmation message is shown

#### Scenario: Report without an active profile
- **WHEN** no cluster is connected and the user activates "Copy diagnostics"
- **THEN** the profile summary states that no cluster is connected

#### Scenario: Unknown value in the report
- **WHEN** a report field cannot be determined (for example the OS version or the log path)
- **THEN** the field is shown as "unknown" and the rest of the report is still produced

#### Scenario: No recent errors
- **WHEN** no error has been recorded in the current session
- **THEN** the recent-errors part of the report states that there are none

### Requirement: Diagnostics Stay Local
Error capture, logging and diagnostics SHALL NOT send any data off the machine and SHALL NOT contact Kafka or the
Schema Registry. Data leaves the application only when the user copies it or opens the log folder.

#### Scenario: Diagnostics without network access
- **WHEN** the user copies diagnostics or error details while offline or while a cluster is unreachable
- **THEN** the action completes without any network request
