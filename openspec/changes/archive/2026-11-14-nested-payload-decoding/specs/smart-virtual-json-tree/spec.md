## ADDED Requirements

### Requirement: On-Demand Decoding of Tree Text Values
Every string row in the tree SHALL offer a "Decode as…" action with the options JSON, Base64 and gzip (Base64 text that is gunzipped). The decoded result SHALL appear in place as a child subtree of that row. The row SHALL keep showing the original value, and the user SHALL be able to remove the decoded view. Nothing SHALL be decoded without an explicit user action.

#### Scenario: Decode a JSON string field
- **WHEN** a row holds the string `{"id":7,"tags":["a"]}` and the user chooses "Decode as JSON"
- **THEN** the row SHALL become expandable and show a decoded subtree with `id: 7` and `tags` as an array
- **AND** the row SHALL still show the original string value and a marker that names the applied decoding

#### Scenario: Decode Base64 to text
- **WHEN** a row holds `aGVsbG8gd29ybGQ=` and the user chooses "Decode as Base64"
- **THEN** the decoded subtree SHALL contain the text `hello world`
- **AND** that text row SHALL itself offer "Decode as…" so that decodings can be chained, for example Base64 then JSON

#### Scenario: Base64 accepts common variants
- **WHEN** the value uses the URL-safe alphabet, lacks padding, or contains line breaks
- **THEN** "Decode as Base64" SHALL decode it the same way as standard padded Base64

#### Scenario: Decode Base64 to binary bytes
- **WHEN** a Base64 value decodes to bytes that are not valid UTF-8
- **THEN** the decoded subtree SHALL show the byte count and a hex preview of the first bytes
- **AND** the byte row SHALL offer gzip decompression and copying all bytes as hex

#### Scenario: Decode gzip-compressed Base64
- **WHEN** a row holds Base64 of gzip-compressed JSON and the user chooses "Decode as gzip"
- **THEN** the value SHALL be Base64-decoded and decompressed, and the decompressed text SHALL appear as a text row that can be decoded as JSON

#### Scenario: Remove a decoded view
- **WHEN** the user chooses "Show original only" on a decoded row
- **THEN** the decoded subtree SHALL disappear and the row SHALL look as before the decoding

#### Scenario: No automatic decoding
- **WHEN** a message is opened whose string fields contain JSON, Base64 or gzip data
- **THEN** every string row SHALL show its original value and no row SHALL be decoded until the user requests it

### Requirement: Bounded Off-Thread Decoding with Error Display
Decoding SHALL run off the UI thread and the row SHALL show a progress state while it runs. Input SHALL be limited to 8 MiB of text and decoded output to 16 MiB. A failed or over-limit decoding SHALL show a localized error on that row naming the reason, SHALL leave the original value unchanged and SHALL NOT look like an empty result.

#### Scenario: Large value stays responsive
- **WHEN** the user decodes a value of several megabytes
- **THEN** the UI SHALL stay responsive and the row SHALL show a progress indicator until the result or an error is shown

#### Scenario: Invalid Base64
- **WHEN** the user chooses "Decode as Base64" on a value that is not Base64
- **THEN** the row SHALL show an inline error "not valid Base64" and SHALL NOT show a decoded subtree

#### Scenario: Not gzip data
- **WHEN** the user chooses "Decode as gzip" on Base64 data that has no gzip header
- **THEN** the row SHALL show an inline error "not gzip data"

#### Scenario: Invalid JSON
- **WHEN** the user chooses "Decode as JSON" on `{"a":`
- **THEN** the row SHALL show an inline error that the value is not valid JSON

#### Scenario: Decompression exceeds the output limit
- **WHEN** a gzip value would decompress to more than 16 MiB
- **THEN** decompression SHALL stop at the limit without holding the full output in memory
- **AND** the row SHALL show an error naming the limit instead of a partial result

#### Scenario: Dismiss a decoding error
- **WHEN** a decoding error is shown on a row and the user dismisses it
- **THEN** the row SHALL return to its original state and the user SHALL be able to try another decoding

### Requirement: Decoded Subtrees Are View-Only
Decoded subtrees SHALL be part of the tree view: search SHALL find matches in them, and copying a decoded node SHALL copy the decoded content. Rows inside a decoded subtree SHALL NOT offer pinning as a column, filtering by field or copying a field path, because such content cannot be addressed by a field path. Decoded views SHALL be discarded when another message is shown.

#### Scenario: Search finds text inside a decoded subtree
- **WHEN** a string row was decoded as JSON and the active search query occurs only inside the decoded content
- **THEN** the match SHALL be highlighted in the decoded subtree and included in the match count

#### Scenario: Field actions are not offered inside decoded content
- **WHEN** the user looks at a row inside a decoded subtree
- **THEN** the row SHALL NOT offer "Pin as column", "Filter by field" or "Copy field path"
- **AND** the decoded row itself, whose original value is a field of the message, SHALL keep these actions

#### Scenario: Copy a decoded object
- **WHEN** the user copies an object node inside a decoded subtree
- **THEN** the clipboard SHALL contain that decoded object as valid JSON

#### Scenario: Next message clears decoded views
- **WHEN** decoded views are open and the user steps to another message
- **THEN** the new message SHALL show no decoded views and results of decodings still running for the old message SHALL be dropped

### Requirement: Whole-Value Decoding in the Payload Viewer
When the payload viewer shows a value that is not a JSON object or array, it SHALL offer the same "Decode as…" action for the whole value: Base64 and gzip for text, gzip for binary data shown in the hex view. The decoded result SHALL be shown as tree, text or hex view, and a "Show original" control SHALL return to the original view. The same limits and error display SHALL apply.

#### Scenario: Decode a Base64 header value
- **WHEN** the viewer shows the text value `eyJhIjoxfQ==` and the user chooses "Decode as Base64"
- **THEN** the viewer SHALL show the decoded text `{"a":1}` with the option to decode it further as JSON
- **AND** a banner SHALL name the applied decoding and offer "Show original"

#### Scenario: Decompress a binary gzip payload
- **WHEN** the viewer shows a binary payload in the hex view whose bytes are gzip data and the user chooses "Decode as gzip"
- **THEN** the decompressed content SHALL be shown as a tree if it is a JSON object or array, otherwise as text or hex

#### Scenario: Copy keeps the original value
- **WHEN** a decoded whole value is shown and the user activates the viewer's copy action
- **THEN** the original, undecoded value SHALL be copied, and a separate action SHALL copy the decoded content

## MODIFIED Requirements

### Requirement: Human-Readable Smart Timestamp Formatting
The JSON tree viewer SHALL automatically detect and format ISO-8601 date-time strings into localized, readable date-time presentations, and SHALL make integer numbers in a plausible epoch range readable as dates through a tooltip without replacing the number, while preserving access to exact raw values.

#### Scenario: Inline localized timestamp rendering
- **WHEN** a leaf string value matches ISO-8601 date/time patterns (e.g. `2026-09-29T19:00:00+01:00`)
- **THEN** the value SHALL render with a clock/calendar icon and formatted localized date-time text (e.g. `29.09.2026 19:00:00 (+01:00)`)
- **AND** the original raw value SHALL NOT be mutated in the underlying message data

#### Scenario: Timestamp tooltip and raw value inspection
- **WHEN** a user hovers over or taps a formatted timestamp value
- **THEN** a tooltip or popover SHALL display the exact raw timestamp, UTC equivalent, and local timezone offset
- **AND** the row copy action SHALL allow copying either the raw timestamp or formatted string

#### Scenario: Epoch number date tooltip
- **WHEN** a leaf integer lies between 2000-01-01 and 2100-01-01 UTC when read as epoch seconds, milliseconds, microseconds or nanoseconds, for example `1768812660123`
- **THEN** the row SHALL still display the number unchanged
- **AND** hovering it SHALL show a tooltip with the date in the global time display mode (local or UTC), the same instant in the other zone as ISO-8601, and the assumed unit (for example "epoch milliseconds")

#### Scenario: Numbers outside the epoch range
- **WHEN** a leaf number is not an integer or lies outside every epoch range above, for example `42` or `3.5`
- **THEN** the row SHALL show no date tooltip

#### Scenario: Time display mode change
- **WHEN** the global time display mode changes from local to UTC while a tree is shown
- **THEN** the next epoch tooltip SHALL show the date in UTC first
