# Spec Delta

## MODIFIED Requirements

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

#### Scenario: Session contains only the tabs of its own cluster

- **WHEN** the user has tabs "orders" on cluster "A" and "payments" on cluster "B" open while "B" is the active cluster
- **AND** restarts the application and connects to cluster "B"
- **THEN** only the "payments" tab SHALL be restored
- **AND** connecting to cluster "A" SHALL restore only the "orders" tab

#### Scenario: Closing a tab of a non-active cluster updates that cluster's session

- **WHEN** cluster "B" is active and the user closes the last open tab of cluster "A"
- **THEN** the saved session of cluster "A" SHALL contain no tabs
- **AND** the saved session of cluster "B" SHALL be unchanged

#### Scenario: Tabs that cannot be restored are reported

- **WHEN** the saved session of a cluster contains topics "orders" and "legacy-events" and "legacy-events" is no longer in the topic list of that cluster (deleted or not visible to the account)
- **THEN** the "orders" tab SHALL be restored
- **AND** a message SHALL state that one tab could not be restored and SHALL name "legacy-events"
- **AND** after the message, the saved session SHALL contain only the restored tabs

#### Scenario: Disconnect keeps the session

- **WHEN** the user disconnects from a cluster with two open tabs and later connects to it again
- **THEN** the two tabs SHALL be restored
