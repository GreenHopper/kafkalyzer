# Spec Delta

## MODIFIED Requirements

### Requirement: Live Broker Connection Test in Cluster Configuration Dialog

The `ClusterConfigDialog` SHALL provide a "Test Connection" button in its footer that validates connectivity to the broker using the currently entered configuration parameters before saving, displaying immediate visual progress and then the staged connection diagnosis result: one row per stage with its state and, for failures, a localized hint and the raw error.

#### Scenario: Successful connection test
- **WHEN** the user enters valid broker credentials and clicks "Test Connection"
- **THEN** the dialog SHALL show a loading indicator while testing
- **AND** upon successful connection SHALL display a confirmation message indicating success
- **AND** SHALL list every stage with its state, including not applicable stages

#### Scenario: Failed connection test
- **WHEN** the user enters unreachable broker parameters or invalid credentials and clicks "Test Connection"
- **THEN** the dialog SHALL display the failure reason returned by the validation check without closing the dialog or saving the profile
- **AND** the failure SHALL be shown at the stage it was attributed to, with a localized hint and the raw error

#### Scenario: Failure that cannot be attributed
- **WHEN** the diagnosis reports "connection failed, stage unknown"
- **THEN** the dialog SHALL show that text with the raw error and SHALL NOT mark any single TLS, authentication or metadata stage as failed

#### Scenario: Test is not repeated while running
- **WHEN** a connection test is running
- **THEN** the "Test Connection" button SHALL be disabled until the result is shown

#### Scenario: Dialog closed during the test
- **WHEN** the user closes the dialog while a test is running
- **THEN** the late result SHALL be discarded without an error
