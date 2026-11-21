# static-analysis-gates Specification

## Purpose

Makes formatting, static analysis and lint cleanliness a blocking, reproducible verification step for every change in both the Dart/Flutter and the Rust codebase, so documented quality rules are enforced automatically instead of by convention.

## Requirements

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

### Requirement: Source File Size Guard For Changed Sources

The quality gate SHALL check the size of hand-written Dart sources under the application source tree, and SHALL fail a change that takes such a file from at or below the agreed size limit to above it, or that adds a new hand-written Dart source above the limit. Files already above the limit at the merge base of the change SHALL stay editable without failing the check, and generated sources SHALL be exempt.

#### Scenario: Change grows a source file past the limit

- **WHEN** a change modifies a hand-written Dart source that was at or below the size limit at the merge base and leaves it above the limit
- **THEN** the quality gate SHALL fail and name the file with its line count and the limit

#### Scenario: Change adds an oversized new source file

- **WHEN** a change adds a new hand-written Dart source that is above the size limit
- **THEN** the quality gate SHALL fail and name the new file with its line count and the limit

#### Scenario: Unrelated work continues in an already oversized file

- **WHEN** a change modifies a hand-written Dart source that was already above the size limit at the merge base
- **THEN** the quality gate SHALL report no finding for that file, so long as the change does not take another file over the limit

#### Scenario: Oversized file is split

- **WHEN** a change splits an oversized source file into several files that are each at or below the limit
- **THEN** the quality gate SHALL report no finding for any of them

#### Scenario: Generated source is large

- **WHEN** the only file above the limit is produced by a checked-in generator or by code generation
- **THEN** the quality gate SHALL report no finding for that file

### Requirement: Size Guard Carries No Exception List

The source file size guard SHALL decide its verdict from the checked-out revision and the merge base of the change alone. It SHALL NOT read a committed baseline, allowlist or ratchet file, and SHALL NOT be silenced by a project-wide configuration switch.

#### Scenario: Contributor tries to exempt a file by editing a list

- **WHEN** keeping the gate green would require adding the file name to a committed exception list
- **THEN** that approach SHALL be considered non-conforming to this capability, and the change SHALL split the file or leave it below the limit

#### Scenario: Merge base is unavailable

- **WHEN** the version control history needed to compare the change against its merge base is not available to the gate
- **THEN** the guard SHALL fail with a tooling error naming the missing revision information
- **AND** it SHALL NOT report success for the checked-out sources

### Requirement: Controller Locator Guard For Presentation Sources

The quality gate SHALL verify that a change does not introduce a new ambient lookup of session-wide state inside presentation sources of a feature, and SHALL scope that check to the hand-written sources the change touches, with no committed baseline or exception list.

#### Scenario: Change introduces a locator lookup for session-wide state

- **WHEN** a change adds a lookup of session-wide state in a presentation source it touches
- **THEN** the gate SHALL fail and identify the file and the state being looked up

#### Scenario: Change only removes such lookups

- **WHEN** a change reduces the number of session-wide state lookups in the presentation sources it touches
- **THEN** the gate SHALL report no finding for those files

#### Scenario: Presentation source needs a stateless service

- **WHEN** a touched presentation source obtains a stateless service or a dependency it receives from its caller
- **THEN** the gate SHALL report no finding, so the check covers session-wide state only

#### Scenario: Composition root wires the state

- **WHEN** the only place that performs such lookups is the application wiring or the shared test setup that provides the state
- **THEN** the gate SHALL report no finding for that source

#### Scenario: Unrelated work in an already non-conforming source

- **WHEN** a change touches a presentation source that already contained such a lookup at the merge base and does not add one
- **THEN** the gate SHALL report no finding for that file, so the existing count does not block unrelated work
