# topic-report-comparison Specification

## Purpose

Compares two saved topic analysis reports so a user can see what changed in a topic between two scan moments without re-running either scan.

## Requirements

### Requirement: Select Two Reports To Compare

The system SHALL let the user pick two analysis reports as the comparison pair, where each side is either the currently loaded live analysis or a previously imported report file.

#### Scenario: Compare live analysis with an imported report

- **WHEN** the user has a live analysis loaded and selects an imported report as the comparison base
- **THEN** the system SHALL show both reports side by side
- **AND** each side SHALL be labeled with its topic, scan moment and whether it is live or imported

#### Scenario: Compare two imported reports

- **WHEN** the user selects two imported report files as the pair
- **THEN** the system SHALL show the comparison without connecting to any cluster

#### Scenario: Only one report available

- **WHEN** the user opens the comparison action while only one report is available
- **THEN** the system SHALL prompt for the second report instead of showing a partial comparison

### Requirement: Comparable Reports Only

The system SHALL compare reports of the same topic only, and SHALL reject a pair whose topics differ with a localized message that names both topics.

#### Scenario: Mismatched topics rejected

- **WHEN** the user pairs a report of topic `orders` with a report of topic `shipments`
- **THEN** the system SHALL refuse the comparison
- **AND** the message SHALL name both topic names

#### Scenario: Same topic, different clusters

- **WHEN** the user pairs two reports of the same topic recorded on different clusters
- **THEN** the comparison SHALL be shown
- **AND** each side SHALL display its cluster name

### Requirement: Per-Metric Comparison With Deltas

The system SHALL show, for each available aggregate metric, the value of both reports and the absolute and relative difference between them, including message volume, payload size statistics, tombstone count and partition balance.

#### Scenario: Volume growth

- **WHEN** report A holds 100000 messages and report B holds 120000 messages for the same topic
- **THEN** the comparison SHALL show 100000 and 120000 with a difference of +20000 (+20 %)

#### Scenario: Metric present on one side only

- **WHEN** one report contains a metric the other does not provide
- **THEN** the system SHALL show the available value and mark the metric as not comparable
- **AND** the remaining metrics SHALL still be compared

#### Scenario: Structure changes listed

- **WHEN** a field appears in the field frequency summary of one report but not the other
- **THEN** the comparison SHALL list that field as added or removed
- **AND** fields present in both SHALL show their count difference

### Requirement: Older Report Files Stay Comparable

Reports written by an earlier application version SHALL remain comparable, with metrics that the older file does not contain marked as unavailable rather than treated as zero.

#### Scenario: Report without size percentiles

- **WHEN** the user pairs a report file that contains no message size percentile values
- **THEN** the comparison SHALL mark the percentile rows as not available for that side
- **AND** the message count, byte total and other shared metrics SHALL be compared normally
