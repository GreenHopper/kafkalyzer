## Context

Currently, Kafkalyzer loads message payloads directly into the UI thread for rendering. For small payloads, this is instantaneous. However, for large payloads (e.g., up to 8MB), reading, parsing (if JSON), and applying formatting/syntax highlighting blocks the main Dart isolate, leading to OS-level "Application Not Responding" dialogs. We need to implement a solution that ensures the UI remains responsive and provides feedback during large message processing.

## Goals / Non-Goals

**Goals:**
- Ensure the main UI isolate does not block for more than a few milliseconds when opening large messages.
- Provide a visual progress indicator (like a circular progress spinner) while a message is being loaded or formatted.
- Process heavy operations (e.g., JSON parsing, hex view formatting) asynchronously.

**Non-Goals:**
- We are not implementing true infinite scrolling or virtualized lazy loading for the payload bytes themselves in this iteration, though that might be considered later. 
- We are not increasing the hard limit of message sizes fetched from Kafka in this specific task.

## Decisions

1. **Use `compute` (Isolates) for heavy processing**
   - *Rationale:* Dart's `compute` function easily spawns an isolate for a single heavy task. We can use this for JSON decoding (`jsonDecode` and pretty-printing) and Hex string generation, returning the fully formatted string to the main isolate.
   - *Alternative:* Chunked processing on the main thread using `Future.delayed`. This is complex and might still stutter the UI compared to a true background isolate.

2. **Display Loading Indicators in `JsonOrStringViewer` and `HexViewer`**
   - *Rationale:* While the future from `compute` is pending, we can yield a `FutureBuilder` or a simple `isLoading` state in the viewers to show a `CircularProgressIndicator`.
   - *Alternative:* Only showing a spinner in the parent `MessageDetailsDialog`. Having it in the viewers allows switching tabs (e.g., to raw bytes) and seeing a spinner per view if needed, but doing it in the parent might be simpler. We'll add it in the viewers since they are responsible for their own formatting overhead.

3. **Character Limits / Truncation Option for Renderers**
   - *Rationale:* Even if parsing is fast, Flutter's `SelectableText` or `RichText` can still choke on millions of characters. We may need to limit the maximum displayable characters to a safe threshold (e.g., 500KB of text) and provide an option or warning like "Message truncated for display. [Save to File] to view full payload."
   - *Alternative:* Native text rendering optimization. Not feasible without custom rendering engines.

## Risks / Trade-offs

- **[Risk]** Isolates have memory overhead. Passing large strings (8MB) between isolates copies the memory.
  - *Mitigation:* 8MB copied is ~16MB, which is well within desktop memory limits. If sizes grow further, we might need to explore `TransferableTypedData` for the byte arrays.
- **[Risk]** UI might still lag during the final text layout phase in Flutter.
  - *Mitigation:* Implement a hard truncation limit (e.g., 500,000 characters) for the text views, guaranteeing the layout engine never receives an unmanageable string.
