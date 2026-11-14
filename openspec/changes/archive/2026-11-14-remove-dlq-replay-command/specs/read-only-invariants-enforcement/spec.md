# Spec Delta

## ADDED Requirements

### Requirement: Static Check for Producer-Mode CLI Commands

The verification script SHALL fail with a non-zero exit code when any application source contains a `kcat` (or `kafkacat`) command line that uses the producer flag `-P`, so that the application never hands users a ready-made command that writes to Kafka. Consumer-mode commands (`-C`) and metadata commands (`-L`) SHALL remain allowed.

#### Scenario: Producer-mode kcat command fails verification
- **WHEN** an application source contains a string such as `kcat -b broker:9092 -t orders -P`
- **THEN** the verification script SHALL report the file and line
- **AND** the verification script SHALL terminate with a non-zero exit code

#### Scenario: Consumer-mode kcat command passes verification
- **WHEN** an application source contains a string such as `kcat -C -b broker:9092 -t orders -p 0 -o 42 -c 1 -e`
- **THEN** the verification script SHALL NOT report it
