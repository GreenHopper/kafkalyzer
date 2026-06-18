## ADDED Requirements

### Requirement: Unified Output Directory Configuration
The system SHALL only allow configuration of the output directory through the general application settings.

#### Scenario: User changes output directory in Settings
- **WHEN** user selects a new directory in general settings
- **THEN** the application-wide output directory is updated to the selected folder

### Requirement: Automated Startup Directory Configuration
The system SHALL automatically initialize the default output directory on startup if not already configured.

#### Scenario: First application startup
- **WHEN** application is launched for the first time
- **THEN** the default output directory is automatically set to a platform-appropriate path inside the user's Documents folder

### Requirement: Derived Script Output Path
The system SHALL automatically save script execution outputs inside a subdirectory named after the script within the settings' default directory.

#### Scenario: User executes a script
- **WHEN** user executes a script named "My Test Script"
- **THEN** script run files are created in the folder "[general_default_output_dir]/My_Test_Script/[run_id]"
