# Read-Only Invariants Enforcement Specification

## Purpose

Enforces strict read-only guarantees across the codebase through automated static analysis tooling and continuous integration verification gates, preventing accidental introduction of Kafka producer clients, message publishing, or partition offset mutations.

## Requirements

### Requirement: Automated Static Analysis Check for Write and Commit Paths

The system SHALL provide a dedicated static verification script that scans all Rust and Dart source files, failing with a descriptive error message and non-zero exit code if any Kafka producer, message publish, consumer group subscription, or offset commit API is detected.

#### Scenario: Forbidden Kafka producer or publish call fails verification

- **WHEN** the static analysis script is executed on source files containing `Producer`, `ThreadedProducer`, `FutureRecord`, or `.send(`
- **THEN** the script SHALL output the offending file paths and line numbers
- **AND** terminate execution with a non-zero exit status

#### Scenario: Forbidden consumer group commit call fails verification

- **WHEN** the static analysis script is executed on source files containing consumer `commit(`, `commit_message(`, or `commit_consumer_state(`
- **THEN** the script SHALL output the offending lines
- **AND** terminate execution with a non-zero exit status

#### Scenario: Compliant read-only codebase passes verification

- **WHEN** the static analysis script is executed against a codebase containing only consumer read and metadata query APIs
- **THEN** the script SHALL print a confirmation message stating that all read-only invariants are satisfied
- **AND** terminate execution with exit code 0

### Requirement: Continuous Integration Enforcement Gate

The automated CI workflow SHALL execute the read-only verification script and its regression test as an independent check on every pull request and branch build, failing the CI pipeline if any prohibited write, commit, admin mutation, offset store, HTTP write or dependency placement pattern is detected, or if any regression case fails.

#### Scenario: Pull request with prohibited write pattern is blocked in CI

- **WHEN** a pull request introduces a Kafka producer dependency or message mutation API
- **THEN** the CI workflow job for read-only verification SHALL fail
- **AND** block merging of the pull request

#### Scenario: Pull request with misplaced Kafka or bridge dependency is blocked in CI

- **WHEN** a pull request declares the Kafka client, HTTP client or bridge framework library in a crate outside its allowed crate
- **THEN** the CI workflow job for read-only verification SHALL fail

#### Scenario: Pull request that breaks a gate regression case is blocked in CI

- **WHEN** a pull request changes the verification script so that one of its regression cases fails
- **THEN** the CI workflow job for read-only verification SHALL fail

#### Scenario: Clean pull request passes CI gate

- **WHEN** all source code changes strictly adhere to read-only consumer and metadata operations
- **THEN** the CI workflow job for read-only verification SHALL succeed

### Requirement: Architectural Invariance of Kafka Consumer Configuration

Every Kafka consumer client configured and instantiated in the native backend SHALL explicitly configure `enable.auto.commit` as `false`, use manual partition assignment without joining broker consumer groups, and perform no partition offset commits.

#### Scenario: Consumer configuration sets enable.auto.commit to false

- **WHEN** a Kafka consumer client configuration is constructed for partition consumption or search streaming
- **THEN** the client configuration SHALL explicitly set `enable.auto.commit` to `false`

#### Scenario: Stream consumption does not mutate broker consumer group offsets

- **WHEN** message streaming or analysis completes, pauses, or terminates
- **THEN** the consumer client SHALL NOT invoke offset commit APIs or alter high-watermark consumer group progress on the broker

### Requirement: Static Check for Mutating Admin and Offset-Store Calls

The static verification script SHALL fail with a non-zero exit status and report the offending file paths and line numbers if any Rust or Dart source file calls a mutating cluster administration API (topic, partition, config, record or consumer-group mutation) or a consumer offset-store API. No exception marker SHALL exempt these calls.

#### Scenario: Mutating admin call fails verification

- **WHEN** the script is executed on source files containing a call to `create_topics(`, `delete_topics(`, `create_partitions(`, `alter_configs(`, `incremental_alter_configs(`, `delete_records(` or `delete_groups(`
- **THEN** the script SHALL output the offending file paths and line numbers
- **AND** terminate execution with a non-zero exit status

#### Scenario: Offset-store call fails verification

- **WHEN** the script is executed on source files containing a call to `store_offset(`, `store_offsets(` or `store_offset_from_message(`
- **THEN** the script SHALL output the offending lines
- **AND** terminate execution with a non-zero exit status

#### Scenario: Exception marker does not exempt admin or offset-store calls

- **WHEN** a line containing a mutating admin or offset-store call also carries the read-only exception marker
- **THEN** the script SHALL still report the line as a violation
- **AND** terminate execution with a non-zero exit status

#### Scenario: Describe-only admin usage passes verification

- **WHEN** the script is executed on source files that create an admin client and call only describe operations such as `describe_configs(`
- **THEN** the admin and offset-store checks SHALL report no violation

### Requirement: Static Check for HTTP Write Methods in Native Backend Sources

The static verification script SHALL fail with a non-zero exit status if any Rust source file issues an HTTP `PUT`, `DELETE` or `PATCH` request, and SHALL accept an HTTP `POST` request only on a line that carries the read-only exception marker followed by a written reason. Dart sources SHALL NOT be evaluated by this check.

#### Scenario: HTTP PUT, DELETE or PATCH request fails verification

- **WHEN** the script is executed on Rust source files containing `.put(`, `.delete(`, `.patch(` or an explicit `Method::PUT`, `Method::DELETE` or `Method::PATCH`
- **THEN** the script SHALL output the offending file paths and line numbers
- **AND** terminate execution with a non-zero exit status

#### Scenario: Unmarked HTTP POST request fails verification

- **WHEN** the script is executed on Rust source files containing `.post(` or `Method::POST` on a line without the read-only exception marker
- **THEN** the script SHALL output the offending lines
- **AND** terminate execution with a non-zero exit status

#### Scenario: Marker without a reason does not exempt an HTTP POST request

- **WHEN** a Rust line containing `.post(` carries the read-only exception marker but no reason text after it
- **THEN** the script SHALL report the line as a violation
- **AND** terminate execution with a non-zero exit status

#### Scenario: Marked and reasoned HTTP POST request passes verification

- **WHEN** a Rust line containing `.post(` carries the read-only exception marker followed by a reason, such as the Schema Registry compatibility check that stores nothing
- **THEN** the HTTP write check SHALL NOT report that line

#### Scenario: Unrelated Dart delete methods are not reported

- **WHEN** a Dart source file calls a non-HTTP method named `delete(`, such as deleting a secure-storage key or a directory
- **THEN** the HTTP write check SHALL NOT report that line

### Requirement: Crate Dependency Allowlist for Kafka, HTTP and Bridge Libraries

The static verification script SHALL fail with a non-zero exit status if a Cargo manifest of the application's Rust workspace other than the Kafka I/O crate declares the Kafka client or HTTP client libraries, or if a manifest other than the bridge crate declares the Rust-Dart bridge framework. Manifests outside the application's Rust workspace SHALL NOT be evaluated.

#### Scenario: Kafka client declared outside the Kafka I/O crate fails verification

- **WHEN** a manifest under the Rust workspace other than the Kafka I/O crate's manifest declares `rdkafka`, `rdkafka-sys` or `reqwest`, in any dependency section, table form or through a `package` rename
- **THEN** the script SHALL output the offending manifest path and line number
- **AND** terminate execution with a non-zero exit status

#### Scenario: Bridge framework declared outside the bridge crate fails verification

- **WHEN** a manifest under the Rust workspace other than the bridge crate's root manifest declares `flutter_rust_bridge`
- **THEN** the script SHALL output the offending manifest path and line number
- **AND** terminate execution with a non-zero exit status

#### Scenario: Dependencies declared in their allowed crates pass verification

- **WHEN** the Kafka client and HTTP client libraries are declared only in the Kafka I/O crate, including platform-specific dependency sections, and the bridge framework only in the bridge crate
- **THEN** the dependency allowlist check SHALL report no violation

#### Scenario: Vendored plugin manifests are not evaluated

- **WHEN** a manifest outside the application's Rust workspace, such as a vendored Flutter plugin, declares the bridge framework
- **THEN** the dependency allowlist check SHALL NOT report it

### Requirement: Static Check for Mutating Native Kafka Library Calls

The verification script SHALL fail with a non-zero exit code when any native backend source calls a mutating function of the underlying C Kafka library directly (produce, commit, offset store, subscribe, topic/partition/config/record/group/ACL mutation), so that a foreign-function binding cannot bypass the higher-level checks. Read-only describe and list functions SHALL remain allowed.

#### Scenario: Direct native commit or offset mutation fails verification

- **WHEN** a native backend source calls a native library function that commits, stores or alters consumer group offsets
- **THEN** the verification script SHALL report the file and line
- **AND** the verification script SHALL terminate with a non-zero exit code

#### Scenario: Native read-only listing passes verification

- **WHEN** a native backend source calls a native library function that only lists or describes consumer group offsets or groups
- **THEN** the verification script SHALL NOT report it

### Requirement: Regression Cases for Every Gate Pattern

The verification script SHALL be accompanied by an automated regression test that, for every prohibited pattern, contains at least one case that the script must reject and at least one compliant case that it must accept, and that also asserts the unmodified repository passes the script.

#### Scenario: Regression test detects a pattern that no longer rejects

- **WHEN** a gate pattern is weakened so that its prohibited example is no longer rejected
- **THEN** the regression test SHALL fail with a non-zero exit status naming the failing case

#### Scenario: Regression test detects a false positive

- **WHEN** a gate pattern is changed so that its compliant example is rejected
- **THEN** the regression test SHALL fail with a non-zero exit status naming the failing case

#### Scenario: Regression test passes for the intact gate

- **WHEN** the regression test runs against the intact gate and the unmodified repository
- **THEN** every case SHALL pass
- **AND** the regression test SHALL terminate with exit code 0

### Requirement: Static Check for Producer-Mode CLI Commands

The verification script SHALL fail with a non-zero exit code when any application source contains a `kcat` (or `kafkacat`) command line that uses the producer flag `-P`, so that the application never hands users a ready-made command that writes to Kafka. Consumer-mode commands (`-C`) and metadata commands (`-L`) SHALL remain allowed.

#### Scenario: Producer-mode kcat command fails verification
- **WHEN** an application source contains a string such as `kcat -b broker:9092 -t orders -P`
- **THEN** the verification script SHALL report the file and line
- **AND** the verification script SHALL terminate with a non-zero exit code

#### Scenario: Consumer-mode kcat command passes verification
- **WHEN** an application source contains a string such as `kcat -C -b broker:9092 -t orders -p 0 -o 42 -c 1 -e`
- **THEN** the verification script SHALL NOT report it
