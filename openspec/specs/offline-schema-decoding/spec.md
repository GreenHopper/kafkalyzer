# offline-schema-decoding Specification

## Purpose

Lets users decode Avro, Protobuf and JSON Schema messages with schema files from their own machine when a Schema
Registry is not available, so search, analysis and scripts work on fields instead of raw bytes.

## Requirements

### Requirement: Local Schema Assignment Per Topic Side

The user SHALL be able to assign one local schema file to the key and one to the value of a topic. Supported files are an Avro schema, a proto3 Protobuf source file, a Protobuf descriptor set and a JSON Schema. The schema type SHALL default from the file extension and SHALL be changeable. A Protobuf assignment SHALL name one message type from the file.

#### Scenario: Assigning an Avro schema to the value

- **WHEN** the user assigns the file `orders.avsc` to the value of topic `orders`
- **THEN** the assignment SHALL show type Avro, the file name and the number of fields read from the schema

#### Scenario: Choosing the Protobuf message type

- **WHEN** the user assigns a descriptor set that defines the messages `acme.Order` and `acme.Refund`
- **THEN** the assignment SHALL list both message types and SHALL require one of them to be chosen before it can be saved

#### Scenario: File cannot be used

- **WHEN** the chosen file cannot be read, is not a valid schema of the chosen type, or is a proto2 source file or a source file that imports other files
- **THEN** the assignment SHALL show the reason, SHALL NOT be saved, and for the Protobuf cases SHALL suggest using a descriptor set

#### Scenario: Removing an assignment

- **WHEN** the user removes the value assignment of a topic
- **THEN** later scans of that topic SHALL decode the value as they did without a local schema

### Requirement: Assignment Stored Per Cluster And Topic

Assignments SHALL be stored on this machine per cluster profile and topic and SHALL survive a restart. An assignment SHALL apply only to the cluster and topic it was made for. A stored assignment that cannot be read SHALL be reported and kept, never silently dropped or overwritten.

#### Scenario: Same topic name on another cluster

- **WHEN** topic `orders` has a value assignment on cluster `prod` and the user opens topic `orders` on cluster `test`
- **THEN** no local schema SHALL apply on cluster `test`

#### Scenario: Assignment after restart

- **WHEN** the application is restarted after a value assignment was saved
- **THEN** the assignment SHALL be shown and applied for that cluster and topic

#### Scenario: Stored assignment unreadable

- **WHEN** the stored assignment data of a topic cannot be parsed
- **THEN** the topic SHALL show that its local schema assignment could not be read
- **AND** the stored data SHALL be kept until the user replaces or removes the assignment

### Requirement: Precedence Between Registry And Local Schema

Each assignment SHALL have a mode. In the default mode the local schema SHALL decode a side only when the registry cannot: no registry configured, registry unreachable, no subject for that side, schema id not resolvable, or a payload without the registry prefix. In the mode "always use local schema" the local schema SHALL decode every message of that side.

#### Scenario: No registry configured

- **WHEN** the cluster profile has no Schema Registry and the value of the topic has a local Avro assignment
- **THEN** every value SHALL be decoded with the local schema

#### Scenario: Registry decodes the message

- **WHEN** the registry is reachable, the value subject exists, the payload carries a resolvable schema id, and the assignment uses the default mode
- **THEN** the value SHALL be decoded with the registry schema and the local schema SHALL NOT be used

#### Scenario: Registry unreachable

- **WHEN** the registry is configured but cannot be reached at scan start and the assignment uses the default mode
- **THEN** the value SHALL be decoded with the local schema

#### Scenario: Always use the local schema

- **WHEN** the assignment is set to "always use local schema" and the registry could decode the payload
- **THEN** the value SHALL be decoded with the local schema

### Requirement: Schema File Read Once Per Scan

The assigned file SHALL be read and parsed once when a scan starts and SHALL NOT be read per message. A file that is missing, unreadable, too large or invalid at scan start SHALL NOT stop the scan. Every message of that side SHALL then show its raw form with the load error.

#### Scenario: Many messages share one file read

- **WHEN** a scan decodes 100,000 values with a local schema
- **THEN** the schema file SHALL be read once for that scan

#### Scenario: File missing at scan start

- **WHEN** the assigned file was deleted before the scan starts
- **THEN** the scan SHALL return the same messages as without an assignment, in their raw form
- **AND** each affected message SHALL state that the local schema file was not found

#### Scenario: File edited during a scan

- **WHEN** the file is edited while a scan is running
- **THEN** the running scan SHALL keep using the schema read at its start, and the next scan SHALL read the new file

### Requirement: Assignment File State

The topic SHALL show the state of each assignment: usable, file not found, file not readable, schema invalid, message type no longer present, or file changed since it was assigned. A state that could not be checked SHALL be shown as unknown.

#### Scenario: File changed since assignment

- **WHEN** the assigned file still parses but its content differs from the content checked at assignment time
- **THEN** the assignment SHALL be marked as changed, SHALL still be used, and the user SHALL be able to confirm the new content

#### Scenario: Message type removed from the file

- **WHEN** the assigned Protobuf message type is no longer defined in the file
- **THEN** the assignment SHALL show that the message type is missing and SHALL offer to choose another one

### Requirement: Local Schemas Apply In Search, Analysis And Scripts

An assignment SHALL apply to every scan of its cluster and topic: the topic message view, the consumer-lag message view, the topic analysis and script steps, in the application and in headless script runs. The topic analysis SHALL show which side was decoded with which local file and SHALL count messages that failed local decoding as their own content type.

#### Scenario: Script step on a topic with an assignment

- **WHEN** a script step, run headless, reads topic `orders` on a cluster where its value has a local schema
- **THEN** the step results SHALL contain the decoded values and their local file provenance

#### Scenario: Analysis with a local schema

- **WHEN** a topic analysis runs on a topic whose value has a local Avro assignment and no registry is configured
- **THEN** field presence and value statistics SHALL be computed from the decoded values

#### Scenario: Analysis with failing local decoding

- **WHEN** some values of an analysed topic do not match the local schema
- **THEN** the analysis SHALL report how many values failed local decoding instead of counting them as text or binary

### Requirement: Local Schema In The Schema View And Field Suggestions

The topic schema view SHALL show each assignment with file name, type, message type, mode and state, with actions to assign, change and remove, also when no registry is configured. A usable local schema SHALL show its field structure. Field suggestions SHALL use the local schema when it decodes that side.

#### Scenario: Cluster without registry

- **WHEN** the user opens the schema view of a topic on a cluster without a Schema Registry
- **THEN** the view SHALL offer to assign a local schema file in addition to the existing settings action

#### Scenario: Field suggestions from a local schema

- **WHEN** the value of a topic has a usable local Protobuf assignment and no registry is configured
- **THEN** field-path suggestions SHALL list the fields of the assigned message type

#### Scenario: Local schema cannot be shown

- **WHEN** the assigned file is missing or invalid
- **THEN** the schema view SHALL show the reason instead of a field structure

### Requirement: Local Schema Decoding Stays Offline And Read-Only

Using a local schema SHALL NOT add any Kafka or Schema Registry request and SHALL NOT fetch schemas from any network location. Schema file contents and message payloads SHALL NOT be written to logs.

#### Scenario: Scan with a local schema and no network to the registry

- **WHEN** a scan decodes values with a local schema on a cluster whose registry is unreachable
- **THEN** the scan SHALL make no request for the local schema and no Schema Registry request beyond those made without an assignment

#### Scenario: Read-only gate

- **WHEN** the read-only gate runs on the code base with this capability
- **THEN** it SHALL pass without a new exception
