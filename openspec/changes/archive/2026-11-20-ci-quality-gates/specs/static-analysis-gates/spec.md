# Spec Delta

## Purpose

Makes formatting, static analysis and lint cleanliness a blocking, reproducible verification step for every change in both the Dart/Flutter and the Rust codebase, so documented quality rules are enforced automatically instead of by convention.

## ADDED Requirements

### Requirement: Automated Source Quality Gate On Every Change

The delivery pipeline SHALL run a source quality gate on every pull request targeting the main branch and on every push to the main branch, independently of the release build stages, and SHALL mark the run as failed when the gate reports any finding.

#### Scenario: Pull request introducing a quality finding is blocked

- **WHEN** a pull request introduces a formatting or static-analysis finding in Dart or Rust sources
- **THEN** the quality gate stage SHALL report a failed result for that pull request
- **AND** the failing check SHALL be named in the run so the contributor can identify which check failed

#### Scenario: Clean pull request passes the gate

- **WHEN** a pull request contains no formatting, analysis or lint findings
- **THEN** the quality gate stage SHALL report a successful result

#### Scenario: Gate result is independent of release builds

- **WHEN** a change is pushed that triggers no release build
- **THEN** the quality gate SHALL still run and report its result

### Requirement: Gate Covers Formatting And Static Analysis For Both Codebases

The quality gate SHALL verify that Dart sources are formatted, that Dart sources are free of analyzer errors, and that Rust sources are formatted. It SHALL additionally verify that the Rust workspace is free of lint findings once that workspace passes without findings.

#### Scenario: Unformatted Dart sources fail the gate

- **WHEN** the gate runs against Dart sources whose formatting differs from the project's formatter output
- **THEN** the gate SHALL fail and identify the affected files

#### Scenario: Unformatted Rust sources fail the gate

- **WHEN** the gate runs against Rust sources whose formatting differs from the workspace formatter output
- **THEN** the gate SHALL fail and identify the affected files

#### Scenario: Analyzer error in Dart sources fails the gate

- **WHEN** the gate runs against Dart sources that contain an analyzer error under the project's configured rule set
- **THEN** the gate SHALL fail and list the reported errors with their locations

#### Scenario: Compile error in the Rust workspace fails the gate

- **WHEN** the Rust lint stage cannot compile a workspace crate, for example because of a compile error or a missing native build dependency
- **THEN** the gate SHALL fail with the tooling error
- **AND** the gate SHALL NOT report success when a stage could not be executed

### Requirement: Lint Warnings Block The Gate

The Rust lint stage SHALL treat lint warnings as blocking findings, so that a newly introduced warning fails the gate even when the same warning class already existed elsewhere in the workspace.

#### Scenario: Newly introduced lint warning fails the gate

- **WHEN** a change introduces a lint warning in any workspace crate
- **THEN** the gate SHALL fail and identify the crate, file and rule

#### Scenario: Suppressed warning with a stated reason passes the gate

- **WHEN** a lint finding is suppressed at the narrowest scope that covers only the affected source item and the suppression carries a reason
- **THEN** the gate SHALL report no finding for that source item

### Requirement: Gate Activated Only On A Clean Baseline

Each individual check SHALL be switched on only for a revision that already passes it; findings that exist before activation SHALL be resolved in the same change or in an explicitly named prerequisite change.

#### Scenario: Activation revision passes every enabled check

- **WHEN** the quality gate is enabled at a revision
- **THEN** that revision SHALL pass all enabled checks, so the gate is green from its first run

#### Scenario: Check that still has findings is not enabled

- **WHEN** a check would fail on the current revision because of pre-existing findings
- **THEN** the change SHALL leave that check disabled and name the prerequisite change that clears the findings
- **AND** the change SHALL NOT lower the severity of that check to make it pass

#### Scenario: Deferred check is switched on once its baseline is clean

- **WHEN** the named prerequisite change has removed the pre-existing findings of a deferred check
- **THEN** a follow-up change SHALL enable that check in the gate, so the gate reaches the full check set instead of staying partially enabled

### Requirement: No Repository-Wide Exception Mechanism

The quality gate SHALL NOT be introduced or kept green by a repository-wide exception list, a baseline or diff-ratchet file, or a workspace-level or project-level downgrade of lint severities.

#### Scenario: Global suppression request is rejected

- **WHEN** a change would satisfy the gate by adding a repository-wide exception list or a global severity downgrade
- **THEN** that change SHALL be considered non-conforming to this capability

#### Scenario: Exception limited to generated sources

- **WHEN** a finding originates in code that is generated by a checked-in generator
- **THEN** the exception SHALL be applied inside that generator's output or configuration only
- **AND** hand-written sources SHALL remain fully checked

### Requirement: Gate Verdict Reproducible Locally

The checks performed by the quality gate SHALL be runnable by a contributor on a workstation with the documented project toolchain, and the documented commands SHALL produce the same pass or fail verdict as the pipeline.

#### Scenario: Contributor reproduces a gate failure locally

- **WHEN** a contributor runs the documented quality-gate commands on the same revision that failed in the pipeline
- **THEN** at least one documented command SHALL fail with the same finding

#### Scenario: Toolchain missing locally

- **WHEN** a required tool is not installed on the contributor's workstation
- **THEN** the command SHALL fail with a tooling error rather than reporting the sources as clean

### Requirement: Quality Gate Performs No Cluster Or Registry Access

The quality gate SHALL NOT open any connection to a Kafka cluster or a Schema Registry, and SHALL NOT replace, weaken or absorb the existing read-only invariant verification stage.

#### Scenario: Gate runs without any broker or registry reachable

- **WHEN** the quality gate runs in an environment with no Kafka cluster and no Schema Registry reachable
- **THEN** all of its checks SHALL complete and report a verdict based only on the checked-out sources

#### Scenario: Read-only verification remains separate

- **WHEN** the quality gate is enabled
- **THEN** the read-only invariant verification stage and its regression test SHALL continue to run unchanged as their own stage
