## ADDED Requirements

### Requirement: Non-Blocking Payload Processing
The system MUST perform heavy processing of large message payloads (such as JSON parsing, pretty-printing, and hex formatting) off the main UI thread to prevent the application from freezing.

#### Scenario: User opens a large message
- **WHEN** the user clicks on a message containing a payload of several megabytes
- **THEN** the UI thread remains responsive while the payload is processed in the background

### Requirement: Visual Progress Indication
The system MUST provide visual feedback to the user while large payloads are being processed.

#### Scenario: Processing takes noticeable time
- **WHEN** processing a payload takes longer than a few milliseconds
- **THEN** a circular progress indicator (or similar loading state) is shown in the viewer area until processing is complete

### Requirement: Output Truncation
The system SHALL truncate the rendered output of extremely large payloads to a safe character limit to prevent the UI layout engine from crashing or hanging, while still allowing the user to copy or save the raw data.

#### Scenario: Payload exceeds display limit
- **WHEN** the formatted payload exceeds 500,000 characters
- **THEN** the display is truncated with a clear message indicating truncation, but the full raw data remains accessible via "Copy" or "Save to File" actions
