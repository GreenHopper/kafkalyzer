# Spec Delta

## MODIFIED Requirements

### Requirement: Derived Script Output Path
The system SHALL automatically save script execution outputs inside a subdirectory named after the script within the settings' default directory. Both the script subdirectory and the run directory SHALL be built from the sanitised script name, which contains no path separators, reserved file-name characters, control characters, `.` or `..` segments, or trailing dots and spaces, so that run output never leaves the script's output folder.

#### Scenario: User executes a script
- **WHEN** user executes a script named "My Test Script"
- **THEN** script run files are created in the folder "[general_default_output_dir]/My_Test_Script/[run_id]"

#### Scenario: Script name contains path elements
- **WHEN** user executes a script named "../../reports/x"
- **THEN** the script subdirectory and the run directory SHALL both be single directories below "[general_default_output_dir]"
- **AND** no file or directory SHALL be created outside "[general_default_output_dir]"

#### Scenario: Script name consists only of dots
- **WHEN** user executes a script named ".."
- **THEN** run files SHALL be created in a subdirectory of "[general_default_output_dir]" with a non-empty name other than "." or ".."
