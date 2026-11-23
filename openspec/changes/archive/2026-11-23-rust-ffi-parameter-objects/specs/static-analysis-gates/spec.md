# Spec Delta

## ADDED Requirements

### Requirement: Native Build Prerequisites For Rust Verification

The project SHALL document the native build packages that the Rust workspace verification commands require on each supported operating system, and the local build entry point SHALL check that same set before running them. A missing native package SHALL stop the command with a tooling error naming the package and SHALL NOT be reported as a clean source tree.

#### Scenario: Native package missing on a contributor workstation

- **WHEN** a contributor runs the workspace lint or workspace test command on a machine that lacks a required native development package
- **THEN** the run SHALL fail with a tooling error that names the missing package and the documented way to install it
- **AND** the run SHALL NOT report zero findings or otherwise present the sources as clean

#### Scenario: Local prerequisite check compared with the pipeline

- **WHEN** the documented prerequisite set is compared with the packages the pipeline installs before running the same commands
- **THEN** both SHALL require the same set of native packages
- **AND** a revision that is green in the pipeline SHALL be reachable as green locally

#### Scenario: Library provided by a non-system package manager

- **WHEN** a workstation provides a required native library through a package manager other than the system one
- **THEN** the documented search-path override SHALL let the same commands reach the same verdict as the pipeline
- **AND** that override SHALL be recorded where a contributor can find it
