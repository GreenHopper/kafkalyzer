## MODIFIED Requirements

### Requirement: Velopack Initialization & Configuration
The system SHALL initialize the Velopack auto-update bridge at application startup, configuring `https://github.com/GreenHopper/kafkalyzer` as the update repository source using an `AutoSource` provider capable of querying the GitHub Releases API.

#### Scenario: Successful initialization on startup
- **WHEN** the application starts up
- **THEN** `initializeVelopack` is called with the GitHub repository URL using `AutoSource` before UI rendering or non-blockingly during initialization

#### Scenario: Initialization in development / unpackaged environment
- **WHEN** the application starts up in a debug or unpackaged build where Velopack native bindings are inactive
- **THEN** the system catches any initialization errors, logs them using the structured logger, and allows normal application execution without crashing

---

### Requirement: Update Availability Check
The system SHALL support querying whether a new release is available from GitHub Releases and SHALL explicitly distinguish between a verified up-to-date state, an available update, and a check failure.

#### Scenario: Update is available
- **WHEN** the system checks for updates and a newer release version exists
- **THEN** the system identifies that an update is available and retrieves release metadata including version and release notes

#### Scenario: App is verified up to date
- **WHEN** the system successfully contacts the update source and no newer release version exists
- **THEN** the system indicates that the application is running the latest version

#### Scenario: Update check fails due to network or service error
- **WHEN** the system attempts to check for updates but encounters a network failure, HTTP error, rate limit, or source resolution failure
- **THEN** the system surfaces the failure to the caller and SHALL NOT indicate that the application is up to date

---

## ADDED Requirements

### Requirement: Automated Startup Update Check
The system SHALL automatically check for available updates in the background after application startup without blocking UI responsiveness or startup workflows.

#### Scenario: Background check discovers a new release
- **WHEN** the application finishes launching and completes the background update check
- **AND** a newer release is found
- **THEN** the system displays a non-intrusive notification (e.g. snackbar or banner) informing the user of the new version with an action button to open the update dialog

#### Scenario: Background check finds no update
- **WHEN** the background update check completes and no newer release exists
- **THEN** the check completes silently without displaying any popup, dialog, or notification

#### Scenario: Background check encounters an error
- **WHEN** the background update check encounters a network or service failure
- **THEN** the error is logged and suppressed from disrupting the user's initial startup workflow

---

### Requirement: Environment-Aware Update Capability
The system SHALL recognize environments that cannot apply in-place updates (such as unpackaged debug builds or Linux desktop environments running outside an AppImage container) and provide manual upgrade alternatives.

#### Scenario: User triggers update check in unpackaged or dev build
- **WHEN** the user manually checks for updates in an unpackaged build or non-AppImage Linux environment
- **THEN** the update dialog explains that automatic updates are available only in packaged installations
- **AND** provides a direct link or action to open the latest GitHub Releases page in the system browser
