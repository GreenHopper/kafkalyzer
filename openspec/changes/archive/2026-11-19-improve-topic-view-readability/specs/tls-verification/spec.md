## MODIFIED Requirements

### Requirement: Explicit Per-Profile Opt-Out Only

Disabling certificate and hostname verification SHALL only be possible through an explicit option stored on an
individual cluster profile. No application setting, environment variable, build flag or code path SHALL disable
verification for all profiles or for a profile that has not opted out.

#### Scenario: Opted-out profile connects to a self-signed broker
- **WHEN** a profile has verification explicitly disabled and the broker presents a self-signed certificate
- **THEN** the connection SHALL succeed
- **AND** the profile SHALL be flagged as insecure wherever the profile itself is listed, selected or edited

#### Scenario: Other profiles are unaffected
- **WHEN** one profile has verification disabled and the user connects with a different TLS profile
- **THEN** the second connection SHALL verify certificate and hostname

#### Scenario: Profile whose transition is still undecided
- **WHEN** a profile created before this change has not yet completed its verification transition
- **THEN** every connection made with it SHALL verify certificate and hostname

## ADDED Requirements

### Requirement: Insecure Marker at Connection Level

A profile with verification disabled SHALL show an "insecure" marker made of an icon and a localized text label with a
tooltip on its Explorer sidebar cluster entry, in every cluster selection dropdown and, when present, in the Explorer
header banner of the active cluster. Topic tabs SHALL NOT show the marker.

#### Scenario: Active insecure profile in the sidebar
- **WHEN** the user is connected with a profile whose verification is disabled
- **THEN** the sidebar cluster entry of that profile SHALL show the insecure marker with icon, label and tooltip

#### Scenario: Topic tabs stay clean
- **WHEN** the user opens three topic tabs of a profile whose verification is disabled
- **THEN** none of the tabs SHALL show the insecure marker
- **AND** the sidebar cluster entry SHALL still show it

#### Scenario: Insecure profile in a cluster dropdown
- **WHEN** the user opens a cluster selection dropdown that lists a profile whose verification is disabled
- **THEN** that entry SHALL show the insecure marker next to its name

#### Scenario: Verified profile
- **WHEN** a profile has verification enabled or its transition is still undecided
- **THEN** no insecure marker SHALL be shown for it anywhere

#### Scenario: Narrow sidebar
- **WHEN** the sidebar is too narrow to show the marker label next to the cluster name
- **THEN** the marker SHALL keep its icon, tooltip and semantic label, and the cluster name SHALL be shortened before the marker is dropped

## REMOVED Requirements

### Requirement: Insecure Marker on Explorer Tabs

**Reason**: The marker is a property of the connection, not of a topic. Repeating it on every tab added a red badge per
tab, pushed tab titles out of view and drew attention away from the topic name without adding information beyond the
sidebar entry of the same profile.

**Migration**: The marker is shown on the sidebar cluster entry, in cluster selection dropdowns and in the Explorer
header banner (requirement "Insecure Marker at Connection Level"); Settings, the cluster dialog and the topic
configuration views keep their markers unchanged.
