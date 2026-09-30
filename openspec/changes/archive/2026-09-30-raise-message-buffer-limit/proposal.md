## Why

Users cannot search, inspect, analyze, or export more than 1000 matching messages from a topic, even when the result-limit checkbox is off or a limit above 1000 is configured. A hard-coded Flutter ring buffer silently drops older matches, so a ~9300-message topic always yields only the last 1000 in the UI and in downloads.

## What Changes

- Remove the hard-coded 1000-message ring buffer in the Flutter streaming layer (`MessageStreamController`).
- Retain every matching message delivered for a consumption session when no result limit is configured, until the stream ends or the user stops it.
- When a result limit of $N$ is configured, retain up to $N$ matching messages (existing stop-at-limit behavior), without a lower silent cap of 1000.
- Keep existing UI throttling and amortized append behavior so large result sets remain responsive.
- Update/add unit coverage so buffers above 1000 are retained and exportable.

## Capabilities

### New Capabilities

<!-- None — this extends existing topic consumption buffer behavior. -->

### Modified Capabilities

- `topic-consumption`: Require the Flutter message buffer to honor the configured result limit (or retain all matches when unlimited), and forbid silent dropping at a fixed 1000-message ceiling independent of user settings.

## Impact

- **Primary code**: `lib/src/features/topic/presentation/controllers/message_stream_controller.dart` (ring-buffer trim).
- **Downstream UX**: message list/table/inspector, and `MessageExportService` exports (they consume whatever the controller retained).
- **Unaffected**: Rust consumer `max_results` enforcement, partition quota distribution, topic content analysis scan limits (separate path with its own sampling options).
- **Risk**: Unbounded live streaming (`runForever` with no limit) can grow memory with topic throughput; design will address mitigations without reintroducing a silent 1000 drop.
