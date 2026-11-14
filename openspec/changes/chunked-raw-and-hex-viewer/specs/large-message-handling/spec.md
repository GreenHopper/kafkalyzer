# Spec Delta: large-message-handling

## ADDED Requirements

### Requirement: Virtualized Raw Text Rendering
The Raw view SHALL display text payloads of any size completely, without a fixed character cap. It SHALL lay out only the rows near the viewport, and each displayed row SHALL hold a bounded number of characters even when the payload has no line breaks. Row boundaries SHALL be computed off the UI thread.

#### Scenario: Payload larger than the former display limit
- **WHEN** the user opens a text payload of 20 MB in the Raw view
- **THEN** the viewer shows the payload without a truncation notice
- **AND** the user can scroll to the last character of the payload

#### Scenario: Single line without line breaks
- **WHEN** the payload is a 2 MB single line (for example minified JSON)
- **THEN** the viewer splits it into display rows of bounded length that appear one after another, wrapped
- **AND** no character is lost or duplicated at row boundaries

#### Scenario: UI stays responsive while scrolling a huge payload
- **WHEN** the user scrolls or jumps within a 20 MB payload in the Raw view
- **THEN** each frame lays out only the rows near the viewport, and no frame lays out the whole payload

#### Scenario: Row computation fails
- **WHEN** computing the display rows fails
- **THEN** the viewer shows an inline error instead of an empty or partial payload
- **AND** copying the complete payload remains available

### Requirement: Virtualized Hex Rendering
The Hex view SHALL display binary payloads of any size completely, as rows of 16 bytes with offset, hex and printable-character columns, without a fixed character cap. Only rows near the viewport SHALL be formatted and laid out.

#### Scenario: Large binary payload
- **WHEN** the user opens a 20 MB binary payload
- **THEN** the Hex view shows no truncation notice
- **AND** scrolling to the end shows the last row with the correct byte offset

#### Scenario: Empty binary payload
- **WHEN** the binary payload contains no bytes
- **THEN** the Hex view shows the empty-binary-data placeholder

### Requirement: Complete Raw Data Copy
Copying from the Raw or Hex view SHALL put the complete data on the clipboard regardless of payload size: the unchanged raw payload text for Raw, and the complete formatted hex dump for Hex. Virtualised display SHALL NOT shorten or change copied data.

#### Scenario: Copy a large raw payload
- **WHEN** the user activates Copy in the viewer for a payload larger than 500,000 characters
- **THEN** the clipboard contains the full payload text, character for character

#### Scenario: Copy a large hex dump
- **WHEN** the user activates "Copy Full Hex Dump" for a large binary payload
- **THEN** the hex dump is generated off the UI thread
- **AND** the clipboard contains the dump of every byte of the payload

### Requirement: Off-Thread Raw Search
Searching in the Raw view SHALL find match positions off the UI thread and SHALL NOT render the full payload as one text element to highlight matches. While the search runs, the match count SHALL be shown as running, not as "no matches". A failed search SHALL be shown as failed.

#### Scenario: Search a large payload
- **WHEN** the user searches for a phrase in a 20 MB payload in the Raw view
- **THEN** the UI stays responsive while matches are computed
- **AND** once finished, visible matches are highlighted and the total count is shown

#### Scenario: Search still running
- **WHEN** the match computation has not finished yet
- **THEN** the search bar shows a running state instead of "No matches" or a stale count

#### Scenario: Query changes during a search
- **WHEN** the user changes the query before the previous search finishes
- **THEN** only the result of the latest query is shown

#### Scenario: Search fails
- **WHEN** the match computation fails
- **THEN** the search bar shows that the search failed instead of "No matches"

#### Scenario: Jump to a match far down the payload
- **WHEN** the focused match is near the end of a 20 MB payload in the Raw view
- **THEN** the Raw view scrolls so that the row with the focused match is visible and highlighted as focused

### Requirement: Bounded Raw Search Results
The Raw view search SHALL keep at most a fixed maximum number of match positions per payload and query. When this limit is reached, the UI SHALL show that more matches may exist.

#### Scenario: Match limit reached
- **WHEN** a query matches more often than the match limit
- **THEN** only the first matches up to the limit can be stepped through
- **AND** the match count is shown with a marker that the limit was reached, not as an exact total

## REMOVED Requirements

### Requirement: Output Truncation
**Reason**: Virtualised rendering replaces the 500,000-character display cap (roadmap §5.5). The Raw and Hex views now show payloads of any size completely; see *Virtualized Raw Text Rendering*, *Virtualized Hex Rendering* and *Complete Raw Data Copy*.
**Migration**: No user action or data migration is needed. The truncation notice disappears. Copy still returns the complete data.
