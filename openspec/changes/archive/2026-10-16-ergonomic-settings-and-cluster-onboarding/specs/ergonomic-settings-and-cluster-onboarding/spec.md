# ergonomic-settings-and-cluster-onboarding Specification Delta

## Purpose

Provides an ergonomically constrained settings view with cluster capability badges and clear backup distinctions, combined with a streamlined cluster configuration dialog featuring file pickers, segmented client-authentication modes, password visibility toggles, and live connection testing.

## ADDED Requirements

### Requirement: Constrained Settings View Layout and Clear Configuration Scope

The `SettingsView` SHALL constrain its content to an ergonomic maximum desktop reading width (max width 960 px, horizontally centered), arrange numeric settings in a multi-column row, and visually distinguish global application configuration backup/restore from cluster ZIP export/import.

#### Scenario: Displaying constrained settings layout
- **WHEN** the user opens `SettingsView` on a desktop display wider than 960 px
- **THEN** the settings form content SHALL be centered with a maximum width constraint of 960 px
- **AND** the numeric fields for max script runs and max concurrent lag queries SHALL be rendered in a side-by-side row

#### Scenario: Distinguishing configuration backup from cluster export
- **WHEN** viewing the configuration management sections in `SettingsView`
- **THEN** the global configuration section SHALL explicitly indicate that it exports or imports the complete application settings state
- **AND** the cluster configuration section SHALL indicate that it exports or imports selected cluster profiles and certificates as a ZIP bundle

---

### Requirement: Cluster List Security Protocol and Schema Registry Badges

Each item in the cluster configuration list in `SettingsView` SHALL render informative visual badges indicating its security protocol (`PLAINTEXT`, `SSL`, `SASL_PLAINTEXT`, `SASL_SSL`) and whether a Schema Registry URL is configured.

#### Scenario: Cluster item displays protocol and Schema Registry indicators
- **WHEN** a cluster profile configured with `SASL_SSL` and a Schema Registry URL is rendered in `SettingsView`
- **THEN** the cluster tile SHALL display a `SASL_SSL` badge
- **AND** a badge or icon indicating Schema Registry is active

---

### Requirement: Guided SSL Authentication Mode Selector and File Pickers in Cluster Dialog

The `ClusterConfigDialog` SHALL allow users to select their SSL client authentication method (`None`, `Keystore (PKCS12 / JKS)`, or `PEM Certificate & Key`) so only the relevant certificate fields are displayed, and every file path field (Truststore, Keystore, PEM Certificate, PEM Key, Kerberos Keytab, Kerberos Config) SHALL include a native file picker action button.

#### Scenario: Switching SSL client authentication mode hides irrelevant fields
- **WHEN** the user selects `SSL` or `SASL_SSL` in `ClusterConfigDialog`
- **AND** selects `Keystore (PKCS12 / JKS)` as the client authentication mode
- **THEN** the Keystore location and password fields SHALL be displayed
- **AND** the PEM Certificate, Private Key, and PEM Key Password fields SHALL be hidden

#### Scenario: Selecting None for SSL client authentication mode
- **WHEN** the user selects `None` as the client authentication mode
- **THEN** neither Keystore nor PEM client certificate fields SHALL be displayed
- **AND** only the server Truststore location and password fields SHALL be displayed

#### Scenario: Selecting a certificate file via FilePicker
- **WHEN** the user clicks the folder action button on any file path input
- **THEN** a native file picker dialog SHALL open allowing the user to select a file
- **AND** upon file selection the chosen file path SHALL populate into the corresponding text input field

---

### Requirement: Password Visibility Toggles on Sensitive Fields

All password and secret inputs in `ClusterConfigDialog` (Truststore password, Keystore password, PEM key password, SASL password, Schema Registry password) SHALL provide an interactive toggle to switch between obscured and visible plain text.

#### Scenario: Toggling password visibility
- **WHEN** a user enters text into a password field in `ClusterConfigDialog`
- **THEN** the text SHALL be obscured by default
- **AND** clicking the visibility icon button SHALL toggle `obscureText` to false to show the entered characters

---

### Requirement: Progressive Disclosure for Schema Registry Credentials

The `ClusterConfigDialog` SHALL conceal the Schema Registry username and password inputs unless a Schema Registry URL has been entered or the user explicitly expands an optional credentials disclosure section.

#### Scenario: Concealing Schema Registry credentials when URL is empty
- **WHEN** the `Schema Registry URL` field in `ClusterConfigDialog` is empty
- **THEN** the Schema Registry username and password fields SHALL NOT occupy primary form space

#### Scenario: Revealing Schema Registry credentials when URL is populated
- **WHEN** the user enters a non-empty `Schema Registry URL`
- **THEN** the optional Schema Registry username and password fields SHALL be revealed or expandable

---

### Requirement: Live Broker Connection Test in Cluster Configuration Dialog

The `ClusterConfigDialog` SHALL provide a "Test Connection" button in its footer that validates connectivity to the broker using the currently entered configuration parameters before saving, displaying immediate visual progress and a success or error message.

#### Scenario: Successful connection test
- **WHEN** the user enters valid broker credentials and clicks "Test Connection"
- **THEN** the dialog SHALL show a loading indicator while testing
- **AND** upon successful connection SHALL display a confirmation message indicating success

#### Scenario: Failed connection test
- **WHEN** the user enters unreachable broker parameters or invalid credentials and clicks "Test Connection"
- **THEN** the dialog SHALL display the failure reason returned by the validation check without closing the dialog or saving the profile
