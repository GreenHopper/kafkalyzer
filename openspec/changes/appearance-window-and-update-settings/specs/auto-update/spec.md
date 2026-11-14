# Spec Delta

## MODIFIED Requirements

### Requirement: Download and Progress Tracking
The system SHALL support downloading available update packages with real-time progress feedback. The user SHALL be able to cancel a running download from the update dialog; a cancelled download SHALL NOT be applied, neither at once nor on the next start, unless the user starts the download again and confirms the restart.

#### Scenario: User initiates update download
- **WHEN** the user triggers the download in the update dialog
- **THEN** the system streams the download progress from 0% to 100% and updates the progress indicator accordingly

#### Scenario: Progress is shown while the transfer runs
- **WHEN** half of the update package has been transferred
- **THEN** the progress indicator SHALL show a value between 0% and 100%, not 0% until the transfer has finished

#### Scenario: User cancels a running download
- **WHEN** the download is running and the user clicks "Cancel" in the update dialog
- **THEN** the dialog SHALL close, a message SHALL confirm that the update will not be installed
- **AND** the system SHALL NOT offer "Restart Now" or apply the update for this download

#### Scenario: Cancelled package is not applied on the next start
- **WHEN** a cancelled download finished in the background and the user restarts the application
- **THEN** the application SHALL start in its current version without applying the downloaded package

#### Scenario: New download while a cancelled transfer is still running
- **WHEN** the user starts the download again while a cancelled transfer has not yet finished
- **THEN** the dialog SHALL show the progress of the running transfer instead of starting a second one

#### Scenario: Download fails
- **WHEN** the download fails with a network or service error
- **THEN** the dialog SHALL show the error with a retry action and SHALL NOT offer "Restart Now"

---

### Requirement: Automated Startup Update Check
The system SHALL automatically check for available updates in the background after application startup without blocking UI responsiveness or startup workflows. In installations that cannot update themselves, the check SHALL look up the latest published release instead. Debug builds and builds whose own version is unknown SHALL NOT report a newer version from this check.

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

#### Scenario: Newer release for an installation without self-update
- **WHEN** the application runs from a package that cannot update itself (for example a deb, tar or snap build) and the latest published release is newer than the running version
- **THEN** the system SHALL display the same non-intrusive notification naming the new version, with an action that opens the update dialog

#### Scenario: Running version is unknown
- **WHEN** the running version cannot be determined
- **THEN** the background check SHALL complete without a notification

---

### Requirement: Environment-Aware Update Capability
The system SHALL recognize environments that cannot apply in-place updates (such as unpackaged debug builds or Linux desktop environments running outside an AppImage container) and provide manual upgrade alternatives. In such environments the update dialog SHALL look up the latest published release with a read-only request that needs no credentials and report whether it is newer than the running version.

#### Scenario: User triggers update check in unpackaged or dev build
- **WHEN** the user manually checks for updates in an unpackaged build or non-AppImage Linux environment
- **THEN** the update dialog explains that automatic updates are available only in packaged installations
- **AND** provides a direct link or action to open the latest GitHub Releases page in the system browser

#### Scenario: Newer release available for manual installation
- **WHEN** the user checks for updates in an environment without in-place updates and the latest release is newer than the running version
- **THEN** the dialog SHALL show "version X available", the release notes when present, and an action that opens that release's page in the system browser
- **AND** the dialog SHALL NOT offer a download or restart action

#### Scenario: Manual installation is up to date
- **WHEN** the latest release is not newer than the running version
- **THEN** the dialog SHALL state that the running version is the latest

#### Scenario: Release lookup fails
- **WHEN** the release lookup fails because of a network error, an HTTP error, a rate limit or an unreadable response
- **THEN** the dialog SHALL show the failure with a retry action and the link to the releases page
- **AND** SHALL NOT state that the application is up to date

#### Scenario: Running version unknown in a manual installation
- **WHEN** the running version cannot be determined and the latest release is v1.4.0
- **THEN** the dialog SHALL show v1.4.0 as the latest release, state that the running version is unknown, and SHALL NOT claim that an update is or is not available
