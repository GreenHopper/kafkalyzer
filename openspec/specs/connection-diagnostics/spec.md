# connection-diagnostics Specification

## Purpose

Lets a user find out why a cluster profile cannot connect by testing it in stages (network, TLS, authentication,
metadata, Schema Registry) and reporting an honest, localized, secret-free result per stage without changing anything
on the cluster or registry.

## Requirements

### Requirement: Staged Connection Diagnosis

A connection diagnosis of a cluster profile SHALL report one result for each of these stages, in this order:
(1) network: DNS resolution and TCP reachability of every bootstrap server, (2) TLS, (3) authentication,
(4) cluster metadata retrieval, (5) Schema Registry. The diagnosis SHALL use the profile exactly as entered,
including its TLS verification setting, without saving it.

#### Scenario: Healthy SASL_SSL profile with registry
- **WHEN** the user diagnoses a `SASL_SSL` profile with valid credentials, a trusted broker certificate and a reachable registry
- **THEN** the result SHALL list the five stages in order, each with state ok
- **AND** the network stage SHALL show for each bootstrap server whether its name resolved and whether a TCP connection succeeded

#### Scenario: Unsaved changes are diagnosed
- **WHEN** the user edits the password in the cluster dialog and runs the diagnosis without saving
- **THEN** the diagnosis SHALL use the edited password
- **AND** the stored profile SHALL remain unchanged

### Requirement: Stage States

Every stage SHALL have exactly one state: ok, failed, not checked, not applicable or undetermined. Not checked SHALL
mean the stage did not run because a stage it depends on failed or the time budget was used up. Not applicable SHALL
mean the profile does not use the stage. Undetermined SHALL only be used under the unknown-stage rule. No state SHALL
be conveyed by colour alone.

#### Scenario: Later stages after a network failure
- **WHEN** no bootstrap server of a profile can be reached over TCP
- **THEN** the network stage SHALL be failed
- **AND** the TLS, authentication and metadata stages SHALL be not checked, naming the failed network stage as the reason

#### Scenario: Profile without TLS, SASL or registry
- **WHEN** a `PLAINTEXT` profile without SASL user and without registry URL is diagnosed successfully
- **THEN** the network and metadata stages SHALL be ok
- **AND** the TLS, authentication and Schema Registry stages SHALL be not applicable

#### Scenario: Partly reachable bootstrap list
- **WHEN** one of two bootstrap servers cannot be resolved and the other is reachable
- **THEN** the network stage SHALL be failed and name the unresolvable server
- **AND** the remaining stages SHALL still run against the cluster

### Requirement: Network Stage Independent of the Kafka Client

The network stage SHALL resolve each bootstrap server and open a plain TCP connection to a resolved address with its
own timeout, independently of the Kafka client library. It SHALL close each connection without sending data and SHALL
report a malformed bootstrap entry as a failure of that entry without contacting any host.

#### Scenario: Unknown host name
- **WHEN** a bootstrap server name cannot be resolved
- **THEN** that server SHALL show DNS failed with a hint that the host name is unknown and TCP not checked

#### Scenario: Port closed
- **WHEN** the name resolves but every resolved address refuses the TCP connection
- **THEN** that server SHALL show DNS ok, the resolved addresses, and TCP failed with a "connection refused" hint

#### Scenario: Port filtered
- **WHEN** a TCP connection attempt does not complete within the step timeout
- **THEN** that server SHALL show TCP failed with a timeout hint that names the port

#### Scenario: Malformed bootstrap entry
- **WHEN** a bootstrap entry has no valid host and port
- **THEN** that entry SHALL be reported as invalid and no network request SHALL be made for it

### Requirement: Evidence-Based Attribution of TLS, Authentication and Metadata Results

The TLS, authentication and metadata stages SHALL be derived only from error codes and messages reported by the
Kafka client during one metadata request. A stage SHALL be marked failed only when that evidence identifies it. A
successful metadata request SHALL mark all three stages ok or not applicable.

#### Scenario: Untrusted broker certificate
- **WHEN** verification is enabled and the broker certificate is rejected
- **THEN** the TLS stage SHALL be failed with a certificate hint and the raw error
- **AND** authentication and metadata SHALL be not checked

#### Scenario: Plaintext client against a TLS listener or vice versa
- **WHEN** the client evidence indicates a security protocol mismatch with the broker listener
- **THEN** the TLS stage SHALL be failed with a hint to check the selected security protocol

#### Scenario: Wrong SASL password
- **WHEN** the client reports a SASL authentication failure
- **THEN** the authentication stage SHALL be failed with a credentials hint
- **AND** the TLS stage SHALL be ok for a TLS profile, because authentication only starts after a completed handshake

#### Scenario: Metadata request not authorized
- **WHEN** the client reports an authorization error for the metadata request
- **THEN** the metadata stage SHALL be failed with an ACL hint and TLS and authentication SHALL be ok or not applicable

### Requirement: Unknown Stage Instead of a Guess

When the metadata request fails and the evidence identifies no stage, or points to more than one stage, the
diagnosis SHALL report "connection failed, stage unknown" with the raw error, and the TLS, authentication and
metadata stages SHALL be undetermined. The system SHALL NOT pick a stage by guessing.

#### Scenario: Timeout without further evidence
- **WHEN** the network stage succeeded but the metadata request times out with no TLS or authentication message
- **THEN** the overall result SHALL be "connection failed, stage unknown" with the raw error
- **AND** TLS, authentication and metadata SHALL be undetermined, not failed

#### Scenario: Contradicting evidence
- **WHEN** the client reports both a TLS error and an authentication error during the same diagnosis
- **THEN** the overall result SHALL be "connection failed, stage unknown" and list both raw errors

### Requirement: Schema Registry Stage

When a registry URL is configured, the diagnosis SHALL send one read-only request to the registry with the profile's
registry credentials and TLS setting, bounded by a timeout, and SHALL report the stage independently of the Kafka
stages. Without a registry URL the stage SHALL be not applicable.

#### Scenario: Registry rejects the credentials
- **WHEN** the registry answers with HTTP 401 or 403
- **THEN** the Schema Registry stage SHALL be failed with a credentials hint and the status code

#### Scenario: Registry unreachable while Kafka is fine
- **WHEN** the registry host cannot be reached or does not answer within the timeout and all Kafka stages are ok
- **THEN** the Schema Registry stage SHALL be failed with an "unreachable" or timeout hint
- **AND** the Kafka stages SHALL keep their ok results

#### Scenario: Registry certificate rejected
- **WHEN** verification is enabled and the registry certificate cannot be verified
- **THEN** the Schema Registry stage SHALL be failed with a certificate hint

### Requirement: Localized Hint with Raw Error

Every failed stage, every failed bootstrap server and the unknown-stage result SHALL show a localized hint and the
raw error text it is based on. The raw text SHALL be selectable so it can be copied. A failure without a known hint
SHALL show a generic localized hint and the raw error.

#### Scenario: Failure with a known hint
- **WHEN** the authentication stage fails
- **THEN** the user SHALL see the localized credentials hint and the raw client message below it

#### Scenario: Failure without a matching hint
- **WHEN** a stage fails with an error that has no specific hint
- **THEN** a generic localized "failed" hint SHALL be shown together with the raw error, never an empty message

### Requirement: No Secrets in Diagnostic Output

No result text, raw error or log line produced by the diagnosis SHALL contain a secret of the profile (SASL
password, keystore, truststore or key passwords, OAuth token, registry password). Any occurrence of such a value
SHALL be replaced by a fixed placeholder before it leaves the diagnosis.

#### Scenario: Error text echoes a secret
- **WHEN** a raw error message contains the profile's SASL password verbatim
- **THEN** the shown message SHALL contain the placeholder instead of the password

#### Scenario: Usernames and hosts remain visible
- **WHEN** a raw error names the bootstrap host or the SASL username
- **THEN** the host and username SHALL remain visible

### Requirement: Bounded Diagnosis Duration

The whole diagnosis SHALL finish within a fixed overall time budget. Each network step, the metadata request and the
registry request SHALL have their own timeout within that budget, and a stage that cannot start before the budget is
used up SHALL be not checked with a timeout reason.

#### Scenario: All hosts silently drop packets
- **WHEN** every bootstrap address and the registry drop all packets
- **THEN** the diagnosis SHALL return a complete result within the overall budget
- **AND** the user interface SHALL show a progress indicator until then and stay responsive

### Requirement: Diagnosis Stays Read-Only

The diagnosis SHALL only open TCP connections without sending data, issue one Kafka metadata request and one
Schema Registry read request. It SHALL NOT join a consumer group, assign partitions, consume, commit offsets,
produce, or create or change anything on the cluster or the registry.

#### Scenario: Diagnosing a production profile
- **WHEN** the user diagnoses a profile pointing at a production cluster
- **THEN** no consumer group, offset, topic, configuration, subject or schema SHALL be created or changed
- **AND** the only Kafka request sent SHALL be a metadata request
