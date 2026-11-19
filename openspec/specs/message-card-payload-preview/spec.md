# message-card-payload-preview Specification

## Purpose

Defines how message payloads and structural differences are rendered inside the timeline and diff message cards so
that values are easy to read at a glance in both themes and at every text size.

## Requirements

### Requirement: Payload Preview Uses the Application Code Font

The payload preview and the key of a timeline or diff card SHALL be rendered in the same monospace font that the message
table and the inspector use, with a line height of at least 1.35, and SHALL follow the text-size setting.

#### Scenario: Same font as the table
- **WHEN** a message is shown in the table view and in the timeline view
- **THEN** its payload text SHALL use the same monospace font family in both views

#### Scenario: Larger text size
- **WHEN** the user sets the text size to "large" in the appearance settings
- **THEN** the payload preview, the key and the diff rows of the cards SHALL grow by the same factor as the rest of the UI

### Requirement: Spaced Single-Line JSON Preview

A payload preview of a JSON object or array SHALL be shown as compact JSON with one space after every `:` and `,`
outside string values, null-valued fields omitted as before, limited to three lines with an ellipsis.

#### Scenario: Minified payload
- **WHEN** a message has the payload `{"address":{"city":"Paris","zip":"75001"},"count":3}`
- **THEN** the card SHALL show `{"address": {"city": "Paris", "zip": "75001"}, "count": 3}`

#### Scenario: Commas and colons inside strings are kept
- **WHEN** a string value contains `a,b:c`
- **THEN** the preview SHALL show that value unchanged

#### Scenario: Non-JSON payload
- **WHEN** the payload is not valid JSON
- **THEN** the preview SHALL show the raw text with line breaks collapsed, without inserted spaces

### Requirement: Syntax-Tinted Preview With Full Contrast

The JSON preview SHALL distinguish keys, string values, numbers and `true`/`false`/`null` by colours taken from the
active colour scheme. Every part of the preview SHALL meet the WCAG AA contrast ratio against the card background in the
light and the dark theme, also when the card is selected. Search highlighting SHALL remain visible on top of the tint.

#### Scenario: Dark theme
- **WHEN** the dark theme is active and a timeline card shows a JSON preview
- **THEN** keys, strings, numbers and literals SHALL be visually distinguishable and each SHALL meet the AA contrast ratio against the card

#### Scenario: Selected card
- **WHEN** a card is selected and therefore drawn on the primary container colour
- **THEN** the preview text SHALL still meet the AA contrast ratio

#### Scenario: Search phrase inside a value
- **WHEN** the in-memory filter phrase occurs inside a string value of the preview
- **THEN** the matching characters SHALL be highlighted and the rest of the value SHALL keep its tint

### Requirement: Diff Rows Use Theme Colours and Readable Values

Added, removed and changed rows in a diff card SHALL take their colours from the active colour scheme, SHALL keep their
icons and the strike-through of old values so the kind of change is not conveyed by colour alone, and SHALL render the
new value of a changed row in the normal text colour of the card so it is the most legible part of the row.

#### Scenario: Changed value in the dark theme
- **WHEN** the dark theme is active and a diff card shows `status: "PENDING" ➔ "ACTIVE"`
- **THEN** the old value SHALL be struck through in the scheme's error colour, the arrow SHALL be de-emphasised and `"ACTIVE"` SHALL meet the AA contrast ratio against the card

#### Scenario: Added and removed rows
- **WHEN** a diff card shows an added and a removed field
- **THEN** the added row SHALL show an add icon and the removed row a remove icon with struck-through text, in colours from the colour scheme

#### Scenario: Theme switch
- **WHEN** the user switches between the light and the dark theme while a diff card is visible
- **THEN** the diff row colours SHALL follow the new scheme without a restart
