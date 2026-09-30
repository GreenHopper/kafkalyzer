## 1. Flutter Buffer Fix

- [x] 1.1 Remove the hard-coded `_messages.length > 1000` / `removeAt(0)` trim in `MessageStreamController._onMessageReceived`, keeping append + throttled notify + stop-at-`maxResults` behavior, and verify with `dart analyze` on the controller file that the trim is gone and analysis is clean
- [x] 1.2 Confirm no other silent fixed match-buffer ceiling remains (repo grep for `> 1000` / ring-buffer trims on message lists) and document finding in the task completion notes if anything unexpected appears
  - Note: Only remaining `removeAt(0)` in lib/ is consumer lag query queue dequeue; no other message-buffer 1000 ceiling found.

## 2. Testability and Unit Coverage

- [x] 2.1 Make `MessageStreamController` unit-testable for inbound matches (e.g. injectable stream factory or `@visibleForTesting` feed path) without changing public streaming semantics, and verify a minimal harness can deliver synthetic `KafkaMessage`s into the buffer
- [x] 2.2 Add unit tests covering: unlimited retention of >1000 matches; retention of $N$ when `maxResults = N > 1000`; stop and at-most-$N$ when more than $N$ arrive; and verify `flutter test` on the new/updated controller test file passes

## 3. Verification

- [x] 3.1 Run `dart format` on touched Dart files and `flutter test` for the new controller tests plus any affected existing topic/message tests, and verify all pass
- [x] 3.2 Manually smoke-check (or note deferred if no cluster): open a topic with >1000 messages, disable Max Results (or set limit >1000), confirm UI count and export include the full retained set rather than capping at 1000
  - Deferred: no Kafka cluster available in this session; covered by unit tests for retention behavior.
