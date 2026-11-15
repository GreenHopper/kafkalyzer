# schema-subject-browser Specification

## Purpose

Lets users find and open any Schema Registry subject of the connected cluster from inside the Explorer, including
subjects that do not follow the `<topic>-key` / `<topic>-value` naming, and see which topic each subject belongs to.

## Requirements

### Requirement: Subject List Inside the Explorer

While a cluster is connected, the Explorer sidebar SHALL offer a switch between the topic list and a subject list. The subject list SHALL be part of the Explorer; no navigation destination SHALL be added. The switch SHALL be keyboard reachable and labelled for screen readers.

#### Scenario: Switching to subjects
- **WHEN** the user is connected to a cluster with a configured Schema Registry and selects "Subjects" in the sidebar switch
- **THEN** the sidebar SHALL show the subject list of that cluster in place of the topic list
- **AND** the navigation rail SHALL still show exactly Explorer, Consumer Lag, Scripts and Settings

#### Scenario: Switching back to topics
- **WHEN** the user selects "Topics" in the sidebar switch
- **THEN** the topic list SHALL be shown again with its previous filter text

#### Scenario: Cluster without Schema Registry
- **WHEN** the connected cluster has no Schema Registry URL configured and the user selects "Subjects"
- **THEN** the sidebar SHALL state that no Schema Registry is configured and offer an action to open the cluster settings
- **AND** it SHALL NOT show an empty subject list

### Requirement: Searchable Subject List

The subject list SHALL show all subjects returned by the registry, sorted by name, filterable by a case-insensitive substring, and SHALL show how many subjects match out of the total. The list SHALL stay responsive for at least 10 000 subjects and SHALL reuse the subject list already loaded for the cluster instead of requesting it again.

#### Scenario: Filtering subjects
- **WHEN** the registry returns subjects `orders-value`, `orders-key`, `com.acme.Customer` and the user types `ORDER`
- **THEN** the list SHALL show `orders-key` and `orders-value`
- **AND** a counter SHALL show 2 of 3 subjects

#### Scenario: Subject list already loaded
- **WHEN** the subjects of the cluster were loaded at connect time and the user opens the subject list
- **THEN** no additional subject list request SHALL be sent

#### Scenario: Refresh
- **WHEN** the user activates the refresh action of the subject list
- **THEN** the subject list SHALL be requested again, the previous list SHALL stay visible while loading, and a loading indicator SHALL be shown

#### Scenario: No matching subject
- **WHEN** the filter matches no subject
- **THEN** the list SHALL state that no subject matches the filter, distinct from "the registry has no subjects"

### Requirement: Subject List Load Failures

A failed subject list request SHALL be shown as an error state that names the cause (for example credentials rejected, access denied, timeout, unreachable) and offers "Retry". A failure SHALL NOT be shown as an empty registry.

#### Scenario: Registry rejects the credentials
- **WHEN** loading the subject list returns HTTP 401
- **THEN** the subject list SHALL show a localized message that the Schema Registry rejected the credentials, the status code, and a "Retry" action

#### Scenario: Registry unreachable
- **WHEN** the registry does not answer within the request timeout
- **THEN** the subject list SHALL show a timeout error with "Retry"
- **AND** the subject count SHALL be shown as unknown, not as 0

#### Scenario: Failed refresh with an earlier list
- **WHEN** a refresh fails while an earlier subject list is shown
- **THEN** the earlier list SHALL stay visible with an inline error and "Retry"

### Requirement: Associated Topic per Subject

Each subject row SHALL show the topic derived from the subject name (`<topic>-key` or `<topic>-value`) and whether it is key or value, or that no topic can be derived. Association SHALL be computed once per change of the subject or topic list, not once per row.

#### Scenario: Convention-based subject
- **WHEN** the subject list contains `orders-value` and the cluster has topic `orders`
- **THEN** the row SHALL show topic `orders` and the value marker

#### Scenario: Subject without topic in its name
- **WHEN** the subject list contains `com.acme.Customer`
- **THEN** the row SHALL show that no topic is associated by name
- **AND** the subject SHALL still be listed and openable

#### Scenario: Topic list not available
- **WHEN** the topic list of the cluster failed to load or is still loading
- **THEN** the derived topic SHALL still be shown, marked as not verified against the topic list

### Requirement: Global Compatibility Level in the Subject List

The subject list header SHALL show the registry's global compatibility level. If it cannot be read, it SHALL be shown as unknown together with the reason.

#### Scenario: Global level readable
- **WHEN** the registry reports the global compatibility level `BACKWARD`
- **THEN** the subject list header SHALL show `BACKWARD` as the global compatibility

#### Scenario: Global level not readable
- **WHEN** reading the global compatibility level returns HTTP 403
- **THEN** the header SHALL show the global compatibility as unknown with an "access denied" hint
- **AND** the subject list itself SHALL still be shown

### Requirement: Open a Subject in the Schema Inspector

Activating a subject SHALL open the schema inspector for that subject at its latest version, with version selection, version comparison, type, identity, references, compatibility level and the associated topics. An associated topic SHALL be openable as a topic tab when it exists on the connected cluster.

#### Scenario: Open a subject that does not follow topic naming
- **WHEN** the user activates subject `com.acme.Customer`
- **THEN** the schema inspector SHALL open for `com.acme.Customer` at its latest version
- **AND** the version selector SHALL list all versions of the subject

#### Scenario: Open the associated topic
- **WHEN** the inspector of `orders-value` is open and the user activates the associated topic `orders`, which exists on the cluster
- **THEN** the inspector SHALL close and the Explorer SHALL open topic `orders` in a tab with its real metadata

#### Scenario: Subject can no longer be loaded
- **WHEN** the user activates a subject that was deleted after the list was loaded
- **THEN** the inspector SHALL show the not-found error with "Retry" instead of an empty schema

### Requirement: Subject Browsing Stays Read-Only

Listing, filtering and opening subjects SHALL only read from the Schema Registry with GET requests. It SHALL NOT register, delete or change subjects, schemas, compatibility or mode, and SHALL NOT send any Kafka request other than the topic metadata the Explorer already loads.

#### Scenario: Browsing subjects
- **WHEN** the user lists, filters and opens subjects and switches versions
- **THEN** every request sent to the Schema Registry SHALL be a GET request
- **AND** no subject, schema or registry setting SHALL be created or changed
