# Tasks

Branch condition: all work stays on the existing `quality-improvements`
branch — the quality work of this repository is tracked on that one branch, and
this change does not start a branch of its own.

## 1. Baseline and go/no-go measurement

- [x] 1.1 Record the current feature import matrix (expected: 48 cross-feature
      import files, 18 one-directional pairs, zero cycles) and the current
      surface inventory (17 files / 7 028 lines in `lib/src/ui/messages`,
      19 test files / 6 285 lines in `test/src/ui/messages`) in
      `openspec/changes/relocate-messages-feature/baseline-feature-graph.md`,
      and verify the numbers come from the same walk the guard uses
      (`KAFKALYZER_REPO_DIR`-pinned call of `feature_edges` in
      `scripts/quality_gates.sh`), not from an ad-hoc grep
- [x] 1.2 Record the projected matrix of a plain `git mv` (expected: 10
      mutually reachable pairs, six of them between `scripting`, `search`,
      `topic` and `navigation`) and the 7 files outside the surface that import
      it, and verify by re-running the projection with the relocations of
      design D3-D6 applied so the projected cycle count is zero — this is the
      go/no-go gate for the whole change
- [x] 1.3 Record the three ambient session-wide lookups in
      `lib/src/ui/messages/widgets/message_inspector_panel.dart` (lines
      1074-1075 and 1378-1379) as the locator-guard finding the move would
      otherwise produce, and verify `KAFKALYZER_BASE_REF=origin/main
      scripts/quality_gates.sh locator-guard` still passes before any edit

## 2. Relocate the shared message data (D3, D4, D5)

- [x] 2.1 Move `ScriptResultMessage` to `lib/src/features/messages/domain/` and
      rewrite every importer (`messages_view.dart`, the table, timeline and
      metadata-card sources, `scripting` producers and their tests); verify
      `flutter analyze` is clean and `flutter test test/src/features/scripting
      test/src/ui/messages` passes
- [x] 2.2 Move `ScriptExtraction` and `ExtractionUtils` to the same domain
      directory, keeping `Script` in `scripting`; verify `flutter analyze` is
      clean and the timeline-view tests pass, including the extraction-value
      caching test
- [x] 2.3 Move `MessageReference` from `lib/src/features/navigation/models/` to
      the messages domain directory, with its test file
      (`test/src/features/navigation/models/message_reference_test.dart`), and
      rewrite the palette and quick-jump importers; verify
      `flutter test test/src/features/navigation test/src/features/messages`
      once the messages tests are moved, and `flutter test
      test/src/features/navigation` in the meantime
- [x] 2.4 Split `lib/src/features/topic/utils/dlq_topic_detector.dart`: move
      `DlqFailureMetadata` to `lib/src/features/messages/domain/dlq_failure_metadata.dart`,
      leave `DlqTopicDetector` in `topic`, and split the test file the same way;
      verify `flutter test test/src/features/topic/utils
      test/src/ui/messages/widgets/dlq_failure_diagnostics_card_test.dart`
      passes and no source under `lib/src/ui/messages` imports
      `features/topic/utils/`
- [x] 2.5 Re-run the matrix from 1.1 and append it to
      `baseline-feature-graph.md`; verify the cross-feature pair set is
      unchanged from 1.1 (zero cycles) and that `lib/src/ui/messages` no longer
      imports `scripting/domain/`, `navigation/models/` or
      `topic/utils/dlq_topic_detector.dart`

## 3. The diff kit becomes shared UI (D6)

- [x] 3.1 Move `lib/src/features/scripting/presentation/widgets/diff/` (6
      files) to `lib/src/ui/diff/` with its 5 test files, and rewrite the
      importers in `scripting` (`script_schemas_view.dart`),
      `messages/views/messages_diff_view.dart` and
      `lib/src/dependency_injection.dart`; verify `flutter analyze` is clean,
      `flutter test test/src/features/scripting/presentation/widgets/diff
      test/src/ui/messages/views/messages_diff_view_test.dart` passes, and the
      size guard reports nothing (`wc -l` of each moved file unchanged)
- [x] 3.2 Verify `lib/src/ui/diff/` imports no feature module
      (`grep -c "package:kafkalyzer/src/features/" lib/src/ui/diff/*.dart` is 0
      for every file) and append the resulting edge list to
      `baseline-feature-graph.md`

## 4. Cut the inspector's container fallbacks (D7, D8)

- [x] 4.1 Make `onJumpToOriginalMessage` on `MessageInspectorPanel` a required
      parameter, delete the `getIt<ActiveConnectionController>()` default, and
      wire `messages_view.dart` and
      `lib/src/features/consumer/presentation/topic_partition_table.dart`,
      threading a new callback through `MessagesView` to its callers in `topic`,
      `search` and `scripting`; verify the existing DLQ-card jump tests still
      pass and `KAFKALYZER_BASE_REF=origin/main scripts/quality_gates.sh
      locator-guard` reports no finding
- [x] 4.2 Delete the panel's own `TopicSchemaInspectorView` construction and its
      second `ActiveConnectionController` lookup, move the "no active cluster"
      empty state to the caller that supplies the schema builder, and verify
      `flutter test test/src/ui/messages/widgets/message_inspector_panel_test.dart`
      plus the topic-detail inspector tests pass with the injected builder
- [x] 4.3 Remove the `features/topic/topic_utils.dart` import from the panel by
      passing the already-formatted topic text in (design D8); verify
      `flutter analyze` reports no unused import and
      `grep -c "features/topic/" lib/src/ui/messages/widgets/message_inspector_panel.dart`
      is 0
- [x] 4.4 Add a widget test for the injected-jump path asserting the panel calls
      the callback with the original topic, partition and offset and performs no
      container lookup, and a test for the schema tab absent a builder asserting
      the panel shows no schema tab rather than a made-up one; verify both pass

## 5. Move the surface into the feature module (D1, D9)

- [x] 5.1 `git mv lib/src/ui/messages lib/src/features/messages` into the house
      layout (`presentation/views`, `presentation/widgets`,
      `presentation/models`, `domain`) and rewrite every `package:kafkalyzer`
      import in the 7 external importing files and inside the surface; verify
      `flutter analyze` is clean and the commit diff contains only moves and
      import lines (`git show --stat` plus a check that no non-import line
      changed)
- [x] 5.2 `git mv test/src/ui/messages test/src/features/messages`, mirror the
      subdirectories, and rewrite the test imports; verify `flutter test` runs
      the whole suite green (expected count: the current suite plus the
      regression tests from 4.4)
- [x] 5.3 Update the path-keyed row in
      `test/l10n/hardcoded_strings_allowlist.txt` for
      `message_inspector_panel.dart` and verify the hard-coded-strings test
      passes with no new allowlist entry added
- [x] 5.4 Run the full guard set with the pinned base
      (`KAFKALYZER_BASE_REF=origin/main timeout 900 bash scripts/quality_gates.sh`)
      and verify it prints "Quality gate passed." — zero new mutually reachable
      pairs, no locator finding in `lib/src/features/messages/presentation`,
      and no size finding — and append the final matrix to
      `baseline-feature-graph.md`, showing `messages` with an empty outgoing row

## 6. Rules and documentation

- [x] 6.1 Update the `Tech Stack` source-layout text in `openspec/config.yaml`
      so it says what the tree now is: a surface with its own views, widgets and
      models is a feature module even when several features consume it, and
      `lib/src/ui/` holds app chrome plus feature-neutral UI (smart tree, diff
      kit, shared utils); verify `openspec instructions proposal --change
      relocate-messages-feature --json` returns the updated context
- [x] 6.2 Verify the boundary and locator rules in `openspec/config.yaml` need
      no further edit and record the answer in
      `baseline-feature-graph.md`: the Code Quality bullet added by
      `break-feature-cycles` already names the shared modules, and a new
      "shared modules must not import features" rule is deliberately not added
      because 11 sources under `lib/src/services/` and `lib/src/ui/` violate it
      today — that belongs to `relocate-feature-services`
- [x] 6.3 Update `design/code-quality-refactoring-backlog.md`: mark
      `break-feature-cycles` section 5 numbers as superseded by this change's
      matrix, mark `relocate-messages-feature` implemented in the section 8
      list, and state in the section 3 Q-7 row that the god-widget split of the
      three >800-line message sources was **not** part of the move; verify the
      matrix in the document matches the matrix printed by 5.4
- [x] 6.4 Add the deferred split as its own backlog row with a fixed change id
      (`split-messages-surface`: `messages_table_view.dart` 1 598 L,
      `message_inspector_panel.dart` 1 416 L, `messages_view.dart` 1 297 L, and
      the `openTopicByNameWithFeedback` helper that still takes a cluster
      controller) and verify the section 8 list names it; this closes the debt
      the `split-god-widgets` result note handed to Q-7

## 7. Integration verification

- [x] 7.1 Run the full order and verify every step is green: `cargo fmt --all`,
      `cargo clippy --workspace --all-targets`, `cargo test --workspace` (in
      `rust/`), `dart format --output=none --set-exit-if-changed lib test`,
      `flutter analyze`, `flutter test`, `scripts/check_read_only.sh` with no
      new exception, `scripts/quality_gates.sh` and
      `bash scripts/test_quality_gates.sh` (the guard fixture suite, unchanged)
- [x] 7.2 Spot-check the user-visible invariants on a running app (2026-11-23:
      everything else in group 7 is green — 1 365 Dart tests, clippy, analyze,
      read-only gate, quality gates with rename-aware size guard; this one is
      the manual pass the user runs in the app)
      (`docker compose up -d && flutter run -d linux`): the message table,
      timeline and diff views render for a topic stream and for a script run,
      the inspector's schema tab shows the same content as before, the DLQ card
      jumps to the original message, a copied message reference still lands in
      the command palette, and the consumer lag panel shows its inspector

## Workflow follow-up

- The change declares `skip_specs: true`: it adds no requirement. The
  capability that carries the rules this change obeys,
  `feature-module-boundaries`, is already merged into `openspec/specs/`
  (`break-feature-cycles` archived 2026-11-23), so nothing has to be archived
  before this change.
- Ask the user to apply the change only after these artifacts are reviewed; the
  apply workflow is a separate, explicit request.
- `relocate-feature-services` (Q-8) picks up
  `lib/src/services/message_export_service.dart`, which imports this now-moved
  feature, and the "shared modules must not import features" rule deferred in
  6.2.
