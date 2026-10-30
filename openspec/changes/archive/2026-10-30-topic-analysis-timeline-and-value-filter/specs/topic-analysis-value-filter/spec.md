# Spec Delta

## Purpose

Lets a user find out how often messages with a specific field value occur in a topic, how that share relates to all other messages, and how it develops over time, including for fields nested in objects and maps.

## ADDED Requirements

### Requirement: Value Filter Definition Before The Scan

Before starting an analysis the user SHALL be able to define one value filter consisting of a field path and an exact value. The field path SHALL use the canonical field-path syntax, including nested object and map paths and JSON Pointer form.

#### Scenario: Defining a filter on a nested map field

- **WHEN** the user enters the field path `attributes.region` and the value `EU` and starts the analysis
- **THEN** the scan SHALL evaluate the filter for every scanned message

#### Scenario: Field path suggestions

- **WHEN** a report is available and the user edits the filter field path
- **THEN** the system SHALL offer the field paths discovered in that report as suggestions

#### Scenario: Incomplete filter

- **WHEN** the user enters a value but no field path
- **THEN** the analysis SHALL NOT start with that filter
- **AND** the system SHALL show a localized validation message

#### Scenario: Removing the filter

- **WHEN** the user clears the filter and starts an analysis
- **THEN** the scan SHALL run without filter and the report SHALL contain no filter section

### Requirement: Exact Value Matching

A message SHALL match the filter when its decoded payload contains the field path and the field's value, rendered the same way as in the field value statistics, equals the filter value exactly (case-sensitive). A JSON `null` SHALL be rendered as `null`.

#### Scenario: String value matches

- **WHEN** the filter is `status` = `FAILED` and a message payload is `{"status":"FAILED"}`
- **THEN** the message SHALL count as a match

#### Scenario: Different case does not match

- **WHEN** the filter is `status` = `FAILED` and a message payload is `{"status":"failed"}`
- **THEN** the message SHALL NOT count as a match

#### Scenario: Number and boolean values

- **WHEN** the filter is `retries` = `3` and a payload is `{"retries":3}`, or the filter is `active` = `true` and a payload is `{"active":true}`
- **THEN** the message SHALL count as a match

#### Scenario: Null value

- **WHEN** the filter is `customerId` = `null` and a payload is `{"customerId":null}`
- **THEN** the message SHALL count as a match and as carrying the field

#### Scenario: Field absent or payload not structured

- **WHEN** a message payload does not contain the field path, is a tombstone, or cannot be decoded as structured data
- **THEN** the message SHALL NOT count as a match and SHALL NOT count as carrying the field

#### Scenario: Avro payload

- **WHEN** the topic uses Schema Registry encoded Avro values and the filter path points to a field inside a decoded record or map
- **THEN** matching SHALL be evaluated on the decoded value

### Requirement: Filter Does Not Reduce The Main Report

With an active filter the existing report sections SHALL keep describing all scanned messages. The filter result SHALL be shown in an additional "filter matches" section.

#### Scenario: Totals unchanged

- **WHEN** a scan of 100,000 messages with an active filter finds 2,500 matches
- **THEN** the total message count in the report SHALL be 100,000
- **AND** the filter matches section SHALL show 2,500

### Requirement: Filter Match Statistics

The filter matches section SHALL show the field path, the value, the match count, the share of matches among all scanned messages, and the share of matches among messages that carry the field.

#### Scenario: Shares computed

- **WHEN** 100,000 messages were scanned, 40,000 of them carry `attributes.region`, and 2,500 have the value `EU`
- **THEN** the section SHALL show 2,500 matches, 2.5 % of all scanned messages and 6.25 % of messages with the field
- **AND** it SHALL show the 97,500 non-matching messages as the remainder

#### Scenario: No matches

- **WHEN** the scan completes without any matching message
- **THEN** the section SHALL show 0 matches and 0 % instead of being hidden

#### Scenario: Live update during the scan

- **WHEN** a filtered scan is running
- **THEN** the match count and shares SHALL update together with the other partial results

### Requirement: Filter Match Timeline

The filter matches section SHALL show the matches per clock hour in the selected recent window and per day, each next to the total message count of the same hour or day and the match share in percent.

#### Scenario: Matches in recent hours

- **WHEN** a filtered scan completes and the 24-hour window is selected
- **THEN** each hour SHALL show the match count, the total count and the match share for that hour

#### Scenario: Matches per day

- **WHEN** the daily distribution is shown for a filtered report
- **THEN** each day SHALL additionally show the match count and the match share of that day

### Requirement: Value Drill-Down After The Scan

In the field value statistics the user SHALL be able to select a listed value of any field, including nested fields, and immediately see its count, its share of all scanned messages and its share of messages carrying the field, computed from the existing report without rescanning.

#### Scenario: Selecting a listed value

- **WHEN** the user selects the value `EU` of field `attributes.region` in the field value explorer
- **THEN** the system SHALL show the count, the share of all scanned messages and the share of messages with the field

#### Scenario: Approximate counts flagged

- **WHEN** the selected field's distinct-value tracking was capped during the scan
- **THEN** the shown count SHALL be labelled as approximate

### Requirement: Re-Scan With Selected Value

From a selected field value the user SHALL be able to start a new analysis that uses that field path and value as filter and the currently selected scan scope, to obtain exact counts and the match timeline.

#### Scenario: Starting the re-scan

- **WHEN** the user selects the value `FAILED` of field `status` and chooses "re-scan with this filter"
- **THEN** the filter SHALL be set to `status` = `FAILED`
- **AND** a new analysis SHALL start with the currently selected scan scope

#### Scenario: Truncated value cannot be used

- **WHEN** the selected value was shortened for display because it is too long
- **THEN** the re-scan action SHALL be unavailable
- **AND** the system SHALL explain that the value is shortened and can be entered manually

#### Scenario: Imported report of another topic

- **WHEN** the displayed report is imported and belongs to a different topic than the topic opened in the analysis view
- **THEN** the re-scan action SHALL be unavailable with a localized explanation
- **AND** the drill-down counts from the report SHALL still be shown
