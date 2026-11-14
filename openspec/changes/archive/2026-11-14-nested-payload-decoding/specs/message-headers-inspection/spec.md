## MODIFIED Requirements

### Requirement: Message Headers UI Display
The system SHALL render message headers in a reusable message details/inspector component that can be invoked from both the Explorer View and the Consumer Lag View. Each header value SHALL be shown with the same value viewer as the message key and payload, including tree view, hex view, search highlighting and on-demand decoding.

#### Scenario: Display headers list in reusable inspector
- **WHEN** the user inspects a message that contains headers (regardless of which view triggered the inspection)
- **THEN** the system SHALL display the headers in a structured key-value list (with UTF-8 decoding for string values, and hex fallback for binary values).

#### Scenario: JSON header value as tree
- **WHEN** a header value is a JSON object or array
- **THEN** the header SHALL show the value as a tree with the same Tree/Raw switch as the payload

#### Scenario: Binary header value in hex view
- **WHEN** a header value is the hex fallback for non-UTF-8 bytes (`0x` followed by hex digit pairs)
- **THEN** the header SHALL show those bytes in the hex view used for binary payloads
- **AND** the header's copy action SHALL copy the value exactly as received

#### Scenario: Decode a header value on demand
- **WHEN** a header value is plain text and the user chooses "Decode as Base64" on it
- **THEN** the decoded content SHALL be shown in place with a control to return to the original value

#### Scenario: Header with an empty value
- **WHEN** a header has no value
- **THEN** the header SHALL show a localized "empty value" marker instead of an empty viewer
