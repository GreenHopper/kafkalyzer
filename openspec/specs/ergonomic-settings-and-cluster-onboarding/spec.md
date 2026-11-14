# ergonomic-settings-and-cluster-onboarding Specification

## Purpose

Provides an ergonomically constrained settings view with cluster capability badges and clear backup distinctions, combined with a streamlined cluster configuration dialog featuring file pickers, segmented client-authentication modes, password visibility toggles, and live connection testing.

## Requirements

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

### Requirement: TLS Verification Option in Cluster Configuration Dialog

When `SSL` or `SASL_SSL` is selected, the `ClusterConfigDialog` SHALL offer an explicit option to disable certificate
and hostname verification for this profile. The option SHALL be off for new profiles, SHALL show a localized warning
while on, and the dialog header SHALL show the insecure marker for a profile with verification disabled.

#### Scenario: New TLS profile keeps verification on
- **WHEN** the user creates a profile, selects `SASL_SSL` and saves without touching the verification option
- **THEN** the saved profile SHALL have verification enabled
- **AND** no insecure marker SHALL be shown for it

#### Scenario: Option hidden for protocols without TLS
- **WHEN** the user selects `PLAINTEXT` or `SASL_PLAINTEXT`
- **THEN** the verification option SHALL NOT be displayed

#### Scenario: User disables verification
- **WHEN** the user turns the option on
- **THEN** the dialog SHALL show a warning that certificate and hostname are no longer checked
- **AND** after saving, the profile SHALL be flagged insecure in the dialog header and in the cluster list

#### Scenario: User re-enables verification
- **WHEN** the user edits an insecure profile, turns the option off and saves
- **THEN** the profile SHALL have verification enabled and SHALL no longer be flagged insecure

#### Scenario: Connection test uses the entered setting
- **WHEN** the user clicks "Test Connection" with verification on against a broker whose certificate cannot be verified
- **THEN** the test SHALL fail and display the verification error without saving the profile

### Requirement: Insecure Badge in Cluster List

Each item in the cluster configuration list in `SettingsView` whose profile has verification disabled SHALL display an
"insecure" badge consisting of an icon and a localized label with a tooltip, in addition to the protocol and Schema
Registry badges.

#### Scenario: Insecure profile in the list
- **WHEN** a `SASL_SSL` profile with verification disabled is rendered in `SettingsView`
- **THEN** its tile SHALL display the `SASL_SSL` badge and the insecure badge

#### Scenario: Verified or undecided profile in the list
- **WHEN** a TLS profile with verification enabled or still undecided is rendered
- **THEN** its tile SHALL NOT display the insecure badge
