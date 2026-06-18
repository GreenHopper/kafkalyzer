## Why

When users attempt to view very large messages (e.g., up to 8MB) in the UI, the application freezes. The OS eventually shows a dialog indicating the application is not responding because the UI thread is blocked by heavy processing or rendering operations. We need to handle large messages gracefully so the UI remains responsive and provides proper feedback (e.g., progress indicators) during long-running operations.

## What Changes

- Add a size check or streaming approach to handle large payloads (up to 8MB or more).
- Move heavy processing (like JSON formatting, syntax highlighting, or parsing) off the main UI thread to background isolates.
- Display a progress indicator in the UI while large messages are being loaded or processed.
- Potentially truncate or paginate the view of extremely large messages to prevent rendering bottlenecks, offering an option to view the full message if safe, or save it directly to a file.

## Capabilities

### New Capabilities
- `large-message-handling`: Ensures the UI stays responsive when opening, parsing, and rendering large payloads by utilizing background processing, loading states, and truncation.

## Impact

- **UI Components**: Modifications to `MessageDetailsDialog`, `JsonOrStringViewer`, and `HexViewer` to support async content loading and rendering.
- **State/Controllers**: Message data passing might need to involve asynchronous parsing streams or isolate spawning.
- **Performance**: Significant improvement in application stability and responsiveness during interactions with large data payloads.
