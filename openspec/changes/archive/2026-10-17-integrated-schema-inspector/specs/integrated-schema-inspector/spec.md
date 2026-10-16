# Spec Delta

## Purpose

Provides non-blocking, integrated Avro schema inspection directly within Kafka topic and message views, replacing blocking modal dialogs with dedicated embedded tabs, real-time in-schema search, and one-click field actions for table column projection and search filtering.

## ADDED Requirements

### Requirement: Non-Blocking Schema Inspection View Mode
The topic message exploration interface (`MessagesView` inside `TopicDetailView`) SHALL provide a dedicated, non-blocking `Schema` view mode accessible alongside `Table`, `Timeline`, and `Diff` view modes via `ViewModeSwitcher`.

#### Scenario: Switching to Schema view mode in Topic Explorer
- **WHEN** the user selects the `Schema` view mode button in the message view mode switcher
- **THEN** the main content area SHALL render the embedded `TopicSchemaInspectorView`
- **AND** the topic search bar, stream controls, and progress indicators SHALL remain fully visible, operational, and non-obscured
- **AND** no modal dialog SHALL be displayed

#### Scenario: Header schema button activates integrated view mode
- **WHEN** the user clicks the `[Schema]` button in the `TopicDetailView` header
- **THEN** the active view mode in `MessagesView` SHALL switch to `Schema` without displaying a modal dialog

### Requirement: Key and Value Avro Schema Display and Search
The integrated schema inspector SHALL render both the Key schema (`<topic>-key`) and Value schema (`<topic>-value`) with simplified record structures, data types, documentation strings, and in-schema search capabilities.

#### Scenario: Inspecting Key and Value schemas
- **WHEN** a topic has both Key and Value schemas registered in Schema Registry
- **THEN** the inspector SHALL display collapsible sections or cards for both `Key Schema` and `Value Schema`
- **AND** complex records, primitive types, optional fields (`[null, type]`), enums, and unions SHALL be rendered in human-readable formatting

#### Scenario: In-schema text search and match stepper navigation
- **WHEN** the user enters a search term in the schema search bar
- **THEN** matching field names, types, and docstrings SHALL be highlighted across Key and Value schemas
- **AND** the search bar SHALL display the match count in format `current/total`
- **AND** stepper controls (`Previous match` / `Next match`) SHALL scroll to and focus matches sequentially

### Requirement: Interactive Schema Field Actions
Each field in the schema definition tree SHALL provide direct one-click action buttons to pin the field as a message table column and to filter search queries by that field.

#### Scenario: Pinning a schema field directly as a projected table column
- **WHEN** the user views a topic's schema in the inspector
- **AND** activates the `Pin as Table Column` action on a schema field row
- **THEN** the clean, normalized field path SHALL be added to the topic's projected table columns
- **AND** the message table SHALL display the projected column when the user switches to Table view, even if no messages have been consumed yet
- **AND** a confirmation SnackBar SHALL notify the user of the pinned column

#### Scenario: Filtering by a schema field
- **WHEN** the user views a topic's schema in the inspector
- **AND** activates the `Filter by this Field` action on a schema field row
- **THEN** the normalized field path SHALL be populated into the `Field (Opt.)` input of `TopicSearchBar`
- **AND** a confirmation feedback SHALL inform the user that the field filter has been configured

#### Scenario: Clean field path normalization
- **WHEN** a field path from a simplified Avro schema tree contains type descriptors (such as `fieldName : String` or `subRecord : Record`)
- **THEN** the system SHALL extract the bare field identifier (e.g. `fieldName` or `subRecord`)
- **AND** nested hierarchical paths SHALL be formatted as dot-delimited paths (e.g. `order.customer.id`) compatible with JSON payload extraction and search filters

### Requirement: Graceful Schema Empty and Error States
The schema inspector SHALL present clear, informative, non-blocking empty states and error diagnostics when schemas are absent or inaccessible.

#### Scenario: Topic without registered Avro schemas
- **WHEN** a connected cluster has Schema Registry configured but no subject exists for `<topic>-key` or `<topic>-value`
- **THEN** the inspector SHALL display an empty state stating that no Avro schema is registered for this topic
- **AND** the user SHALL be able to switch back to other view modes freely

#### Scenario: Cluster without configured Schema Registry
- **WHEN** the active cluster profile does not have a Schema Registry URL configured
- **THEN** the inspector SHALL display an empty state informing that Schema Registry is not configured for this cluster
- **AND** SHALL provide an action button to open cluster settings

#### Scenario: Schema Registry connection error
- **WHEN** fetching schemas fails due to network or authentication errors
- **THEN** the inspector SHALL display the error message and provide a `Retry` action button
