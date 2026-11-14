# Tasks

Prerequisite: `fix-result-view-defects` is merged (`compareMessageIdentity`, controller error state). No Rust crate,
`rust/src/api/` or bridge change: the Rust and bridge-regeneration steps do not apply to this change.

## 1. Spikes (scroll behaviour of the message table)

- [ ] 1.1 S1: in a throwaway widget test on `MessagesTableView`'s `TableView`, record which notifications mouse wheel
      (`PointerScrollEvent`), drag, scrollbar-thumb drag and keyboard scrolling produce, versus `jumpTo`/`animateTo`;
      write the result (which inputs need an extra hook) into design D7 and verify the test documents each input kind
- [ ] 1.2 S2: in the same harness, insert 50 rows above the first visible row and compare a post-frame `jumpTo`
      with correcting the position before paint; keep the variant whose golden/offset check shows the anchor row at
      the same y position in the first frame, and note the choice in design D7

## 2. Pure Dart building blocks

- [ ] 2.1 Write failing unit tests for `MessageRingBuffer`/`MessageSnapshot` (`test/src/ui/messages/message_ring_buffer_test.dart`):
      append below capacity, eviction order at capacity, `receivedTotal`/`droppedTotal`, `firstSeq`/`endSeq`, `epoch`
      after `clear()`, snapshot unaffected by later adds, 10,000 adds at capacity stay linear (no per-add shift)
- [ ] 2.2 Implement `lib/src/ui/messages/message_ring_buffer.dart` over `ListQueue` (design D1); verify 2.1 GREEN
- [ ] 2.3 Write failing unit tests for `mergeIncremental` (`test/src/ui/messages/incremental_sorted_merge_test.dart`):
      result equals `List.sort` for random inputs with duplicate primary keys and the identity tie-breaker, retain
      filter removes exactly the evicted items, empty previous/added, comparator call count O(k log N)
- [ ] 2.4 Implement `lib/src/ui/messages/incremental_sorted_merge.dart` (design D5); verify 2.3 GREEN

## 3. Buffer limit setting (service)

- [ ] 3.1 Write failing tests in `test/src/services/settings_service_test.dart` (or the existing settings test file):
      default 50,000 when unset, invalid stored value (0, 5,000,000, wrong type) → default without rewriting the
      preference, `setMessageBufferLimit` rejects out-of-range values, `parseMessageBufferLimit` accepts 1,000 and
      1,000,000 and rejects 999, text and empty input, reload after `importConfiguration`
- [ ] 3.2 Implement key, constants, `ValueNotifier`, load/set/parse in `lib/src/services/settings_service.dart` and
      call the loader from `initializeSettings()` and `importConfiguration()` (design D9); verify 3.1 GREEN

## 4. Controllers

- [ ] 4.1 Extend `test/src/features/topic/presentation/controllers/message_stream_controller_test.dart` (failing first):
      limit 1,000 with 1,250 messages → 1,000 retained, `droppedCount` 250, `receivedCount` 1,250; result limit
      stops on received count when above the buffer limit; pause freezes `messages` identity while `pendingCount`
      grows; resume publishes; EOF/error/stop keep pause and buffer; start/clear reset pause and counts; at most one
      notification per throttle interval; existing three retention tests still pass with limit ≥ N
- [ ] 4.2 Implement design D2 in `message_stream_controller.dart` (injectable limit provider defaulting to
      `SettingsService.messageBufferLimit`); verify 4.1 GREEN
- [ ] 4.3 Add failing tests for `MultiSearchController` (new `test/src/features/search/presentation/controllers/multi_search_controller_test.dart`,
      stream injected the same way as in 4.2 if needed): 6,000 messages with limit 5,000 → 5,000 retained, dropped
      1,000, received 6,000; 3,000 → no drops; trailing notification arrives ≤ 100 ms after a burst; result file
      still contains every message and valid JSON
- [ ] 4.4 Implement design D3 in `multi_search_controller.dart` (ring buffer per target, trailing flush with timer
      cleanup, file-sink first-element fix); verify 4.3 GREEN
- [ ] 4.5 Switch `ScriptRunner.getMatchCount`/`totalFound` to received counts, add `getDroppedCount`, log a warning
      when extractions run on a target with drops; extend `script_runner_test.dart` for a target above the limit and
      verify match counts above 2,000 are reported

## 5. Localization keys (en + de)

- [ ] 5.1 Add to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`: pause, resume with plural `{count}` new, pause and
      resume tooltips, follow-newest label, follow on/off tooltips, follow-disabled tooltip (needs timestamp order),
      dropped indicator with `{dropped}`/`{limit}` and its tooltip, buffer-limit label, helper text and range error;
      run `flutter gen-l10n` (or `flutter pub get`) and verify the generated getters compile

## 6. Result views

- [ ] 6.1 Write failing widget tests in `test/src/ui/messages/messages_view_test.dart`: feeding successive
      `MessageSnapshot`s with an active search evaluates the predicate only for new messages (counting predicate
      calls via a test seam), order/match count/dimming equal a full recompute, evicted messages disappear without
      reordering others, sort or search change recomputes fully, a plain `List` input keeps full recompute
- [ ] 6.2 Implement design D4 in `messages_view.dart` (delta detection, shared non-match identity set, match count,
      filtered/sorted lists via `mergeIncremental`); verify 6.1 GREEN and existing `messages_view_*_test.dart` pass
- [ ] 6.3 Write failing tests in `test/src/ui/messages/views/messages_table_view_projection_test.dart` and a new
      `messages_table_view_live_test.dart`: rows of retained messages are not rebuilt on a live tick, column filter
      evaluated only for new rows, column sort result equals full sort, projected-value bridge mock receives only new
      payloads and cache entries of dropped messages are released
- [ ] 6.4 Implement design D6 in `messages_table_view.dart` (Expando row cache, filter revision, merge under
      column sort, identity projected-value cache with pruning); verify 6.3 GREEN and existing table tests pass

## 7. Follow newest and pause UI

- [ ] 7.1 Write failing widget tests for follow (table): on by default after stream start, stays at top for
      descending and at bottom for ascending, wheel/drag/keyboard scroll and row tap switch it off (per S1),
      programmatic scroll does not, anchor row keeps its y position when 50 rows arrive and 50 drop (per S2),
      re-enable jumps to newest, disabled with tooltip under non-timestamp column sort, toggle exposes tooltip and
      toggled semantics
- [ ] 7.2 Implement design D7 (`showFollowControl`, `followResetToken` on `MessagesView` → `MessagesTableView`); use
      `package:material_ui/material_ui.dart` widgets; verify 7.1 GREEN
- [ ] 7.3 Write failing widget tests in `test/src/features/topic/topic_detail_view_test.dart`: Pause shown only while
      streaming or paused, Resume shows "n new", dropped indicator with count and limit appears only when drops > 0,
      match count shows received total, error stays visible while paused
- [ ] 7.4 Implement design D8 in `topic_detail_view.dart`, `topic_progress_tile.dart` usage and
      `script_progress_widget.dart` (dropped line per script topic tile); verify 7.3 GREEN and
      `test/src/ui/script_progress_widget_test.dart` covers a tile with drops
- [ ] 7.5 Add the buffer-limit `TextField` to Settings → General in `settings_view.dart` (design D9); widget test:
      shows 50,000 by default, invalid input shows the localized range error and leaves the preference unchanged,
      valid input persists; verify the test passes

## 8. Final verification

- [ ] 8.1 Run `dart format lib test` and verify no diff remains
- [ ] 8.2 Run `flutter analyze` and verify zero issues
- [ ] 8.3 Run `flutter test` and verify all tests pass
- [ ] 8.4 Run `scripts/check_read_only.sh` and verify it passes unchanged (no new exception)
- [ ] 8.5 Manual check against a test cluster: live tail on a busy topic with limit 1,000 — dropped count rises,
      pause freezes the table with a growing "n new", resume merges, follow switches off on wheel scroll and the
      read row stays in place; record the result in the PR description

## Workflow follow-up

- Archive the change after review; verify `openspec/specs/topic-consumption` and the new
  `openspec/specs/live-tail-controls` contain the merged requirements.
