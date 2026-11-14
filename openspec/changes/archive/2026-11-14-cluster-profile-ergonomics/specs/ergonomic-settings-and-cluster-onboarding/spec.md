# Spec Delta

## ADDED Requirements

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
