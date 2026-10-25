# Spec Delta

## ADDED Requirements

### Requirement: Tab Session State Persistence and Restoration

The system SHALL persistently store the list of open topic tabs and the active tab index per cluster across application restarts, and automatically restore the open tab workspace when the application connects to that cluster.

#### Scenario: Open tabs automatically restored upon cluster connection

- **WHEN** the user has three open topic tabs in the Explorer and closes the application
- **AND** later restarts the application and connects to the same cluster
- **THEN** the Explorer SHALL automatically reopen the three topic tabs with their respective topic configurations
- **AND** the active tab that was selected at shutdown SHALL be focused

#### Scenario: Active tab index preserved

- **WHEN** the user switches active focus to the second open tab and closes the application
- **THEN** upon restoration, the second tab SHALL be selected as the active tab in the Explorer tab bar

#### Scenario: User disables tab restoration in General Settings

- **WHEN** the user disables "Restore open tabs on startup" in General Settings
- **AND** restarts the application and connects to a cluster
- **THEN** no previous tabs SHALL be automatically reopened
- **AND** the Explorer view SHALL display the default empty onboarding state
