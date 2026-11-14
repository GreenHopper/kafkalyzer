## Context

`DlqFailureMetadata.generateKcatReplayCommand` (`lib/src/features/topic/utils/dlq_topic_detector.dart:32-52`) builds
`printf '%s' '<payload>' | kcat -b <bootstrap> -t <originalTopic> -P [-k '<key>']`. The card
(`dlq_failure_diagnostics_card.dart`, button key `dlq_copy_kcat_button`) copies it with the active profile's
bootstrap servers. The spec `dead-letter-queue-detection` requires this action (scenario *Copying external replay
command for message remediation*). Guardrail L1 of the roadmap forbids produce/replay; the user decided to remove
the action and offer a copy of the failed message instead.

The inspector already has a "copy full message as JSON" button (`message_inspector_panel.dart`,
`_formatFullMessageJson`). §5.27 reworks message JSON copying (`timestampIso`, null vs empty) for rows and the
inspector.

## Goals / Non-Goals

**Goals:** no producer command anywhere in the app; a copy action on the card that carries everything an external
reprocessing tool needs; a gate row that keeps producer-mode `kcat` commands out.

**Non-Goals:** a shared message-JSON serializer for all copy actions (owned by §5.27); any replay feature.

## Decisions

### D1 Failure report JSON built in `DlqFailureMetadata`

Add `Map<String, Object?> toFailureReport(KafkaMessage message)` plus a `jsonEncode` with indentation at the call
site. Shape:

```json
{
  "dlqMessage": {"topic": "...", "partition": 0, "offset": 42, "timestamp": 1700000000000,
                 "key": "k" | null, "value": "..." | null, "headers": {"x-exception-message": "..."}},
  "original": {"topic": "orders", "partition": 0, "offset": 123},
  "exception": {"message": "...", "class": "..."}
}
```

`original` and `exception` are omitted when unknown. The stack trace stays in `headers` (no duplication). Keeping it
next to the header parsing keeps the change small; when §5.27 introduces a shared message serializer, `dlqMessage`
can delegate to it without changing the output.

Alternative considered: reuse `_formatFullMessageJson` from the inspector. It is private to the panel, uses a
locale-formatted date and turns `""` into `null` (finding in §5.27), so it is not reused.

### D2 Gate row

Add a row "Producer-mode kcat command" with scope `all` (Dart and Rust sources) and regex
`(kcat|kafkacat)[^"'\`]*[[:space:]]-P([^A-Za-z]|$)`. It matches the command inside one string literal; a command
assembled from separate literals would not be caught, which is accepted (the check is a tripwire, not a proof).
Today the only hit is `dlq_topic_detector.dart:44`, which this change deletes. The `kcat -C` command from §5.27 has
no `-P` and passes.

### D3 Button

Same position and style as today, icon `Icons.content_copy`, key `dlq_copy_failed_message_button`, label from
`copyFailedMessage`, notice from `failedMessageCopied`. The keys `copyKcatReplayCommand` and `kcatCommandCopied` are
deleted from both ARB files.

## Risks / Trade-offs

- [Users relied on the replay command] → Accepted by decision; the copied JSON carries key, value and headers, which
  external tools can consume. Mention in release notes.
- [Regex misses split strings] → Accepted; unit tests and review cover the rest.

## Migration Plan

No data migration. Rollback = revert the commit.
