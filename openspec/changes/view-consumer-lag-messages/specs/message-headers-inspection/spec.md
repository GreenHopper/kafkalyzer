## MODIFIED Requirements

### Requirement: Message Headers UI Display
The system SHALL render message headers in a reusable message details/inspector component that can be invoked from both the Explorer View and the Consumer Lag View.

#### Scenario: Display headers list in reusable inspector
- **WHEN** the user inspects a message that contains headers (regardless of which view triggered the inspection)
- **THEN** the system SHALL display the headers in a structured key-value list (with UTF-8 decoding for string values, and hex fallback for binary values).
