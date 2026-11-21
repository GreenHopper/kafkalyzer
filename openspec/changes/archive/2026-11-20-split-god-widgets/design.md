# Design

## Context

Three of the four god widgets are `WatchingStatefulWidget` screens whose `State` class holds both the layout and orchestration:

- `settings_view.dart`: `_SettingsViewState` (lines 49 to 1267) holds the cluster selection, the import/export flow (`_runWithProgressDialog` 1188, `_askExportCredentials` 1215, `_handleExportConfiguration` 1226) and the section builders (`_buildDiagnosticsSection` 136, `_buildAboutAndUpdates` 333, `_buildAppearanceSection` 378, `_buildConfigImportExport` 534, `_buildClusterListContent` 903). The same file also defines `_MessageBufferLimitField`, `_ExportCredentialsChoice`, `_ExportCredentialsDialog`, `_GeneralSettingsSection` and `_IntSettingField`.
- `topic_detail_view.dart`: `_TopicDetailViewState` builds the header (530), the mode switcher (684), title row (730), tags (790), facts chips (1077) and the progress tile and actions (1532, 1571). `lib/src/features/topic/presentation/` already has `widgets/` and `controllers/`.
- `explorer_view.dart`: `_ExplorerViewState` builds the sidebar (281 to 1105) and the tab strip (1339 to 1676); `_TopicListAgeLabelState` (1686) owns a `Timer.periodic` of 30 seconds that repaints the "updated … ago" label.

Constraints: Dart privacy is per file, so a private class cannot move to another file unchanged. Existing convention in this repo is one public widget class per file under `<feature>/presentation/widgets/` (for example `lib/src/features/explorer/presentation/widgets/cluster_overview_view.dart`). The controller convention is `ChangeNotifier` + `watch_it`, registered as `registerLazySingleton` in `lib/src/dependency_injection.dart:65`, with services pulled from `getIt` in field initializers (`ClusterListController`). Accessibility and localization are covered by tests that walk the whole widget tree (`test/src/a11y/accessibility_guidelines_test.dart`). The quality gate today is `scripts/quality_gates.sh` behind the `quality-gates` job, added by `ci-quality-gates`.

## Goals / Non-Goals

**Goals:**

- Each of the three screens keeps one file that shows the screen structure, and every section lives in its own file at or below 800 lines.
- The cluster import/export flow and the topic-list refresh become callable and assertable without pumping the whole screen.
- No change to the rendered widget tree, the localization keys, or the order in which services are called.
- The size guard makes further growth expensive without a committed exception list.

**Non-Goals:**

- No change to controller registration style, no `getIt.reset()` in tests, no constructor injection across existing widgets. That is `remove-global-controller-state`.
- No behaviour change, no new strings, no renaming of public widget classes that other files import.
- No split of `messages_table_view.dart` (belongs to `relocate-messages-feature`) and no split of the other seven files above 800 lines.

## Decisions

**D1 — Extract section widgets as public classes, one class per file, under the owning feature's `presentation/widgets/`.**
Dart library privacy makes `_GeneralSettingsSection` un-movable as a private name, and the repo already uses public per-file widget classes in that directory. Alternative considered: part-files. Dart has no `part of` for widget splitting in practice (one library, so the file count grows without reducing the review unit), so it does not solve the problem.

**D2 — Move code before extracting logic, one PR per screen.**
Each PR first moves builders and their state-holders verbatim into new files, then moves orchestration into a class. A review diff that renames nothing and only moves lines is the one a reviewer can actually verify. Alternative considered: one big PR per the backlog's "one file per PR" plus simultaneous extraction. Rejected: it hides behaviour-neutral moves behind rewrites.

**D3 — `SettingsImportExportController` is a plain `ChangeNotifier` with optional constructor parameters that default to `getIt<...>()`.**
It owns: running an action with the progress dialog, the credential prompt result, and the export call. The view keeps only "which clusters are selected" and calls the controller. Constructor defaults keep every existing call site unchanged, and the injectable parameters make a fake possible today, which is what `remove-global-controller-state` would otherwise add later. Alternative considered: watch_it `StateNotifier` (the backlog's wording). Rejected for now: the repo's `ClusterListController` uses `ChangeNotifier`, and picking a second base class in the same PR adds a second thing to review; the class stays swappable because nothing outside the settings feature reads it.

**D4 — The explorer refresh becomes a small `TopicListRefreshTicker` (fake-able through `clock`/`Timer` injection), not a new controller.**
The timer's only job is a periodic repaint of one label. A full `ChangeNotifier` for it would register another global singleton, which this repo is trying to shed. Alternative considered: `Ticker`/`AnimationController` from Flutter. Rejected: it drags `TickerProviderStateMixin` into a stateless subtree and does not make the 30-second rule testable any better.

**D5 — Shared screen state stays in the screen `State` during the move.**
Cluster selection, sidebar width and tab selection stay in `_SettingsViewState` / `_ExplorerViewState`; section widgets receive values and callbacks. Alternative considered: introduce notifiers per section now. Rejected: that is the Q-3 change's job and would create churn twice.

**D6 — Size guard is a shell function inside `scripts/quality_gates.sh`, comparing the file length at the head against the merge base.**
For each hand-written `.dart` file under `lib/` that the change touches: fail if the head is over 800 lines and the merge-base version was at or below 800, and fail if the file is new and over 800. Generated sources are exempt by generation pattern (`*.g.dart`, `*.freezed.dart`, `lib/src/rust/**`, `lib/l10n/**`), which is a rule inside the check, not a list of files. Alternatives considered: (a) a committed baseline list of the eleven oversized files — rejected, the `static-analysis-gates` spec forbids an exception list; (b) failing any file over 800 lines regardless of history — rejected, it blocks unrelated feature work on `messages_view.dart` and friends; (c) a Dart analyzer plugin — rejected, a plugin is a second toolchain for a twelve-line shell loop.

**D7 — Merge base comes from the environment: `GITHUB_BASE_REF` target branch in CI, `origin/main` locally; the checkout gains `fetch-depth: 0` for the `quality-gates` job.**
Without the base revision the guard cannot tell "already oversized" from "just became oversized", so the guard fails with a tooling error instead of reporting success. Local default is `git merge-base HEAD origin/main`, with an override env var `KAFKALYZER_BASE_REF` for forks and CI reruns. Alternative considered: compare against `HEAD~1` — rejected, a PR with several commits would re-check files its earlier commits already grew.

**D8 — Verification per PR is the gate script plus the full Dart test suite, and the `read-only-gate` stays untouched.**
`scripts/quality_gates.sh` catches formatting and analysis after each move; `flutter test` catches tree changes. The a11y test is the check that a moved widget kept its semantics label and tooltip.

## Risks / Trade-offs

- **Widget tests locate by type or key.** Moving a builder into a new widget class inserts a node in the tree, so a test that expects an exact ancestor chain can break. Mitigation: the extracted widgets are plain `StatelessWidget`s that return the same subtree; run the a11y and layout tests after every PR, and keep keys on the moved nodes.
- **State that two sections share.** Settings' cluster selection is read by the cluster list and by the import/export section. If a moved widget copies the value instead of receiving it, the screen goes stale. Mitigation: selection stays in the shell during the move (D5); the controller does not mirror it.
- **The guard needs git history in CI.** `fetch-depth: 0` makes the `quality-gates` checkout slower (roughly 20 to 60 seconds on this repo). Accepted cost, and it only affects that one job.
- **A split can hide a bug for one commit.** Moving 1 200 lines is mechanical, but a dropped `await` is easy to miss. Mitigation: move-only commits are reviewed with `git diff -M` and each PR re-runs the existing tests for that screen before any extraction happens.
- **Guard threshold is arbitrary.** 800 lines comes from the backlog's "Done when". If it turns out to block legitimate files, the threshold is a constant in the script and changing it is a code change with a stated reason, not an exemption list.

## Open Questions

- Should `SettingsImportExportController` also own the cluster *import* path (currently partly in `_buildConfigImportExport`), or only export? Default assumption: both, since the progress dialog is shared by both.
- Does `explorer_view.dart`'s tab strip need its own file today, or does it fit under 800 lines after the sidebar moves? Measure after the sidebar PR; split the tab strip only if the shell stays over the limit.
