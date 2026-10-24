# json-path-resolution Specification

## Purpose

Defines one field-path language for extracting values from Kafka message keys and payloads, shared by table projection, script variable extraction and broker-side message filtering, so the same path always selects the same value.

## Requirements

### Requirement: Canonical Field Path Syntax

The system SHALL resolve a field path against a decoded JSON value using one path language: dot-separated object keys, array indices written as `[n]` or as a dot-separated number, an optional leading `$.`, and slash-prefixed JSON Pointer form.

#### Scenario: Nested object path resolves
- **WHEN** a path `customer.address.zipCode` is applied to a payload containing that nesting
- **THEN** the system SHALL return the value at that location as its string representation

#### Scenario: Array index resolves in both notations
- **WHEN** the path `leistungen[0].transportId` or `leistungen.0.transportId` is applied to a payload whose `leistungen` is a list
- **THEN** the system SHALL return the `transportId` of the first list entry

#### Scenario: Documented JSONPath prefix resolves
- **WHEN** a user enters the path `$.id` or `$.order.items[1].sku`
- **THEN** the system SHALL ignore the leading `$` marker and resolve the remainder of the path

#### Scenario: JSON Pointer form resolves
- **WHEN** a path starting with `/`, for example `/status/code`, is applied
- **THEN** the system SHALL treat it as a JSON Pointer and return the referenced value

#### Scenario: Unresolvable path yields no value
- **WHEN** a path does not exist in the payload, or the payload is not valid JSON, or the path is empty
- **THEN** the system SHALL return no value instead of raising an error to the user
- **AND** the caller SHALL render that as an empty result (empty cell, no variable, no match)

### Requirement: One Resolver For All Field Path Features

Message-table projected columns, script variable extraction and broker-side field filtering SHALL apply the same path semantics to the same payload, so a path that resolves in one feature resolves identically in the others.

#### Scenario: Same path in a projected column and in a filter
- **WHEN** the user filters a scan by field `order.trackingId` and then adds a projected column with the same path
- **THEN** every returned message SHALL show in that column the same value the filter matched

#### Scenario: Array index works in script extraction
- **WHEN** a script extraction is configured with path `items[0].sku`
- **THEN** the extracted variable SHALL hold the same value as a projected column configured with that path on the same message

#### Scenario: Source selection is honored
- **WHEN** an extraction or a filter is configured with source `KEY` instead of `VALUE`
- **THEN** the system SHALL resolve the path against the message key representation only

### Requirement: Path Input Guidance Matches Accepted Syntax

Path input fields and their hints SHALL state a syntax the resolver accepts, in the active UI language, so a user-entered example resolves.

#### Scenario: Example path from the hint resolves
- **WHEN** a user copies the path shown in the hint of an extraction or projected-column input into that input
- **THEN** the system SHALL resolve the example path against a payload that contains the corresponding field

#### Scenario: Hint is localized
- **WHEN** the application runs in German
- **THEN** the path hint SHALL be shown in German and keep the same path examples
