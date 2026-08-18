## ADDED Requirements

### Requirement: Velopack Initialization & Configuration
The system SHALL initialize the Velopack auto-update bridge at application startup, configuring `https://github.com/Protoss78/kafkalyzer` as the update repository source.

#### Scenario: Successful initialization on startup
- **WHEN** the application starts up
- **THEN** `initializeVelopack` is called with the repository URL before UI rendering or non-blockingly during initialization

#### Scenario: Initialization in development / unpackaged environment
- **WHEN** the application starts up in a debug or unpackaged build where Velopack native bindings are inactive
- **THEN** the system catches any initialization errors, logs them using the structured logger, and allows normal application execution without crashing

---

### Requirement: Update Availability Check
The system SHALL support querying whether a new release is available from GitHub Releases.

#### Scenario: Update is available
- **WHEN** the system checks for updates and a newer release version exists
- **THEN** the system identifies that an update is available and retrieves release metadata including version and release notes

#### Scenario: App is up to date
- **WHEN** the system checks for updates and no newer release version exists
- **THEN** the system indicates that the application is running the latest version

---

### Requirement: Download and Progress Tracking
The system SHALL support downloading available update packages with real-time progress feedback.

#### Scenario: User initiates update download
- **WHEN** the user triggers the download in the update dialog
- **THEN** the system streams the download progress from 0% to 100% and updates the progress indicator accordingly

---

### Requirement: Apply Update and Restart
The system SHALL apply the downloaded update and restart the application upon user confirmation.

#### Scenario: User restarts application after download
- **WHEN** the download reaches 100% and the user clicks "Restart Now"
- **THEN** the system invokes Velopack's `updateAndRestart()` to apply the update and relaunch the updated application

---

### Requirement: Settings View Update Check
The system SHALL provide a manual update check trigger and status display in the Settings view.

#### Scenario: User manually checks for updates from Settings
- **WHEN** the user clicks "Check for Updates" in the Settings view
- **THEN** the system queries update status and presents the `UpdateDialog` with the result (up-to-date message or available update details with download option)
