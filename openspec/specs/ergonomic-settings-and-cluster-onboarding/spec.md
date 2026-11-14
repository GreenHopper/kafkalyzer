# ergonomic-settings-and-cluster-onboarding Specification

## Purpose

Provides an ergonomically constrained settings view with cluster capability badges and clear backup distinctions, combined with a streamlined cluster configuration dialog featuring file pickers, segmented client-authentication modes, password visibility toggles, and live connection testing.

## Requirements

### Requirement: Constrained Settings View Layout and Clear Configuration Scope

The `SettingsView` SHALL constrain its content to an ergonomic maximum desktop reading width (max width 960 px, horizontally centered), arrange numeric settings in a multi-column row, and visually distinguish global application configuration backup/restore from cluster ZIP export/import. It SHALL group its content into titled sections in this order: Appearance, General, Configuration, Cluster configuration, followed by the diagnostics and About sections.

#### Scenario: Displaying constrained settings layout
- **WHEN** the user opens `SettingsView` on a desktop display wider than 960 px
- **THEN** the settings form content SHALL be centered with a maximum width constraint of 960 px
- **AND** the numeric fields for max script runs and max concurrent lag queries SHALL be rendered in a side-by-side row

#### Scenario: Distinguishing configuration backup from cluster export
- **WHEN** viewing the configuration management sections in `SettingsView`
- **THEN** the global configuration section SHALL explicitly indicate that it exports or imports the complete application settings state
- **AND** the cluster configuration section SHALL indicate that it exports or imports selected cluster profiles and certificates as a ZIP bundle

#### Scenario: Section order
- **WHEN** the user opens `SettingsView`
- **THEN** the Appearance section with theme, language, text size and time display SHALL come first
- **AND** the General section SHALL follow it, before the Configuration section

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

### Requirement: Validated Numeric Settings
Every numeric field on the Settings page SHALL accept only whole numbers within its documented range. The helper text SHALL show the range and default. Invalid input SHALL show an inline error at the field and SHALL NOT be stored; the last valid value stays in effect. Ranges: max script run history 0–1,000 (default 30, 0 keeps all runs), max concurrent lag queries 1–20 (default 5), lag warning threshold 0–1,000,000,000,000 (default 0, off).

#### Scenario: Value above the range
- **WHEN** the user enters 50 into max concurrent lag queries
- **THEN** the field SHALL show an error naming the range 1–20
- **AND** the stored value SHALL stay unchanged

#### Scenario: Non-numeric input
- **WHEN** the user enters "abc" into the lag warning threshold
- **THEN** the field SHALL show an error and the stored value SHALL stay unchanged

#### Scenario: Valid value
- **WHEN** the user enters 10 into max concurrent lag queries
- **THEN** the value 10 SHALL be stored and used for the next lag refresh

### Requirement: Out-of-Range Stored Settings Fall Back to Defaults
A stored numeric setting that is missing, of the wrong type or outside its range, for example after a configuration import, SHALL be ignored wherever the application uses it, and the default SHALL be used. The Settings page SHALL show the value in effect. The stored value SHALL NOT be rewritten until the user enters a valid value.

#### Scenario: Imported configuration sets zero concurrent lag queries
- **WHEN** the stored max concurrent lag queries value is 0
- **THEN** the Consumer Lag view SHALL use 5 concurrent queries
- **AND** the Settings page SHALL show 5

### Requirement: Configurable Default Result Limit
The General section SHALL offer a default result limit, range 1–100,000, default 200. Opening a topic with default settings (for example by double-clicking it in the Explorer) SHALL stop after this many messages, and a new topic search configuration SHALL start with this limit. Saved searches and script steps SHALL keep their own stored limits.

#### Scenario: Open a topic with a changed default
- **WHEN** the default result limit is 1,000 and the user double-clicks a topic in the Explorer
- **THEN** the topic SHALL stream from the tail and stop after 1,000 messages

#### Scenario: Saved search keeps its limit
- **WHEN** the default result limit is 1,000 and the user applies a saved search stored with a limit of 50
- **THEN** the search configuration SHALL use 50

### Requirement: Reset Settings Section to Defaults
The Appearance and General sections SHALL each offer "Reset to defaults". After a confirmation it SHALL set every setting of that section to its default and apply it at once. It SHALL NOT change cluster profiles, secrets, scripts, script runs, saved searches, the saved window state or settings of other sections. Cancelling the confirmation SHALL change nothing.

#### Scenario: Reset the General section
- **WHEN** the user confirms "Reset to defaults" in the General section
- **THEN** the default result limit SHALL be 200, max script run history 30, max concurrent lag queries 5, the lag warning threshold 0, tab restoration on, and the output directory the default output directory
- **AND** the theme mode, language and cluster profiles SHALL be unchanged

#### Scenario: Reset the Appearance section
- **WHEN** the user confirms "Reset to defaults" in the Appearance section
- **THEN** the theme mode SHALL be System, the language System, the text size 100 % and the time display local time

#### Scenario: Cancel the reset
- **WHEN** the user opens the reset confirmation and cancels it
- **THEN** no setting SHALL change

### Requirement: Environment Tag in Cluster Configuration Dialog

The `ClusterConfigDialog` SHALL let the user set an optional environment tag for a profile: a short label (free text, with the suggestions DEV, TEST, STAGE and PROD) and a colour from a fixed palette. Choosing PROD SHALL preselect the red palette colour. A label without an explicit colour SHALL use the neutral palette colour. Clearing the label SHALL remove the tag.

#### Scenario: Tagging a profile as production
- **WHEN** the user enters the label "PROD", keeps the preselected colour and saves the profile
- **THEN** the profile SHALL carry the environment label "PROD" with the red palette colour

#### Scenario: Removing a tag
- **WHEN** the user clears the environment label of a tagged profile and saves
- **THEN** the profile SHALL have no environment tag and no environment chip SHALL be shown for it

#### Scenario: Overlong label rejected
- **WHEN** the user enters an environment label longer than 16 characters
- **THEN** the dialog SHALL show a validation error and SHALL NOT save the profile

#### Scenario: Unknown stored colour
- **WHEN** a stored profile carries a colour value the palette does not know (for example from a newer version)
- **THEN** the chip SHALL be shown with the neutral palette colour and the stored value SHALL be kept unchanged on the next save unless the user picks a colour

### Requirement: Environment Tag Visible Wherever a Cluster Is Shown

A tagged profile SHALL show an environment chip with its label text and colour on the Explorer sidebar cluster tile, the Settings cluster tile, the cluster selection dropdowns, every open Explorer tab of that profile, and an Explorer header banner for the active cluster. The chip SHALL convey the environment by text, not by colour alone, and SHALL follow edits of the profile without reopening the tab.

#### Scenario: Production cluster in sidebar and tabs
- **WHEN** the user connects to profile "orders-prod" tagged "PROD" and opens two topic tabs
- **THEN** the sidebar tile of "orders-prod" SHALL show a "PROD" chip
- **AND** both tabs SHALL show a "PROD" chip next to the cluster name
- **AND** the Explorer header banner SHALL show "PROD" and the cluster name in the red palette colour

#### Scenario: Untagged cluster
- **WHEN** the active profile has no environment tag
- **THEN** no environment chip and no Explorer header banner SHALL be shown for it

#### Scenario: Tag changed while tabs are open
- **WHEN** the user changes the tag of a profile from "TEST" to "PROD" while tabs of that profile are open
- **THEN** the open tabs and the header banner SHALL show "PROD" after the dialog is saved

#### Scenario: Tag shown together with the insecure marker
- **WHEN** a profile is tagged "PROD" and has TLS verification disabled
- **THEN** its tiles and tabs SHALL show both the environment chip and the insecure marker

#### Scenario: Tagged cluster in a dropdown
- **WHEN** the user opens the cluster dropdown in the Consumer Lag view
- **THEN** each tagged profile entry SHALL show its environment chip next to the name

### Requirement: Filterable Cluster Lists

The Settings cluster list SHALL offer a text filter, and the Explorer sidebar cluster list SHALL offer the same filter when more than five profiles exist. The filter SHALL match case-insensitively against profile name, environment label and bootstrap servers. When no profile matches, the list SHALL say so instead of showing the "no clusters" empty state.

#### Scenario: Filtering by environment
- **WHEN** profiles "a-dev" (DEV), "a-prod" (PROD) and "b-prod" (PROD) exist and the user types "prod" into the filter
- **THEN** only "a-prod" and "b-prod" SHALL be listed

#### Scenario: No match
- **WHEN** the filter matches no profile
- **THEN** the list SHALL show a "no cluster matches the filter" message with an action to clear the filter

#### Scenario: Small list in the sidebar
- **WHEN** five or fewer profiles exist
- **THEN** the Explorer sidebar SHALL NOT show the cluster filter field

#### Scenario: Active cluster filtered out
- **WHEN** the filter hides the active cluster in the sidebar
- **THEN** the cluster SHALL stay connected and its topics SHALL stay visible below the list

### Requirement: Disconnect Action for the Active Cluster

The active cluster's tile in the Explorer sidebar SHALL offer a "Disconnect" action with tooltip and semantic label. Disconnecting SHALL close the tabs of that cluster, clear the active cluster and show the cluster selection state. Tabs of other clusters SHALL stay open. If a search or analysis of that cluster is running, the user SHALL confirm first.

#### Scenario: Disconnect without running operations
- **WHEN** the user clicks "Disconnect" on the active cluster and no search or analysis of that cluster is running
- **THEN** the cluster SHALL no longer be active and its tabs SHALL be closed without a confirmation dialog

#### Scenario: Disconnect with a running search
- **WHEN** a search of the active cluster is streaming and the user clicks "Disconnect"
- **THEN** a confirmation dialog SHALL state that a search or analysis is still running
- **AND** confirming SHALL stop the search, close the tabs and disconnect
- **AND** cancelling SHALL keep the connection, the tabs and the search unchanged

#### Scenario: Tabs of another cluster stay open
- **WHEN** a tab of cluster "A" is open, the user switched to cluster "B" and disconnects from "B"
- **THEN** the tab of cluster "A" SHALL stay open with its results

### Requirement: Bootstrap Server Validation Before Connecting

Every comma-separated bootstrap entry SHALL be a `host:port` pair: hostname, IPv4 address or bracketed IPv6 address, and a port from 1 to 65535. Surrounding whitespace and empty entries from trailing commas SHALL be ignored, but at least one entry SHALL exist. The dialog SHALL check this before saving or testing. A connect attempt with an invalid stored value SHALL fail before any broker is contacted.

#### Scenario: Valid list
- **WHEN** the user enters `broker-1:9092, 10.0.0.5:9093,[::1]:9094`
- **THEN** the dialog SHALL accept the value

#### Scenario: Missing port
- **WHEN** the user enters `broker-1:9092,broker-2` and clicks Save or Test Connection
- **THEN** the dialog SHALL show a validation error naming `broker-2` and stating that a port is required
- **AND** no connection test SHALL be started

#### Scenario: Typical typos
- **WHEN** the user enters `broker-1.9092`, `http://broker-1:9092`, `broker 1:9092` or `broker-1:99999`
- **THEN** the dialog SHALL show a validation error naming the invalid entry

#### Scenario: Stored profile with an invalid value
- **WHEN** the user connects to a stored profile whose bootstrap value contains an entry without a port
- **THEN** the connection SHALL fail without contacting any broker
- **AND** the error SHALL name the invalid entry and ask the user to edit the profile

### Requirement: Prefill a New Profile From a Kafka Client Properties File

The dialog for a new profile SHALL let the user pick a Kafka `client.properties` file and SHALL show a preview of its effect before applying it. Known connection, SASL, SSL and Schema Registry keys SHALL map to profile fields. Allowlisted client properties SHALL become additional properties. Every other key SHALL be listed with a reason and SHALL NOT be applied. The preview SHALL mask secret values.

#### Scenario: SASL_SSL with SCRAM credentials
- **WHEN** the file contains `bootstrap.servers`, `security.protocol=SASL_SSL`, `sasl.mechanism=SCRAM-SHA-512` and a `sasl.jaas.config` with a ScramLoginModule username and password
- **THEN** the preview SHALL list bootstrap servers, protocol, mechanism, username and a masked password
- **AND** applying it SHALL fill those fields in the dialog without saving the profile

#### Scenario: Unknown and unsupported keys
- **WHEN** the file contains `acks=all`, `group.id=x`, `ssl.truststore.type=JKS` and `sasl.password=${file:/secrets.properties:pw}`
- **THEN** the preview SHALL list all four keys as not applied, each with a reason (unknown or not allowed, unsupported store type, placeholder not resolved)
- **AND** none of them SHALL change a dialog field

#### Scenario: Attempt to disable hostname verification
- **WHEN** the file contains `ssl.endpoint.identification.algorithm=` with an empty value
- **THEN** the key SHALL be listed as not applied, with the hint that verification can only be disabled explicitly in the dialog

#### Scenario: Secrets end up only in the keyring
- **WHEN** the user applies a file with passwords and saves the profile
- **THEN** the passwords SHALL be stored in the OS keyring like manually entered passwords
- **AND** the file SHALL NOT be copied, and its path and content SHALL NOT be stored

#### Scenario: Unreadable or oversized file
- **WHEN** the selected file cannot be read, is not valid UTF-8, or is larger than 1 MiB
- **THEN** the dialog SHALL show an error and SHALL leave all fields unchanged

#### Scenario: No Kafka access during prefill
- **WHEN** a file is read and previewed
- **THEN** no broker and no Schema Registry SHALL be contacted

### Requirement: Additional Client Properties Editor

The `ClusterConfigDialog` SHALL offer an advanced section for additional client properties, entered as one `key=value` per line. The section SHALL list the allowed keys with their value range. Each line SHALL be validated as the user types, and the dialog SHALL refuse to save or test while any line uses a key outside the allowlist, has an invalid value, or repeats a key.

#### Scenario: Allowed property
- **WHEN** the user enters `client.id=kafkalyzer-alice` and `socket.timeout.ms=30000`
- **THEN** the dialog SHALL accept both lines and save them with the profile

#### Scenario: Forbidden property
- **WHEN** the user enters `enable.idempotence=x`, `group.id=reader` or `enable.ssl.certificate.verification=false`
- **THEN** the dialog SHALL mark the line as not allowed and SHALL NOT save or test the profile

#### Scenario: Value out of range
- **WHEN** the user enters `socket.timeout.ms=-5`
- **THEN** the dialog SHALL mark the line as an invalid value and name the allowed range

#### Scenario: Stored profile with a now-invalid line
- **WHEN** the dialog opens a stored profile whose additional properties contain a line that is not allowed
- **THEN** the line SHALL be shown and marked as not allowed, and saving SHALL require the user to remove or fix it
