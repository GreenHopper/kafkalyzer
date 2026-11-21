# Proposal

## Why

Four hand-written presentation widgets have become the place where most feature work lands, and each of them mixes a screen, several unrelated sections, orchestration code and a timer in a single `State` class: `settings_view.dart` (1 905 lines, one state class of 1 218 lines), `topic_detail_view.dart` (1 769 lines, one method of 286 lines), `explorer_view.dart` (1 721 lines, sidebar plus tab strip plus a periodic refresh timer) and `messages_table_view.dart` (1 598 lines). Every change to Settings, Explorer or the topic screen produces 300-line diffs in the same file, and the parts that most need tests — the cluster import/export flow and the 30-second topic-list refresh — cannot be exercised without pumping the whole screen.

## What Changes

- Split `lib/src/features/settings/presentation/settings_view.dart` into one file per section under `lib/src/features/settings/presentation/widgets/` (diagnostics, appearance, about and updates, general settings, cluster import/export, cluster list), leaving `settings_view.dart` as the screen shell.
- Move the cluster import/export orchestration (progress dialog, credential prompt, export action, currently lines 1188 to 1267 plus `_ExportCredentialsDialog`) out of the widget `State` into a `SettingsImportExportController` with injectable dependencies, following the existing `ClusterListController` pattern.
- Split `lib/src/features/topic/topic_detail_view.dart`: header, mode switcher, title row, tags, facts chips, progress tile and progress actions move into `lib/src/features/topic/presentation/widgets/`, and the tab content moves to one widget per tab. The file keeps the shell and the state that the tabs share.
- Split `lib/src/features/explorer/presentation/explorer_view.dart` into sidebar parts (header, cluster list, topic controls, topic filter, topic list), tab strip parts and the error box under `lib/src/features/explorer/presentation/widgets/`, and move the periodic refresh of the topic-list age labels (`_TopicListAgeLabel`, line 1692) into a testable timer holder.
- Add a source-file size guard to the quality gate: a hand-written Dart file in `lib/` that is at or below the 800-line limit at the merge base MUST NOT exceed it at the head of the change. Files already above the limit stay exempt without any committed exception list, so unrelated work on `messages_view.dart` or `smart_virtual_json_tree.dart` is not blocked by this change.
- Out of scope, deliberately: `messages_table_view.dart` (1 598 lines). The change `relocate-messages-feature` moves `lib/src/ui/messages/` to `lib/src/features/messages/`, and splitting the file before that move would rework the same diff twice. It is split in that change instead. Also out of scope: the remaining files above 800 lines (`topic_schema_inspector_view.dart` 1 478, `message_inspector_panel.dart` 1 416, `topic_search_bar.dart` 1 411, `messages_view.dart` 1 297, `consumer_lag_view.dart` 1 287, `smart_virtual_json_tree.dart` 1 204, `topic_analysis_view.dart` 1 057). They are frozen by the size guard and split by later changes.

## Capabilities

### New Capabilities

None. The split changes no observable behaviour, and the behaviour of the three screens is already specified by `explorer-onboarding`, `main-navigation`, `appearance-settings`, `cluster-profile-persistence`, `archive-import-safety` and `ergonomic-settings-and-cluster-onboarding`. Those specs are the regression contract for this change and are not re-specified here.

### Modified Capabilities

- `static-analysis-gates`: the gate gains one check — a source-file size guard for hand-written Dart files under `lib/`, scoped to files the change touches, with no committed baseline or exception list.

## Impact

- **Code**: `lib/src/features/settings/presentation/` (1 file becomes 1 shell plus about 7 files), `lib/src/features/topic/presentation/widgets/` and `lib/src/features/topic/topic_detail_view.dart`, `lib/src/features/explorer/presentation/widgets/` and `lib/src/features/explorer/presentation/explorer_view.dart`. No `lib/src/ui/messages/` change, no Rust change, no bridge change.
- **Tests**: existing widget tests (`test/src/features/explorer/presentation/explorer_view_test.dart`, `test/src/a11y/accessibility_guidelines_test.dart`, `test/src/ui/main_layout_test.dart`, the messages table tests and the settings-related tests) must pass unchanged, because the public widget types and the widget tree the tests pump do not change. New unit tests are added for `SettingsImportExportController` and for the refresh timer holder.
- **Tooling**: `scripts/quality_gates.sh` gains the size guard; the existing `quality-gates` job in `.github/workflows/build.yml` needs a full checkout so the guard can read the merge-base revision of the changed files.
- **Docs**: `README.md` quality-gate section and `openspec/config.yaml` (the style section gains the 800-line limit, the verification list names the new check).
- **Read-only impact**: no new Kafka or Schema Registry calls. The split moves existing describe-only calls behind new classes; the `read-only-gate` job runs unchanged.
- **Prerequisites**: `ci-quality-gates` must be merged first — this change adds a check to the gate script and job that change introduced.
- **Depends-on for sequencing**: none. `remove-global-controller-state` re-registers controllers later; the controller added here is written with injected dependencies so that change only has to move its registration.
