## MODIFIED Requirements

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
- **THEN** its sidebar tile, Settings tile and Explorer header banner SHALL show both the environment chip and the insecure marker
- **AND** its tabs SHALL show only the environment chip

#### Scenario: Tagged cluster in a dropdown
- **WHEN** the user opens the cluster dropdown in the Consumer Lag view
- **THEN** each tagged profile entry SHALL show its environment chip next to the name
