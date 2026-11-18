# tls-verification Specification

## Purpose

Ensures that every TLS connection kafkalyzer opens to a Kafka cluster or its Schema Registry verifies the server
certificate chain and hostname, that verification can only be turned off explicitly and visibly per cluster profile,
and that profiles created before verification was restored are moved to a verified or explicitly insecure state once.

## Requirements

### Requirement: Certificate and Hostname Verification by Default

For every cluster profile using `SSL` or `SASL_SSL`, the system SHALL verify the broker certificate chain against the
configured truststore (or the platform default trust anchors when none is configured) and SHALL verify that the
broker hostname matches the certificate, unless verification is explicitly disabled for that profile.

#### Scenario: Broker with a trusted certificate
- **WHEN** the user connects with a TLS profile whose broker certificate chains to a trusted CA and matches the broker hostname
- **THEN** the connection SHALL succeed with verification active

#### Scenario: Broker certificate from an untrusted CA
- **WHEN** the user connects with a TLS profile whose broker certificate does not chain to any trusted CA and verification is not disabled
- **THEN** the connection SHALL fail
- **AND** the error shown SHALL state that the server certificate could not be verified, not that the cluster has no topics

#### Scenario: Hostname mismatch
- **WHEN** the broker presents a certificate trusted by the CA but issued for a different hostname than the configured bootstrap address
- **THEN** the connection SHALL fail with a verification error

#### Scenario: Configured truststore cannot be read
- **WHEN** the configured truststore file is missing or cannot be parsed
- **THEN** the system SHALL NOT fall back to an unverified connection
- **AND** a failing connection SHALL report an error instead of an empty result

#### Scenario: Truststore contains only an intermediate CA
- **WHEN** the configured truststore (PEM or PKCS#12) contains an intermediate CA that signed the broker certificate but is not a self-signed root
- **THEN** the system SHALL treat that certificate as a trust anchor (Java truststore semantics)
- **AND** the connection SHALL succeed with verification active when the broker certificate chains to that intermediate and the hostname matches

### Requirement: Explicit Per-Profile Opt-Out Only

Disabling certificate and hostname verification SHALL only be possible through an explicit option stored on an
individual cluster profile. No application setting, environment variable, build flag or code path SHALL disable
verification for all profiles or for a profile that has not opted out.

#### Scenario: Opted-out profile connects to a self-signed broker
- **WHEN** a profile has verification explicitly disabled and the broker presents a self-signed certificate
- **THEN** the connection SHALL succeed
- **AND** the profile SHALL be flagged as insecure wherever it is shown

#### Scenario: Other profiles are unaffected
- **WHEN** one profile has verification disabled and the user connects with a different TLS profile
- **THEN** the second connection SHALL verify certificate and hostname

#### Scenario: Profile whose transition is still undecided
- **WHEN** a profile created before this change has not yet completed its verification transition
- **THEN** every connection made with it SHALL verify certificate and hostname

### Requirement: Schema Registry Follows the Profile Verification Setting

HTTPS requests to the Schema Registry of a profile SHALL verify the registry certificate and hostname whenever
verification is not explicitly disabled for that profile, and SHALL skip both checks only when it is disabled.

#### Scenario: Registry with an untrusted certificate and verification on
- **WHEN** a profile without the opt-out points to an HTTPS Schema Registry whose certificate cannot be verified and the user loads subjects
- **THEN** the request SHALL fail
- **AND** the UI SHALL report the registry error instead of an empty subject list or "no schema"

#### Scenario: Registry with an untrusted certificate and verification disabled
- **WHEN** the same registry is used by a profile with verification explicitly disabled
- **THEN** subjects and schemas SHALL load

#### Scenario: Registry unreachable
- **WHEN** the Schema Registry host cannot be reached
- **THEN** the system SHALL report the registry as unreachable and SHALL show schema information as unknown, not as absent

### Requirement: Insecure Marker on Explorer Tabs

Every open Explorer tab that belongs to a profile with verification disabled SHALL display an "insecure" marker made
of an icon and a localized text label with a tooltip, so the state is not conveyed by colour alone.

#### Scenario: Tab of an insecure profile
- **WHEN** the user opens a topic tab while connected with a profile whose verification is disabled
- **THEN** the tab SHALL show the insecure marker next to the profile name

#### Scenario: Tab of a verified profile
- **WHEN** the user opens a topic tab while connected with a profile whose verification is enabled or still undecided
- **THEN** the tab SHALL NOT show the insecure marker

### Requirement: One-Time Verification Transition at Upgrade

On the first start after the upgrade, the system SHALL test each existing TLS profile with verification forced on and
without blocking the UI. A verified result SHALL enable verification silently. A certificate or hostname rejection
SHALL open a transition dialog for that profile. Profiles without TLS SHALL be marked enabled without a test.

#### Scenario: Existing profile passes the verified test
- **WHEN** the app starts for the first time after the upgrade and an existing TLS profile connects successfully with verification
- **THEN** verification SHALL be enabled for that profile and persisted
- **AND** no dialog SHALL be shown for it

#### Scenario: Existing profile fails certificate verification
- **WHEN** the test of an existing TLS profile is rejected because the certificate or hostname cannot be verified
- **THEN** a transition dialog for that profile SHALL name the profile and the verification error
- **AND** offer exactly two choices: keep verification on and fix the profile, or disable verification explicitly

#### Scenario: User keeps verification on
- **WHEN** the user chooses to keep verification on in the transition dialog
- **THEN** verification SHALL be enabled and persisted for the profile
- **AND** later connections SHALL keep failing with the verification error until the profile is fixed

#### Scenario: User disables verification
- **WHEN** the user chooses to disable verification in the transition dialog
- **THEN** verification SHALL be disabled and persisted for the profile only
- **AND** the profile SHALL be flagged as insecure

#### Scenario: Several profiles fail
- **WHEN** more than one existing profile is rejected
- **THEN** one transition dialog per profile SHALL be shown, one after another

#### Scenario: Decision is not asked again
- **WHEN** a profile's transition was decided and the app is restarted
- **THEN** no test and no transition dialog SHALL be repeated for that profile

### Requirement: Deferred Transition for Unreachable Clusters

If the transition test of a profile is inconclusive (cluster unreachable, timeout, authentication or other non-
verification failure) or its transition dialog is dismissed, the decision SHALL be deferred to the next connect with
that profile. Until decided, the profile SHALL only connect with verification and SHALL NOT be shown as verified.

#### Scenario: Cluster unreachable during the upgrade
- **WHEN** an existing TLS profile cannot reach its brokers during the startup test
- **THEN** the profile SHALL stay undecided without a dialog
- **AND** the startup test SHALL NOT run again on later starts

#### Scenario: Next connect resolves a deferred profile
- **WHEN** the user later connects with an undecided profile and the verified connection succeeds
- **THEN** verification SHALL be enabled and persisted for the profile

#### Scenario: Next connect is rejected by verification
- **WHEN** the user connects with an undecided profile and the certificate or hostname is rejected
- **THEN** the transition dialog for that profile SHALL be shown before any further connection attempt
- **AND** no connection SHALL be made without verification unless the user chooses to disable it

#### Scenario: Transition dialog dismissed
- **WHEN** the user closes a transition dialog without choosing
- **THEN** the profile SHALL stay undecided and connect only with verification

#### Scenario: Imported profile from an older version
- **WHEN** the user imports a profile bundle exported by a version without the verification setting
- **THEN** the imported TLS profiles SHALL be undecided and resolved at their next connect

#### Scenario: Non-interactive run with an undecided profile
- **WHEN** a headless script run uses an undecided profile
- **THEN** it SHALL connect only with verification, SHALL report a verification failure as an error, and SHALL NOT change the profile's state

### Requirement: Verification Test Stays Read-Only

The verification test SHALL only open a client connection and request cluster metadata. It SHALL NOT join a consumer
group, assign partitions, consume or commit offsets, produce, or call the Schema Registry, and SHALL end within a
bounded timeout.

#### Scenario: Testing a profile
- **WHEN** the system tests a profile with verification forced on
- **THEN** the only broker request issued SHALL be a metadata request
- **AND** no consumer group, offset or topic on the cluster SHALL be created or changed

#### Scenario: Test does not finish in time
- **WHEN** the brokers do not answer within the test timeout
- **THEN** the test SHALL end with an inconclusive result instead of blocking startup or the connect action
