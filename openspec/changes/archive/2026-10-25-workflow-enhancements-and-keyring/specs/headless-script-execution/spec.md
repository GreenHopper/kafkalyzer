# Spec Delta

## Purpose

Provides a headless command-line entry point to execute multi-step automation scripts without a graphical desktop environment, supporting parameter injection, semantic process exit codes, structured JSON reporting, and a one-click CLI command generator in the GUI workspace.

## ADDED Requirements

### Requirement: Standalone Headless Script Execution

The system SHALL provide a command-line interface (CLI) entry point that executes multi-step automation scripts headlessly without initializing Flutter UI components or requiring an active desktop display server.

#### Scenario: Running a saved script via CLI

- **WHEN** the user invokes the headless script runner with a script identifier or script definition file
- **THEN** the runner SHALL execute the script's steps sequentially using the configured cluster profile
- **AND** the runner SHALL stream and filter messages according to the step definitions without opening any UI window

### Requirement: Parameter Ingestion via CLI, Environment, and JSON Files

The headless script runner SHALL accept script variable values through command-line arguments (`--var key=value`), environment variables (`KAFKALYZER_VAR_<KEY>`), or a JSON parameters file (`--params <path>`), resolving and substituting variables in step filters and target topics.

#### Scenario: Overriding script variables via command-line flags

- **WHEN** the runner is executed with `--var limit=50 --var customerId=12345`
- **THEN** all occurrences of `{{limit}}` and `{{customerId}}` in the script steps SHALL be substituted with the provided values

#### Scenario: Missing required parameters aborts with error

- **WHEN** a script contains variables that have no default value and are not supplied via CLI arguments, environment, or parameter file
- **THEN** the runner SHALL terminate immediately with a clear error message identifying the missing variable
- **AND** return a non-zero exit code without initiating Kafka network connections

### Requirement: Semantic Process Exit Codes and Structured JSON Output

The headless script runner SHALL emit a structured JSON report summarizing execution details (step durations, message counts, extracted variables, and any errors) and SHALL return semantic process exit codes (0 for full success, non-zero for any step failure, timeout, or validation error).

#### Scenario: Successful execution produces exit code 0 and JSON summary

- **WHEN** all steps of a script complete successfully
- **THEN** the runner SHALL exit with status code 0
- **AND** output a valid JSON report containing step execution statuses and final extracted variable values

#### Scenario: Step failure produces non-zero exit code

- **WHEN** any step in the pipeline encounters a connection failure, timeout, or syntax error
- **THEN** the runner SHALL immediately halt subsequent steps
- **AND** exit with a non-zero status code
- **AND** include the step error details in the JSON summary output

### Requirement: Read-Only Safety Invariance in Headless Runner

The headless script runner SHALL strictly enforce the application's read-only guarantee by using only consumer and metadata operations without Kafka producer clients, offset commits (`enable.auto.commit=false`), or partition offset mutations.

#### Scenario: Consuming messages does not affect consumer group offsets

- **WHEN** a script step executes against a topic using the headless runner
- **THEN** the runner SHALL read messages without committing offsets or joining consumer groups on the broker

### Requirement: GUI Affordance to Copy Headless Command

The desktop `ScriptRunView` parameter workspace SHALL provide a subtle "Copy CLI Command" button that formats the currently configured script, selected cluster, and typed parameter values into a ready-to-run terminal command and copies it to the system clipboard.

#### Scenario: Copying CLI command from GUI parameter form

- **WHEN** the user clicks "Copy CLI Command" in the Script Run tab
- **THEN** the system SHALL construct the exact CLI command with flags for the active script, cluster, and currently entered parameter values
- **AND** copy the string to the clipboard while presenting a brief confirmation feedback toast
