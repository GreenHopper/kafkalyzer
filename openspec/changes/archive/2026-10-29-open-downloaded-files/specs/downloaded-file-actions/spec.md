# Spec Delta

## Purpose

Enables desktop users to immediately open exported or downloaded files in their system default application or reveal their containing directory in the native file manager directly from export completion notifications.

## ADDED Requirements

### Requirement: Export Completion Affordance with Direct Open Actions
Upon successful completion of any file download or export operation, the system SHALL surface a completion notification containing explicit interactive affordances to directly open the saved file and to reveal its containing folder in the operating system file manager.

#### Scenario: Successful file export surfaces open actions
- **WHEN** a file export (such as Kafka messages, topic analysis reports, settings, or scripts) successfully saves a file to the chosen path
- **THEN** the system SHALL display a completion notification confirming the export
- **AND** the notification SHALL provide an "Open" action to open the file and a "Show in Folder" action to open the containing folder

#### Scenario: Notification dismissal without activating actions
- **WHEN** the export completion notification is displayed and the user dismisses it or lets it time out
- **THEN** no file or folder opening request SHALL be dispatched to the operating system

### Requirement: Open Downloaded File with Operating System Default Handler
When the user activates the action to open an exported file, the system SHALL request the host operating system to launch or open the target file using the system's registered default application for that file extension.

#### Scenario: User triggers open file action
- **WHEN** the user selects the "Open" action from an export completion notification
- **THEN** the system SHALL invoke the host operating system to launch the exported file in its default application

#### Scenario: Target file is missing or inaccessible when open is requested
- **WHEN** the user selects the "Open" action but the file at the exported path has been moved, renamed, or deleted
- **THEN** the system SHALL display a clear error notification indicating that the file could not be opened

### Requirement: Reveal Downloaded File in Desktop File Manager
When the user activates the action to show the file in its folder, the system SHALL open the containing directory in the host operating system's native file manager and highlight or select the exported file when supported by the host platform.

#### Scenario: User triggers show in folder action
- **WHEN** the user selects the "Show in Folder" action from an export completion notification
- **THEN** the system SHALL open the containing directory in the platform file manager (Finder on macOS, Explorer on Windows, or the desktop file manager on Linux)
- **AND** SHALL highlight or select the exported file on platforms supporting file selection

#### Scenario: Containing folder is inaccessible
- **WHEN** the user selects the "Show in Folder" action but the containing directory does not exist or cannot be accessed
- **THEN** the system SHALL display a clear error notification indicating that the folder could not be opened

### Requirement: Save Dialog Cancellation Handling
When a user initiates an export or download action but dismisses or cancels the destination file picker dialog without selecting a file path, the system SHALL NOT report a successful export and SHALL NOT display file or folder opening affordances.

#### Scenario: User cancels destination file selection dialog
- **WHEN** the file picker dialog for an export operation is dismissed or cancelled without selecting a path
- **THEN** the system SHALL NOT write any file
- **AND** the system SHALL NOT display a completion notification or offer open actions
