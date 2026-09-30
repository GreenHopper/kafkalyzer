## Context

See proposal.md — Why. Today `MessageStreamController` appends matching messages then trims with:

```dart
if (_messages.length > 1000) {
  _messages.removeAt(0);
}
```

Rust already honors `maxResults` / unlimited correctly. The Flutter trim overrides both: unlimited sessions and limits above 1000 still surface only ~1000 messages to the UI and to `MessageExportService`. Throttled `notifyListeners` (~60ms) and append-based buffering remain in place from the earlier performance work.

## Goals / Non-Goals

**Goals:**

- Make retained matches equal the user-configured result limit (or all matches when unlimited).
- Preserve existing UI throttle and $O(1)$ append path.
- Keep stop-at-`maxResults` behavior as the only intentional retention ceiling when a limit is set.

**Non-Goals:**

- Changing Rust `max_results`, partition quota distribution, or tail-offset math.
- Changing topic content analysis sampling presets (10k / 100k / full scan).
- Building disk-backed or paged result stores for multi-million-message sessions.
- Adding a new settings UI for a secondary buffer size (unless needed later for live-stream warnings).

## Decisions

### 1. Remove the fixed 1000 trim; do not replace it with another silent hard cap

**Choice:** Delete the `_messages.length > 1000` / `removeAt(0)` ring-buffer logic. When `maxResults` is set, continue stopping the stream once `_messages.length >= maxResults` (existing logic). When `maxResults` is null, keep appending until EOF / user stop / stream error.

**Alternatives considered:**

- Raise the constant (e.g. 50_000): still surprises users who pick “no limit” or $N$ above the constant.
- Cap only for `runForever == true`: fixes bounded full-topic loads, but still silently drops on live unlimited streams; more complex branching for little gain in the reported failure mode (~9300 bounded read).
- Disk-spill / windowed buffer: correct for huge live topics, out of scope for this fix.

### 2. Prefer stop-at-limit over FIFO trimming when `maxResults` is set

**Choice:** Rely on canceling the subscription at $N$ matches rather than trimming the list. That avoids $O(N)$ `removeAt(0)` and keeps the buffer exactly the retained set.

**Alternatives considered:** Keep FIFO trim at `maxResults` — unnecessary if we stop intake at $N$.

### 3. Memory for unlimited live streams is user-controlled

**Choice:** Document that live + unlimited can grow memory with throughput; users who need a bound should enable Max Results. No new warning UI in this change.

**Alternatives considered:** Soft warning SnackBar at thresholds (e.g. 10k / 50k) — useful follow-up, not required to fix the 1000 silent drop.

### 4. Tests over UI churn

**Choice:** Cover retention with unit tests on `MessageStreamController` (inject/simulate >1000 messages with and without `maxResults`). No Rust or FRB changes expected.

## Risks / Trade-offs

- **[Risk] Large unlimited sessions increase Dart heap and list/table work** → **Mitigation:** Existing 60ms notify throttle and lazy viewport formatting remain; users can set Max Results; list/table already use builders. Validate with ~10k messages in manual check.
- **[Risk] `removeAt(0)` removal alone is not enough if another layer caps at 1000** → **Mitigation:** Grep confirms the only silent 1000 match trim is in `MessageStreamController`; export uses `controller.messages`.
- **[Risk] Live unlimited OOM on busy topics** → **Mitigation:** Accept for this change; recommend Max Results for long-lived live tabs; optional future warning is out of scope.

## Migration Plan

- Pure client behavior change; no data migration.
- Rollback: restore the 1000 trim (not desirable).

## Open Questions

None — silent fixed ceiling removed; configured `maxResults` (or none) is the sole retention policy for this change.
