# Read-Only Security Guidance Specification

## Purpose

Provides in-app security guidance, cluster configuration trust indicators, and comprehensive documentation defining kafkalyzer's read-only guarantees and recommended least-privilege Apache Kafka service account ACL configurations.

## Requirements

### Requirement: Documented Read-Only Invariants and Threat Model

The application documentation in `README.md` SHALL feature a dedicated "Read-Only by Design" section detailing the architectural implementation invariants and verifiable safety guarantees that ensure no write operations occur against connected Kafka clusters.

#### Scenario: Inspecting read-only documentation in README

- **WHEN** a user or security reviewer inspects `README.md`
- **THEN** the documentation SHALL list the verifiable technical invariants including exclusive use of `BaseConsumer`, explicit partition assignment, `enable.auto.commit=false`, and absence of partition offset commit APIs
- **AND** provide instructions for running the verification script locally

### Requirement: Least-Privilege Service Account Recommendations

The system SHALL provide explicit recommendations for configuring least-privilege Kafka service accounts and ACLs, specifying that permissions should be restricted to `Describe`, `Read`, and `DescribeConfigs` on Topic and Group resources without `Write`, `AlterConfigs`, or `IdempotentWrite`.

#### Scenario: Reviewing recommended ACL permissions in cluster configuration

- **WHEN** the user inspects connection security guidance in the Cluster Configuration Dialog or Settings view
- **THEN** the system SHALL present the recommended minimal ACL rules for Topic and Consumer Group operations
- **AND** warn that write permissions are unnecessary for kafkalyzer and should be omitted to enforce defense-in-depth on the broker

### Requirement: In-App Read-Only Trust Indicators

The Cluster Configuration Dialog and Settings view SHALL render a subtle, non-intrusive read-only trust indicator that informs the user that kafkalyzer operates strictly in read-only mode and provides a link or popover to the least-privilege service account recommendations.

#### Scenario: Viewing read-only trust badge in Cluster Configuration Dialog

- **WHEN** the Cluster Configuration Dialog is displayed
- **THEN** a subtle read-only trust badge SHALL be visible in the dialog header or security section
- **AND** tapping or hovering the indicator SHALL display a concise explanatory tooltip confirming that no write, commit, or alteration operations are ever performed

#### Scenario: Opening recommended ACL guidance dialog

- **WHEN** the user clicks the security information action on the read-only indicator
- **THEN** the application SHALL open a lightweight dialog displaying the recommended ACL configuration and Kafka CLI examples for creating a read-only service account
