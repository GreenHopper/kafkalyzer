# Proposal

## Why

The Failure Diagnostics card for dead-letter messages offers "Copy kcat Replay Command". It copies a ready-to-run
`kcat ... -P` producer command that writes the message back into the original topic. kafkalyzer itself does not
produce, but handing out a finished write command contradicts the read-only guardrail (no produce/replay) and makes
an accidental write to a production topic one paste away. The roadmap (`feature-gap-analysis.md` §5.1) already says
reprocessing happens in external tools and kafkalyzer only makes the failed message visible and copyable.

## What Changes

- **BREAKING (UI):** the "Copy kcat Replay Command" action and the code that builds the producer command are removed
  from the Failure Diagnostics card.
- The card gains "Copy failed message" instead: a JSON document with the DLQ message (topic, partition, offset,
  timestamp, key, value, headers), the original coordinates and the exception details, so a user can hand it to
  their own reprocessing tool.
- The read-only gate gets one more row: source code must not contain a `kcat` command with the producer flag `-P`.
  This keeps the replay command from coming back and also guards the read-only `kcat -C` command planned in
  `message-selection-copy-and-display` (§5.27).
- The two ARB keys of the replay action are replaced by keys for the new action (en + de).

Read-only impact: no new Kafka or Schema Registry calls. The change removes a write-command generator.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `dead-letter-queue-detection`: the requirement *DLQ Message Failure Diagnostics and Original Message Navigation*
  is REMOVED and replaced by the ADDED requirement *DLQ Failure Diagnostics, Original Navigation and Failed Message
  Copy* (same diagnostics and navigation scenarios, replay scenario replaced by copy-failed-message). OpenSpec cannot
  drop a scenario through MODIFIED, hence remove + add.
- `read-only-invariants-enforcement`: ADDED requirement that the gate rejects producer-mode `kcat` commands in
  source code.

## Impact

- Code: `lib/src/features/topic/utils/dlq_topic_detector.dart` (`generateKcatReplayCommand` removed, new
  `toFailureReportJson`), `lib/src/ui/messages/widgets/dlq_failure_diagnostics_card.dart` (button replaced).
- Tests: `test/src/features/topic/utils/dlq_topic_detector_test.dart`,
  `test/src/ui/messages/widgets/dlq_failure_diagnostics_card_test.dart`, `scripts/test_check_read_only.sh`.
- `scripts/check_read_only.sh` (one row), `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`.
- No Rust, no bridge, no new dependency.
- Prerequisite: `harden-read-only-gate` (its scoped check table is extended here). Should land before
  `message-selection-copy-and-display`, whose `kcat -C` command the new gate row must accept.

## Non-goals

- Any replay, re-publish or "move back" function, inside or outside the app.
- Changing DLQ detection, badges or "Jump to Original Message".
- Copy actions for ordinary messages (§5.27).
