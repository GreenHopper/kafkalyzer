## ADDED Requirements

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
