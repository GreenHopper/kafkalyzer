# topic-config-inspection Specification

## Purpose

Lets users read the full configuration of a Kafka topic and compare the configurations of two topics, within one
cluster profile or across two saved profiles, without ever changing configuration or revealing sensitive values.

## Requirements

### Requirement: Full Topic Configuration View

The topic detail view SHALL offer a configuration mode that lists every configuration entry the cluster reports for
the topic, each with its name, current value, source and whether it is a default. Entries SHALL be ordered by name
ascending so the order is stable across loads and clusters. The configuration SHALL be read when the mode is opened
or refreshed, not for the whole topic list.

#### Scenario: Open the configuration mode
- **WHEN** the user opens a topic and switches to the configuration mode
- **THEN** the system SHALL show a loading indicator while reading the configuration
- **AND** then list every reported entry with name, value, source and default marker, sorted by name

#### Scenario: Stable order on refresh
- **WHEN** the user refreshes the configuration of the same topic
- **THEN** the entries SHALL appear in the same name order as before

#### Scenario: Entry without a value
- **WHEN** the cluster reports an entry that is not sensitive and has no value
- **THEN** the entry SHALL be shown as having no value, distinct from an unknown or hidden value

#### Scenario: Source not reported by the broker
- **WHEN** the broker does not report where an entry's value comes from
- **THEN** the source SHALL be shown as unknown, never as default

### Requirement: Configuration Source Labels

Each entry's source SHALL be shown as one of: topic override, dynamic broker setting, dynamic cluster-wide broker
default, static broker setting, built-in default, or unknown.

#### Scenario: Topic-level override
- **WHEN** an entry was set on the topic itself
- **THEN** its source SHALL be shown as a topic override and it SHALL NOT be marked as default

#### Scenario: Built-in default
- **WHEN** an entry has the cluster's built-in default value
- **THEN** its source SHALL be shown as built-in default and it SHALL be marked as default

### Requirement: Sensitive Values Are Never Shown

Entries the cluster marks as sensitive SHALL be listed by name and source only. Their values SHALL NOT be shown,
copied, logged, compared or passed to the user interface layer in any form, including partial or hashed forms.

#### Scenario: Sensitive entry in the list
- **WHEN** the configuration contains an entry marked as sensitive
- **THEN** the entry SHALL be shown with a localized "hidden (sensitive)" placeholder instead of a value

#### Scenario: Sensitive entry in copied text
- **WHEN** the user copies the configuration or a comparison that contains a sensitive entry
- **THEN** the copied text SHALL contain the placeholder and not the value

### Requirement: Non-Default Filter

The configuration view SHALL offer a toggle that hides entries marked as default, so only overrides and broker-level
settings remain. The toggle SHALL NOT trigger a new read.

#### Scenario: Show only non-defaults
- **WHEN** the user enables the non-default toggle in the configuration view
- **THEN** only entries not marked as default SHALL remain visible, in the same order

#### Scenario: Nothing left after filtering
- **WHEN** the toggle is enabled and every entry is a default
- **THEN** the view SHALL say that all entries use default values instead of showing an empty table

### Requirement: Unreadable Configuration Is Reported

If the configuration cannot be read, the view SHALL say why: missing permission (shown as "not readable — missing
DescribeConfigs permission?"), topic not found, or another failure with its error message. It SHALL offer a retry
and SHALL NOT show an empty list or assumed values.

#### Scenario: Missing DescribeConfigs permission
- **WHEN** the cluster rejects the configuration request for the topic as not authorized
- **THEN** the view SHALL show the "not readable — missing DescribeConfigs permission?" state with a retry action
- **AND** no entries SHALL be shown

#### Scenario: Topic no longer exists
- **WHEN** the topic does not exist on the cluster anymore
- **THEN** the view SHALL show that the topic was not found

#### Scenario: Cluster unreachable or request timed out
- **WHEN** the configuration request fails because the cluster cannot be reached or does not answer in time
- **THEN** the view SHALL show the failure with its error message and a retry action within a bounded time

### Requirement: Compare Two Topic Configurations

The user SHALL be able to compare the configuration of the open topic with a second topic, in the same cluster
profile or in another saved profile, without switching or disconnecting the active connection. The second topic
SHALL default to the open topic's name.

#### Scenario: Same topic name in another profile
- **WHEN** the user starts a comparison, selects another saved profile and keeps the suggested topic name
- **THEN** the system SHALL read both configurations and show them side by side, labelled with profile and topic
- **AND** the active connection and its open tabs SHALL remain unchanged

#### Scenario: Two topics in the same profile
- **WHEN** the user selects the current profile and a different topic name
- **THEN** the system SHALL compare the two topics of that cluster

#### Scenario: Comparison in progress
- **WHEN** a comparison is being read
- **THEN** each side SHALL show its own loading state, and a side that finishes first SHALL NOT be shown as a full result

### Requirement: Difference Classification

Each config name present on either side SHALL appear once, ordered by name ascending, classified as equal, different,
only on the left, only on the right, not comparable (sensitive) or unknown (the other side is unreadable). Only
different, only-left and only-right SHALL count as differences.

#### Scenario: Different values
- **WHEN** both sides are readable and a non-sensitive entry has different values
- **THEN** the row SHALL be marked as different and counted in the number of differences

#### Scenario: Same value, different source
- **WHEN** both sides have the same value but one side is an override and the other a default
- **THEN** the row SHALL be marked as equal and both sources SHALL be shown

#### Scenario: Entry reported on one side only
- **WHEN** both sides are readable and an entry is reported only by one cluster
- **THEN** the row SHALL be marked as present on that side only and counted as a difference

#### Scenario: Sensitive entry on either side
- **WHEN** an entry is marked as sensitive on at least one side
- **THEN** the row SHALL be marked as not comparable and SHALL NOT be counted as a difference

### Requirement: Unreadable Comparison Side Is Not a Difference

If one side of a comparison cannot be read, that side SHALL show the same unreadable state as the single-topic view.
The readable side's entries SHALL be shown with the other side as unknown, and none of them SHALL be counted as a
difference.

#### Scenario: Second profile lacks DescribeConfigs
- **WHEN** the configuration of the second side is rejected as not authorized
- **THEN** that side SHALL show "not readable — missing DescribeConfigs permission?"
- **AND** the rows SHALL show the first side's values with the second side as unknown
- **AND** the number of differences SHALL be shown as unknown, not as zero

#### Scenario: Both sides unreadable
- **WHEN** neither side can be read
- **THEN** both sides SHALL show their unreadable state with retry and no rows SHALL be shown

#### Scenario: Retry one side
- **WHEN** the user retries the failed side and it succeeds
- **THEN** the comparison SHALL be recomputed with both sides without reading the successful side again

### Requirement: Differences and Non-Defaults Filter

The comparison SHALL offer a toggle "only differences and non-defaults" that keeps rows counted as differences plus
rows where at least one readable side is not a default, in unchanged order, without a new read.

#### Scenario: Filter identical defaults away
- **WHEN** the toggle is enabled and a row is equal with both sides marked as default
- **THEN** the row SHALL be hidden

#### Scenario: Equal override stays visible
- **WHEN** the toggle is enabled and a row is equal but one side is an override
- **THEN** the row SHALL remain visible

#### Scenario: No differences
- **WHEN** both sides are readable, the toggle is enabled and no row remains
- **THEN** the view SHALL state that the configurations do not differ and use only defaults

### Requirement: Comparison Respects Profile Security Settings

A comparison side read through a profile other than the active one SHALL use that profile's stored credentials and
TLS verification setting. A profile whose TLS verification is disabled SHALL be marked insecure on its side. A
profile whose verification transition is undecided SHALL be read only with verification, without changing its state.

#### Scenario: Insecure profile as comparison side
- **WHEN** the user selects a profile with TLS verification disabled as the second side
- **THEN** the profile picker and that side's header SHALL show the insecure marker

#### Scenario: Undecided profile rejected by verification
- **WHEN** the selected profile's transition is undecided and its broker certificate is rejected
- **THEN** that side SHALL show the verification failure as an error
- **AND** the profile's verification state SHALL remain undecided and no unverified connection SHALL be made

#### Scenario: Environment label shown
- **WHEN** a side's profile has an environment label
- **THEN** that side's header SHALL show the label

### Requirement: Copy Configuration as Text

The user SHALL be able to copy the visible configuration or comparison, including the active filter, as plain text with
one line per entry. The text SHALL contain profile and topic names, name, values and sources, mark unknown values as
unknown and sensitive values with the placeholder.

#### Scenario: Copy filtered comparison
- **WHEN** the user copies a comparison with the differences filter enabled
- **THEN** the clipboard SHALL contain only the visible rows in the visible order, with both profile and topic names in a header

#### Scenario: Copy with an unreadable side
- **WHEN** the user copies a comparison whose second side is unreadable
- **THEN** the text SHALL state that side's unreadable reason and show its values as unknown

### Requirement: Configuration Inspection Stays Read-Only

Reading and comparing topic configurations SHALL only issue describe-configuration requests for the selected topics.
It SHALL NOT alter configuration, create or delete topics, join consumer groups or contact the Schema Registry.

#### Scenario: Comparison across profiles
- **WHEN** the user compares a topic across two profiles
- **THEN** exactly one describe-configuration request per side SHALL be sent and no mutating admin request SHALL be sent

#### Scenario: Read-only gate
- **WHEN** the read-only CI gate runs on the source tree containing this capability
- **THEN** the gate SHALL pass without a new exception
