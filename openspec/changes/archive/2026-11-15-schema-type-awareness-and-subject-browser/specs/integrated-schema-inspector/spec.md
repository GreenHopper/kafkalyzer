## RENAMED Requirements

- FROM: `### Requirement: Key and Value Avro Schema Display and Search`
- TO: `### Requirement: Key and Value Schema Display and Search`

## MODIFIED Requirements

### Requirement: Key and Value Schema Display and Search
The integrated schema inspector SHALL render both the Key schema (`<topic>-key`) and Value schema (`<topic>-value`) of Avro, JSON Schema and Protobuf subjects with simplified field structures, data types, documentation strings, and in-schema search capabilities.

#### Scenario: Inspecting Key and Value schemas
- **WHEN** a topic has both Key and Value schemas registered in Schema Registry
- **THEN** the inspector SHALL display collapsible sections or cards for both `Key Schema` and `Value Schema`
- **AND** complex records, primitive types, optional fields (`[null, type]`), enums, and unions SHALL be rendered in human-readable formatting

#### Scenario: Inspecting a JSON Schema value
- **WHEN** the value subject of a topic is a JSON Schema with properties `id` (integer) and `customer` (object with property `name`)
- **THEN** the inspector SHALL show fields `id` and `customer` with their types and the nested field `name` under `customer`
- **AND** it SHALL NOT show the schema as the single word `object`

#### Scenario: Inspecting a Protobuf value
- **WHEN** the value subject of a topic is a proto3 Protobuf schema whose first message has fields `id` (int64) and repeated `items` (message `Item`)
- **THEN** the inspector SHALL show fields `id` and `items` with their types, mark `items` as repeated, and show the fields of `Item` under `items`

#### Scenario: Schema that cannot be shown as fields
- **WHEN** a schema cannot be parsed into fields, for example a proto2 Protobuf schema or invalid schema text
- **THEN** the inspector SHALL show the schema text together with a notice naming why no field structure is available
- **AND** the failure SHALL NOT be hidden

#### Scenario: In-schema text search and match stepper navigation
- **WHEN** the user enters a search term in the schema search bar
- **THEN** matching field names, types, and docstrings SHALL be highlighted across Key and Value schemas
- **AND** the search bar SHALL display the match count in format `current/total`
- **AND** stepper controls (`Previous match` / `Next match`) SHALL scroll to and focus matches sequentially

## ADDED Requirements

### Requirement: Type-Neutral Schema Empty and Error States
The schema inspector SHALL present clear, informative, non-blocking empty states and error diagnostics when schemas are absent or inaccessible.

#### Scenario: Topic without registered schemas
- **WHEN** a connected cluster has Schema Registry configured but no subject exists for `<topic>-key` or `<topic>-value`
- **THEN** the inspector SHALL display an empty state stating that no schema is registered for this topic under these subject names, without naming a schema type
- **AND** the user SHALL be able to switch back to other view modes freely

#### Scenario: Cluster without configured Schema Registry
- **WHEN** the active cluster profile does not have a Schema Registry URL configured
- **THEN** the inspector SHALL display an empty state informing that Schema Registry is not configured for this cluster
- **AND** SHALL provide an action button to open cluster settings

#### Scenario: Schema Registry connection error
- **WHEN** fetching schemas fails due to network or authentication errors
- **THEN** the inspector SHALL display the error message and provide a `Retry` action button

#### Scenario: Registry denies access
- **WHEN** fetching a schema returns HTTP 401 or 403
- **THEN** the inspector SHALL state in localized text that the Schema Registry rejected the credentials (401) or denied access (403), including the status code
- **AND** it SHALL NOT state that no schema is registered


### Requirement: Schema Type and Identity Display

For every schema it shows, the inspector SHALL display the schema type (Avro, JSON Schema or Protobuf), the subject, the version and the schema id. A schema without an explicit type from the registry SHALL be treated as Avro. A type the application does not know SHALL be shown by its registry name and marked as unsupported.

#### Scenario: Protobuf value schema
- **WHEN** the registry returns subject `orders-value` version 3 with id 77 and type `PROTOBUF`
- **THEN** the value section SHALL show type Protobuf, version 3 and id 77

#### Scenario: Registry answer without type
- **WHEN** the registry answer for a subject version contains no schema type
- **THEN** the inspector SHALL show the type Avro

#### Scenario: Unknown schema type
- **WHEN** the registry returns a schema type the application does not support
- **THEN** the inspector SHALL show that type name, mark it as unsupported, and show the schema text without a field structure

### Requirement: Schema References

The inspector SHALL list the references of a schema with their name, subject and version, and activating a reference SHALL open the referenced subject at that version in the inspector. Fields defined in a referenced schema SHALL be shown in the field structure when the reference can be loaded.

#### Scenario: Open a referenced subject
- **WHEN** schema `orders-value` version 5 references `customer.proto` from subject `customer-value` version 2 and the user activates that reference
- **THEN** the inspector SHALL show subject `customer-value` at version 2

#### Scenario: Fields from a reference
- **WHEN** a field of `orders-value` has a type defined in the referenced schema `customer-value` version 2
- **THEN** the field structure SHALL show the fields of that type under the referencing field

#### Scenario: Reference cannot be loaded
- **WHEN** a referenced subject version cannot be loaded
- **THEN** the referencing field SHALL be marked as an unresolved reference naming the reference and the reason
- **AND** all other fields SHALL still be shown

### Requirement: Type-Correct Field Paths

Field paths offered by the inspector and by field suggestions SHALL follow the schema type and SHALL use the canonical field path grammar. Recursive types SHALL be listed once and marked as recursive. If the field structure was cut at a limit, this SHALL be stated.

#### Scenario: Pin a Protobuf field as column
- **WHEN** the user activates `Pin as Table Column` on field `name` nested under field `customer` of a Protobuf schema
- **THEN** the path `customer.name` SHALL be added to the projected table columns

#### Scenario: Field suggestions for a JSON Schema topic
- **WHEN** the value schema of a topic is a JSON Schema with property `customer` containing `name` and the user opens the field suggestions of the search bar
- **THEN** the suggestions SHALL contain `customer` and `customer.name`

#### Scenario: Recursive schema
- **WHEN** an Avro record `Node` has a field `children` of type array of `Node`
- **THEN** the field structure SHALL show `children` once, marked as recursive, and SHALL NOT expand it again

#### Scenario: Field suggestions unavailable
- **WHEN** the schema of a topic cannot be loaded for field suggestions
- **THEN** the field input SHALL keep accepting typed paths and the failure SHALL be logged

### Requirement: Type-Correct Schema Labels

The topic header and the sidebar topic tooltip SHALL name the schema type of the topic's key and value subjects when it is known, show a neutral "Schema" label while it is not loaded, and show the schema as unknown when the registry could not be read. A type SHALL NOT be shown that was not reported by the registry.

#### Scenario: Protobuf topic header
- **WHEN** the user opens topic `orders` whose value subject is a Protobuf schema
- **THEN** the topic header schema tag SHALL read Protobuf and SHALL NOT read Avro

#### Scenario: Key and value of different types
- **WHEN** the key subject is Avro and the value subject is JSON Schema
- **THEN** the schema tag SHALL name both types with their side

#### Scenario: Type not yet loaded
- **WHEN** the sidebar tooltip of a topic with a registered subject is shown before that subject was loaded
- **THEN** the tooltip SHALL show a schema indicator without a type

#### Scenario: Subject list failed
- **WHEN** the subject list of the cluster could not be loaded
- **THEN** the topic header SHALL show the schema state as unknown instead of omitting the schema tag

### Requirement: Copy and Save Schema Text

For every schema it shows, the inspector SHALL offer copying the schema text to the clipboard and saving it to a file chosen by the user, with a file name derived from subject and version and an extension matching the type (`.avsc`, `.json`, `.proto`).

#### Scenario: Copy schema text
- **WHEN** the user activates "Copy schema" on the value schema
- **THEN** the exact schema text returned by the registry SHALL be placed on the clipboard and a confirmation SHALL be shown

#### Scenario: Save a Protobuf schema
- **WHEN** the user activates "Save schema" on subject `orders-value` version 3 of type Protobuf
- **THEN** a save dialog SHALL propose the file name `orders-value-v3.proto`
- **AND** after saving, the completion affordance with open actions SHALL be shown

#### Scenario: Save cancelled or failed
- **WHEN** the user cancels the save dialog or writing the file fails
- **THEN** no success message SHALL be shown, and a write failure SHALL be reported as an error

### Requirement: Schema Inspection Stays Read-Only

Loading schemas, versions, references and compatibility levels for the inspector SHALL only use GET requests against the Schema Registry. The compatibility check of a draft schema remains the only non-GET request and SHALL store nothing.

#### Scenario: Inspecting a schema with references
- **WHEN** the user opens a schema with references and switches versions
- **THEN** every request sent to the Schema Registry SHALL be a GET request
- **AND** no subject, schema or registry setting SHALL be created or changed

## REMOVED Requirements

### Requirement: Graceful Schema Empty and Error States
**Reason**: Its scenario "Topic without registered Avro schemas" names Avro for topics of every schema type (finding B10), and a MODIFIED block cannot drop or rename that scenario.
**Migration**: Replaced by "Type-Neutral Schema Empty and Error States", which keeps the no-registry and connection-error scenarios unchanged, makes the empty state type-neutral, and adds the 401/403 scenario.
