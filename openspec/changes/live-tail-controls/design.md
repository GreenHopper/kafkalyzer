# Design: live-tail-controls

## Context

See proposal.md (Why, verified code findings). Requirements: `specs/topic-consumption/spec.md` and
`specs/live-tail-controls/spec.md`. State that shapes the approach:

- One `MessageStreamController` per topic tab, held by `ActiveConnectionController.getStreamController`; hidden tabs
  stay mounted in an `IndexedStack`, so every open tab keeps receiving ticks. Throttle is a 60 ms one-shot timer.
- `MultiSearchController` (DI singleton) keeps `Map<SearchTarget, List<KafkaMessage>>`; the script runner reads match
  counts and extraction input from it; result files are written separately through an `IOSink` per target and are
  not capped.
- `MessagesView` derives `_cachedFilteredMessages` (arrival order) and `_cachedSortedMessages` and hands the sorted
  list to table/timeline/diff. `MessagesTableView` derives `_cachedData` (row strings, column filters, column sort)
  from that list and reports its visual order back. Children detect changes by list identity.
- After `fix-result-view-defects` every message comparator ends with `compareMessageIdentity` (topic, partition,
  offset), so all orders are total; error state exists on both controllers.
- Sibling 5.27 introduces `MessageQuickFilter.matches` and a time-display mode that keys the table's row cache;
  sibling 5.28 fills an identity set `_cachedNonMatches` in `_updateFilters` for export.
- `KafkaMessage` (generated) has value equality over all fields including payload, so value-keyed maps hash payloads.

## Goals / Non-Goals

**Goals:**
- Per live tick: O(k) filter/format/compare work for k new messages, plus at most a few linear reference passes; no
  O(N) shift per message; memory bounded by the limit (plus at most one frozen snapshot while paused).
- One buffer type for both controllers; one merge helper for both views.

**Non-Goals:**
- Moving any of this to `kafkalyzer-core`: it is view state over data that already lives in Dart, with one caller;
  crossing the bridge per tick would cost more than it saves.
- Byte-size based limits; timeline/diff follow; sharing a buffer between tabs.

## Decisions

### D1 Ring buffer over `ListQueue`, published as an immutable snapshot
New `lib/src/ui/messages/message_ring_buffer.dart`: `MessageRingBuffer(capacity)` wraps `dart:collection`
`ListQueue<KafkaMessage>` (`addLast`/`removeFirst` are amortized O(1)) and keeps `receivedTotal`; derived
`droppedTotal = receivedTotal - length`, and an `epoch` incremented by `clear()`. `snapshot()` returns
`MessageSnapshot extends UnmodifiableListView<KafkaMessage>` over `List.of(queue)` (arrival order) carrying `epoch`,
`firstSeq` (= `droppedTotal` at snapshot time) and `endSeq` (= `receivedTotal`).
The copy is O(N) references once per *published* tick (≤ every 60 ms, only when changed) — the same cost as today's
`List.unmodifiable`, without per-message work.
*Alternative:* a hand-written circular array with index arithmetic — rejected, `ListQueue` already is one.
*Alternative:* a zero-copy view by sequence number into the live buffer — rejected: entries are overwritten while
older views are still held (export copy, view caches), which would make them silently wrong.

### D2 `MessageStreamController`: ring buffer, pause, counters
- `startStreaming` and `clearMessages` create a fresh buffer with capacity
  `SettingsService.messageBufferLimit.value` (injectable `int Function()` for tests) and reset the pause.
- `_onMessageReceived` adds to the buffer; the result-limit stop uses `receivedTotal >= maxResults`;
  `totalConsumed` uses `receivedTotal`.
- The throttle tick publishes `_published = buffer.snapshot()` unless paused, then `notifyListeners()`. While paused
  the tick still notifies (for the "n new" count) but `messages` keeps returning the same `_published` object, so views
  see an identical list and do no work.
- New getters: `isPaused`, `pendingCount = buffer.receivedTotal - _published.endSeq`, `receivedCount`,
  `droppedCount = buffer.droppedTotal`, `bufferLimit`. `pause()` / `resume()` (resume publishes and notifies).
- EOF, stop and error keep the pause and the buffer (spec: stream ends or fails while paused); the error from
  `fix-result-view-defects` is rendered regardless of pause.
Memory while paused: buffer (≤ limit) + frozen snapshot (≤ limit references to possibly evicted messages) — at most
2 × limit messages alive. Stated in Risks.
*Alternative:* `StreamSubscription.pause()` — rejected: the Dart stream controller would buffer events without limit
and the Rust sink would back up.

### D3 `MultiSearchController`: per-target ring buffer and trailing flush
- `_results` becomes `Map<SearchTarget, MessageRingBuffer>`, created in `_startSubscription` with the current limit;
  `getMessagesFor(target)` returns a cached snapshot invalidated on insert (as today). New `receivedCountFor` and
  `droppedCountFor`. The aggregate `getMessagesFor(null)` path keeps its full sort (no live caller in `lib/`).
- The file sink's "first element" check uses `receivedTotal == 1` instead of the list length.
- `_throttleNotify` gains a trailing timer: leading notify as today, and if suppressed, one `Timer(100 ms)` that
  notifies once. Timers are cancelled in `removeTarget`, `clear` and `dispose`.
- `ScriptRunner.getMatchCount` and `totalFound` use `receivedCountFor`; new `getDroppedCount(stepId, topic)`.
  Extractions keep reading the retained messages; when the target dropped messages the runner logs a warning and the
  tile shows the count, so a partial extraction is visible.

### D4 Incremental update in `MessagesView`
`didUpdateWidget` computes a delta when old and new `messages` are both `MessageSnapshot`s with the same `epoch`,
`new.firstSeq >= old.firstSeq` and `new.endSeq >= old.endSeq`, and no view input (search, show-non-matches, sort
field/direction, comparator, active view) changed:
- `evicted` = identity set of `old.take(new.firstSeq - old.firstSeq)` (clamped);
- `added` = `new.skip(max(0, old.endSeq - new.firstSeq))`.
Then: classify `added` once with the quick-filter predicate (`MessageQuickFilter.matches` once 5.27 lands, otherwise
the existing inline predicate extracted into one function); update the identity set `_cachedNonMatches` (shared with
5.28; added here if 5.28 has not landed) and `_cachedMatchCount` (+ added matches, − evicted matches);
`_cachedFilteredMessages` = old filtered list minus the evicted prefix plus added kept items (arrival order, no
predicate calls); `_cachedSortedMessages = mergeIncremental(...)` (D5). Anything else falls back to today's full
`_updateFilters`. The selection pruning from 5.27 runs on `evicted` only.

### D5 One pure merge helper
New `lib/src/ui/messages/incremental_sorted_merge.dart`:
`List<T> mergeIncremental<T>(List<T> previous, {required bool Function(T) retain, required List<T> added,
required Comparator<T> compare})` sorts `added` (k log k), walks `previous` once dropping non-retained items and, for
each added item, finds its slot by binary search in the remaining range (O(k log N) comparisons), returning a new
list (new identity for children). With a total comparator the result equals a full sort — this is the property the
unit tests check against `List.sort` on random input, including equal primary keys.
*Alternative:* `insert` per message at the binary-search index — rejected: O(N) shift per message (k·N per tick).
*Alternative:* full sort with cached keys — rejected by L4 and the spec (only new items may be compared).

### D6 Incremental table rows and projected values
- Row data is cached per message in an `Expando<_TableRowData>` (identity, released with the message). A new
  `Expando` is created when anything a row string depends on changes (projected column set, show topic/step, locale,
  and 5.27's time-display mode).
- Column-filter results are stored on the row with a `_filterRevision`; only rows built this tick or with an old
  revision are evaluated.
- Order: without column sort, rows follow the input order (one O(N) pass of cache lookups). With column sort, the
  previous `_cachedData` is merged (D5) with `retain` = message still in an identity set of the input and still passing
  filters, `added` = rows built this tick. Column sort/filter changes rebuild fully.
- Projected values: `_projectedValues` becomes `Map<KafkaMessage, Map<String, String>>.identity()`; a dirty pass
  sends only payloads of messages without entries in one `resolveJsonPathBatch` call, then removes entries whose
  message is no longer in the input; cleared when the projected column set changes. The existing in-flight guard
  stays; messages arriving during a call are picked up by the next pass.

### D7 Follow newest (table only)
- State lives in `MessagesTableView`, shown as a small toggle overlay at the table's top-right (icon + label "Follow
  newest", tooltip, `Semantics(toggled:)`), rendered only when `MessagesView` passes `showFollowControl: true` (topic
  tab). `MessagesView` passes a `followResetToken` that changes when a stream starts; a new token switches follow on.
- Availability: effective order is timestamp — no column sort and the view's sort field is `timestamp`, or the
  column sort is the Timestamp column. Direction from the same source. Disabled state has its own tooltip.
- Following: descending → offset stays 0 (insertions above row 0 do not move it); ascending → `jumpTo(maxScrollExtent)`
  after layout. Own scrolls run inside a `_programmaticScroll` guard.
- Switch-off: `UserScrollNotification` with a direction other than idle, or `ScrollStartNotification` with
  `dragDetails`, while not inside the guard; a row tap also switches off. Spike S1 verifies wheel, drag, scrollbar
  thumb and keyboard; any input not covered gets an explicit hook (e.g. `Listener.onPointerSignal`).
- Keeping position when off: before the rebuild remember the first visible message (`(offset − 40) / 44`, fixed
  row extents) and its index; after the rebuild find its new index and shift the offset by `Δindex × 44`. If it was
  dropped, the offset is only clamped. Spike S2 decides between a post-frame `jumpTo` and correcting the position
  before paint, whichever shows no visible jump.

### D8 Pause and indicators in the topic tab
`_buildProgressActions` gets a Pause / Resume `OutlinedButton.icon` next to Stop (Resume label "Resume · {count}
new" via ARB plural); shown while streaming or while paused. `TopicProgressTile` already has `extraSubtitle`: the topic
tab and `ScriptProgressWidget` pass a one-line "{dropped} oldest messages dropped (limit {limit})" with an info icon
and a tooltip naming Settings → General. `matchCount` uses the received count. Numbers use `NumberFormat` from `intl`
(existing dependency). No new keyboard shortcuts.

### D9 Buffer limit setting
`SettingsService`: `messageBufferLimitKey = 'message_buffer_limit'`, default 50,000, range 1,000–1,000,000,
`ValueNotifier<int> messageBufferLimit`, `loadMessageBufferLimit()` (called from `initializeSettings()` and at the
end of `importConfiguration()`; an invalid stored value yields the default without rewriting it),
`setMessageBufferLimit(int)` (validated), and a pure `parseMessageBufferLimit(String) → int?` for the field.
Settings → General gets one `TextField` (key `message_buffer_limit_field`) with helper text and a localized
`errorText` for invalid input; it writes only valid values. Controllers read the notifier when a session starts.
The key is a plain preference and travels with the existing configuration export (all preferences are exported).
*Alternative:* separate limits for topic tabs and multi-search — rejected, no user need shown; one knob.

## Risks / Trade-offs

- [Count-based limit with very large payloads (e.g. 50,000 × 100 KB) can still use gigabytes] → the limit is
  user-adjustable and the helper text says it is per result list; a byte-based limit is a non-goal.
- [Many open topic tabs each hold up to the limit; paused tabs up to 2 × limit] → same knob; the dropped indicator
  makes the bound visible. Documented in the setting helper text.
- [O(N) reference copy per published tick and O(N) passes in D4/D6] → no predicate, formatting or comparison on
  old items; at 50,000 messages this is a few hundred KB of pointer copying per 60 ms. Acceptable vs. today's
  full lowercase filter, sort and date formatting.
- [Script extractions only see retained messages] → warning log and visible dropped count on the topic tile; raising
  the limit is the remedy.
- [Parallel edits of `messages_view.dart` / table by 5.27, 5.28, 5.30] → hooks named in D4/D6; whichever lands
  second rebases. Merge order with `fix-result-view-defects` is fixed (prerequisite).
- [Scroll intent detection differs between inputs and platforms] → spike S1 with widget tests per input kind.
- [Compacted or transactional topics, offset gaps, empty topics] → unaffected: counts are received messages, never
  offset arithmetic; offsets only act as sort tie-breakers. An empty topic never creates a snapshot delta.
- [Unreachable broker, missing ACL] → errors surface as in `fix-result-view-defects`; pause never hides them.

## Migration Plan

No data migration. New preference `message_buffer_limit`; absent → default. Behaviour change: unlimited topic
streams now stop retaining beyond 50,000 (visible indicator), multi-search targets retain up to the setting instead
of 2000. Rollback = revert; older versions ignore the key.

## Open Questions

- Exact visual placement of the follow overlay relative to the column header menu — settle in implementation review.
