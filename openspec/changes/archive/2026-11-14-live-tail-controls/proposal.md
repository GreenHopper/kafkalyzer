# Proposal: live-tail-controls

Source: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md`, §5.29 (change id `live-tail-controls`, size M),
finding group C ("Live-Stream ohne Pause und mit unbegrenztem Puffer", §2.4), guardrails L4 and L5 (§1), phase 1b in
§6. Layers: Dart only.

## Why

A live tail in a topic tab grows its buffer without limit until the app runs out of memory, while the multi-topic
search silently keeps only the newest 2000 matches per topic. Every 60 ms tick re-filters, re-sorts and re-formats the
whole list, so the view gets slower the longer it runs, and there is no way to pause the view or to stop it from
jumping while reading a message. Users watching production topics need a bounded, honest and steady view.

## What Changes

Verified in code (deviations from the roadmap noted):
- `MessageStreamController._messages` (`message_stream_controller.dart:74,186`) grows without limit when no result
  limit is set; `messages` copies the whole list once per change (`:80-81`). The result-limit stop compares the
  *retained* count (`:193`). Confirmed.
- `MultiSearchController._insertMessage` (`multi_search_controller.dart:427-432`) caps silently at 2000 with
  `removeRange(0, …)`, an O(N) shift per message once full. Confirmed. Not in the roadmap: `_throttleNotify`
  (`:410-418`) is leading-edge only, so the last batch before a quiet period is not shown; the script runner's match
  count and extractions (`script_runner.dart:99,308,978`) use the capped list, so counts above 2000 are wrong.
- `MessagesView._updateFilters` (`messages_view.dart:368-394`) re-filters and re-sorts everything per tick. Confirmed.
  Not in the roadmap: `MessagesTableView._filterAndSortMessages` re-maps every row per tick (date formatting, preview),
  and `_resolveProjectedValues` sends *all* payloads to the bridge on every change; its cache is keyed by value
  equality and only cleared when the list shrinks, so with a full buffer it would grow without bound.

Changes:
- One ring buffer type with O(1) append and O(1) eviction, used by the topic stream and by every multi-search target.
  Its capacity is the new **message buffer limit** setting (default 50,000, range 1,000–1,000,000, Settings → General).
  The number of dropped oldest messages is shown on the topic progress tile and on each script topic tile; match
  counts report all received matches, not only retained ones.
- Result-limit stop counts received matches. Multi-search notifications get a trailing flush.
- **Pause / Resume** in a topic tab: the view freezes, consumption continues into the bounded buffer, the Resume
  button shows "n new"; resume merges.
- **Follow newest** toggle in the table view: keeps the newest edge in view under timestamp order, switches itself off
  on manual scroll or row selection; while off, visible rows stay in place when rows are inserted or dropped.
- Incremental result updates: `MessagesView` and `MessagesTableView` filter, sort, format and resolve projected
  columns only for added messages and remove dropped ones; full recompute only when search, filters, sort, columns or
  view change. Builds on the total order (topic/partition/offset tie-breaker) from `fix-result-view-defects`.
- New strings in `app_en.arb` and `app_de.arb`.

Read-only impact: no new Kafka or Schema Registry calls. Pause does not pause or seek the consumer; it only freezes the
view. `scripts/check_read_only.sh` must pass unchanged.

Prerequisites (implemented first): `fix-result-view-defects` (tie-breaker comparator `compareMessageIdentity`, error
state in both controllers). Coordinate with parallel siblings that edit the same files: `message-selection-copy-and-
display` (5.27: `MessageQuickFilter`, selection pruning, time-display mode in the row cache key) and
`message-export-fidelity` (5.28: `_cachedNonMatches` filled in `_updateFilters`); this change keeps both hooks working
incrementally. `harden-local-storage-and-imports` edits `SettingsService.importConfiguration`, which this change
touches with one reload call.

Non-goals:
- Pausing, throttling or seeking the Rust consumer; any Rust or bridge change.
- Follow/position keeping in the timeline and diff views (variable row heights); keyboard shortcuts for pause/follow.
- Spilling dropped messages to disk, per-topic buffer limits, a memory-size (MB) based limit.
- Settings page layout and other general settings (5.31), local/UTC time display (5.27), leftover hard-coded strings
  outside the new UI (5.32), export scope (5.28).

## Capabilities

### New Capabilities
- `live-tail-controls`: pause/resume of the result view, follow-newest toggle, incremental live updates of the
  result views, and the message buffer limit setting.

### Modified Capabilities
- `topic-consumption`: MODIFIED *Result Buffer Honors Configured Limit* (bounded by the buffer limit setting for the
  topic stream and each multi-search target, oldest dropped with visible count, stop on received matches); MODIFIED
  *Throttled UI State Emission and Amortized Buffering* (covers multi-search, trailing flush, O(1) eviction).

## Impact

- New `lib/src/ui/messages/message_ring_buffer.dart` (ring buffer + snapshot) and
  `lib/src/ui/messages/incremental_sorted_merge.dart` (pure merge helper), with unit tests.
- `lib/src/features/topic/presentation/controllers/message_stream_controller.dart` — ring buffer, pause, counters.
- `lib/src/features/search/presentation/controllers/multi_search_controller.dart` — ring buffer per target, trailing
  flush, dropped/received counts.
- `lib/src/features/scripting/presentation/controllers/script_runner.dart`, `lib/src/ui/script_progress_widget.dart`,
  `lib/src/ui/topic_progress_tile.dart` — received counts and dropped indicator.
- `lib/src/features/topic/topic_detail_view.dart` — Pause/Resume button, dropped indicator.
- `lib/src/ui/messages/messages_view.dart`, `lib/src/ui/messages/views/messages_table_view.dart` — incremental
  updates, follow toggle, scroll position keeping.
- `lib/src/services/settings_service.dart`, `lib/src/features/settings/presentation/settings_view.dart` — setting.
- `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`, tests under `test/src/...`.
