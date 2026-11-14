# Tasks

## 1. Failure report instead of replay command

- [x] 1.1 In `test/src/features/topic/utils/dlq_topic_detector_test.dart` replace the "generates valid kcat replay
      command" test with tests for `toFailureReport`: full metadata, missing original coordinates (key `original`
      absent), null key vs empty key, null value (tombstone) and headers included; verify they fail first
- [x] 1.2 In `lib/src/features/topic/utils/dlq_topic_detector.dart` delete `generateKcatReplayCommand` and add
      `toFailureReport(KafkaMessage message)` per design D1; verify the tests from 1.1 pass

## 2. Diagnostics card

- [x] 2.1 Add ARB keys `copyFailedMessage` ("Copy failed message" / "Fehlgeschlagene Nachricht kopieren") and
      `failedMessageCopied` ("Failed message copied to clipboard" / "Fehlgeschlagene Nachricht in die
      Zwischenablage kopiert") to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`; delete `copyKcatReplayCommand`
      and `kcatCommandCopied` from both; run `flutter gen-l10n`
- [x] 2.2 In `test/src/ui/messages/widgets/dlq_failure_diagnostics_card_test.dart` replace the kcat test: tapping
      `dlq_copy_failed_message_button` writes JSON whose `dlqMessage.offset` and `original.topic` match the fixture,
      and no clipboard text contains `kcat`; add a test that `find.byKey(Key('dlq_copy_kcat_button'))` finds nothing
- [x] 2.3 In `lib/src/ui/messages/widgets/dlq_failure_diagnostics_card.dart` replace `_copyKcatCommand` and the
      button per design D3 (indented `jsonEncode` of `toFailureReport`); remove the now unused `profile` usage if
      nothing else needs it; verify the widget tests pass

## 3. Read-only gate

- [x] 3.1 Add the row "Producer-mode kcat command" (design D2) to `scripts/check_read_only.sh`; in
      `scripts/test_check_read_only.sh` add rejected cases (`"kcat -b b:9092 -t orders -P"`,
      `"kafkacat -P -b b -t t"`) and accepted cases (`"kcat -C -b b:9092 -t orders -p 0 -o 42 -c 1 -e"`,
      `"kcat -L -b b:9092"`); verify both scripts exit 0 on the repository

## 4. Verification

- [x] 4.1 `dart format lib test`, `flutter analyze`, `flutter test`, `bash scripts/test_check_read_only.sh`,
      `bash scripts/check_read_only.sh`; `git grep -n -- 'generateKcatReplayCommand\|copyKcatReplayCommand'` finds
      nothing outside `openspec/` and `design/`
