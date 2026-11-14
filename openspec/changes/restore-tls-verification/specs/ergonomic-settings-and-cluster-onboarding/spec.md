# Spec Delta

## ADDED Requirements

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
