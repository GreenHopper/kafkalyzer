# app-version-display Specification

## Purpose
TBD - created by archiving change show-app-version. Update Purpose after archive.
## Requirements
### Requirement: Dynamic Application Version Display
The system SHALL display the application version dynamically read from the `pubspec.yaml` file within the UI, ensuring that the version shown accurately reflects the current build without relying on manual compilation flags.

#### Scenario: User checks the application version in the settings view
- **WHEN** the user navigates to the Settings view (or views any UI element showing the version)
- **THEN** the system displays the correct version string corresponding to the `version:` field from `pubspec.yaml`

#### Scenario: Application fails to read the version natively
- **WHEN** the system initializes and encounters an error reading the native package information (e.g., due to a platform-specific issue)
- **THEN** the system gracefully falls back to displaying a default fallback version (like 'DEV' or the `APP_VERSION` environment variable) without disrupting the application launch or usage

### Requirement: About Dialog
Settings SHALL offer an "About Kafkalyzer" action that opens a dialog with the application version (same source as
the version display), the read-only notice, a link to the source repository, the storage locations (application
log folder, settings and data folder, default output folder) and access to the open-source licences of all bundled
packages.

#### Scenario: User opens the About dialog
- **WHEN** the user activates "About Kafkalyzer" in Settings
- **THEN** the dialog shows the version, the repository link, the three storage locations and a "View licences" action

#### Scenario: User views licences
- **WHEN** the user activates "View licences" in the About dialog
- **THEN** the list of bundled packages with their licence texts is shown

#### Scenario: User opens the repository link
- **WHEN** the user activates the repository link
- **THEN** the repository page opens in the default browser

#### Scenario: Link or storage location unavailable
- **WHEN** the browser cannot be launched or a storage location cannot be determined
- **THEN** an error message states that the link could not be opened, or the location is shown as "unknown"
- **AND** the dialog stays usable

