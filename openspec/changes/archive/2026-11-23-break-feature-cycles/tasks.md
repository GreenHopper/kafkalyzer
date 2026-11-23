# Tasks

No Rust workspace or bridge change: this change moves Dart sources and imports
only, so no `flutter_rust_bridge_codegen generate` and no bridge-DTO work. Group
7 still runs the full verification order, including the Rust checks.

**Branch:** work happens on the existing shared `quality-improvements` branch, the
one that already carries `ci-quality-gates`, `split-god-widgets`,
`remove-global-controller-state` and `cover-test-gaps`. Do not create a branch
per change; commit the groups below straight onto it. That also means the guards
compare against `origin/main` as their merge base, so a file that this branch
already made oversized is measured against `main` — set `KAFKALYZER_BASE_REF` to
the branch point of the change if a guard reports a finding this branch did not
introduce.

## 1. Baseline

- [x] 1.1 Record the current feature import matrix and cycle list on the branch
      base (per-feature `git grep` over `lib/src/features`) and paste the numbers
      into the change directory as the comparison record; verify it reproduces the
      four cycles named in the proposal: `cluster↔topic`, `topic↔schema`,
      `topic↔search`, `topic↔scripting`
- [x] 1.2 Confirm `bash scripts/quality_gates.sh` and `flutter test` pass on the
      branch base so every later step has a green reference; verify both exit 0

## 2. Shared items with one definition

- [x] 2.1 Move the scan-step status enum from the scripting runner to the shared
      progress widget file and update the six importers, including the headless
      script runner; verify `flutter analyze` is clean and
      `flutter test test/src/features/scripting test/src/features/topic
      test/src/ui` passes with no assertion changed
- [x] 2.2 Move the consume-stream factory typedef and the bridge request wrapper
      from the per-topic stream controller into a new file in the shared services
      module, and point the topic and search controllers at it; verify
      `flutter analyze` is clean, that the new file contains no
      `src/features/` import, and that `flutter test test/src/features/search
      test/src/features/topic` passes
- [x] 2.3 Move the environment badge and the insecure-TLS badge (with their
      palette helper) to the shared widgets directory and rewrite the imports in
      `cluster`, `explorer`, `settings` and `topic`; verify the badge tests
      `test/src/features/cluster/presentation/widgets/insecure_tls_badge_test.dart`
      and `cluster_ergonomics_widgets_test.dart` pass and that no
      `features/cluster/` import remains in `topic` presentation widgets
- [x] 2.4 Move the topic selection dialog and its test from the search feature to
      the topic feature's widgets and update the script step editor import; verify
      `flutter test test/src/features/search/presentation/widgets` passes from its
      new path and that the search feature has no `features/topic/` import left
- [x] 2.5 Re-run the matrix from 1.1 and verify the `topic↔scripting`,
      `scripting→search→topic→scripting` and `search→topic` edges are gone while
      `flutter analyze` and `flutter test` stay green

## 3. Schema dialogs behind a topic-name port

- [x] 3.1 Add the read-only topic-name port (known topic names for a profile, or
      unknown when not loaded) to the shared services module and implement it in
      the topic feature over its own controller; verify a unit test covers both
      the loaded and the not-loaded answer
- [x] 3.2 Wire the implementation once in the composition root next to the other
      stateless services and verify that the registration list still contains
      exactly the enumerated session-wide state types, so
      `bash scripts/quality_gates.sh locator-guard` passes unchanged
- [x] 3.3 Replace the container lookup of the session-wide topic controller in the
      schema diff and schema viewer dialogs with the port, make the topic-name
      input required, and update the two production callers and the dialog tests;
      verify `flutter test test/src/features/schema/presentation/widgets` passes
      and that neither dialog contains a `getIt.isRegistered` lookup
- [x] 3.4 Add the unknown-input case to the associated-topics test and verify the
      dialog presents the not-loaded state as unknown rather than as an empty
      association list, matching the existing failure-case presentation
- [x] 3.5 Re-run the matrix and verify the `topic↔schema` cycle is gone and that
      `schema` has no import of any `topic` source

## 4. Topic view state out of the connection controller

- [x] 4.1 Move the topic list query, filter, sort, favourite, unhealthy-only and
      preference-notice state, plus the memoised topic list view, from the
      connection controller to the session-wide topic controller; verify
      `flutter test test/src/features/explorer test/src/features/cluster` passes
      with the existing topic-sidebar and preference-notice assertions unchanged
- [x] 4.2 Move the factory and cache for the per-topic stream, facts and analysis
      controllers into one new controller-registry file in the topic module,
      reached from the topic controller; verify `getStreamController`,
      `getAnalysisController` and `getTopicFactsController` no longer appear in
      `cluster` and that the explorer and topic detail tests pass
- [x] 4.3 Move cache clearing for the per-topic controllers to the topic cache and
      to the disconnect path, and add one regression test per cache that asserts
      the clear on cluster switch and on topic-list refresh; verify the new tests
      fail before the move and pass after it
- [x] 4.4 Replace the topic-controller parameter of the cluster picker with a
      "has cached topics" predicate and a listenable supplied by its caller, and
      update the explorer sidebar call site and the picker tests; verify
      `flutter test test/src/features/cluster/presentation/widgets` passes and the
      picker still bolds only clusters with cached topics
- [x] 4.5 Regenerate the checked-in mock files that reference the moved members
      (`dart run build_runner build`) and verify the generated files show the new
      seam with no hand edits
- [x] 4.6 Re-run the matrix and verify the feature graph is acyclic, that the
      connection controller imports no `features/topic/` source, and that both the
      connection controller and the topic controller stay at or below the 800-line
      size limit

## 5. Import-cycle guard in the quality gate

- [x] 5.1 Add the guard to `scripts/quality_gates.sh`: build the feature module
      graph from hand-written sources in the worktree and at the merge base, and
      fail when a pair of modules becomes mutually reachable, naming the modules
      on the new cycle and the touched source; verify `bash
      scripts/quality_gates.sh` passes on this branch and that the guard reports
      zero new cycles
- [x] 5.2 Fail closed on tooling problems: reuse the existing base-resolution
      helper so a missing base revision, a missing merge base or an unresolvable
      touched source produce a named error instead of a pass; verify by running
      the guard with `KAFKALYZER_BASE_REF` pointed at a nonexistent ref
- [x] 5.3 Keep the generated-source exemption identical to the size guard
      (`*.g.dart`, `*.freezed.dart`, `lib/src/rust/*`, `lib/l10n/*`) and verify by
      adding a generated-shaped import in a scratch fixture run
- [x] 5.4 Add fixture cases to `scripts/test_quality_gates.sh`: new cycle fails,
      removed cycle passes, pre-existing cycle untouched passes, generated source
      exempt, unresolvable source is a tooling error; verify `bash
      scripts/test_quality_gates.sh` exits 0 and prints each case name
- [x] 5.5 Confirm the CI job needs no workflow edit and verify that
      `.github/workflows/build.yml` still runs `bash scripts/quality_gates.sh` in
      the `quality-gates` job, and that a locally failing guard is the same check
      the pipeline reports

## 6. Rules and documentation

- [x] 6.1 Add the dependency-direction rule to `context` (Code Quality & Style)
      in `openspec/config.yaml`: one direction per feature pair, an item used by
      two or more features lives once in a shared module, a reverse need is met by
      relocating the item or by a narrow port; verify the YAML still parses and
      `openspec instructions proposal --change break-feature-cycles --json`
      returns the updated context
- [x] 6.2 Add the import-cycle guard to the enumerated check list in
      `context.Verification` step 6 of `openspec/config.yaml` and verify the list
      matches the checks `scripts/quality_gates.sh` actually runs
- [x] 6.3 Add one `rules.design` entry in `openspec/config.yaml`: a change must not
      add a feature import cycle and must state where a relocated item goes;
      verify `openspec instructions design --change break-feature-cycles --json`
      lists it
- [x] 6.4 Update `design/code-quality-refactoring-backlog.md`: mark Q-6 in the
      section 8 table as implemented by this change, replace the section 5 edge
      matrix and cycle list with the post-change numbers, and record the new guard
      in the section 2 result style; verify the matrix in the document matches the
      matrix printed by task 5.1

## 7. Integration verification

- [x] 7.1 Run the full order and verify every step is green: `cargo fmt --all`,
      `cargo clippy --workspace --all-targets`, `cargo test --workspace` (in
      `rust/`), `dart format --output=none --set-exit-if-changed lib test`,
      `flutter analyze`, `flutter test`, `scripts/check_read_only.sh` with no new
      exception, and `scripts/quality_gates.sh` including the new guard
- [x] 7.2 Spot-check the user-visible invariants on a running app (2026-11-22:
      the four checks were confirmed by the user in the running app: topic list
      filters and favourites survive the round trip, the schema dialogs show
      associated topics and the unknown state, the cluster picker still marks
      cached clusters, and the progress and timeline status text is unchanged)
      (`flutter run -d linux`): topic list filters and favourites persist across a
      navigation round trip, the schema diff dialog shows associated topics or an
      unknown state, the cluster picker still marks clusters with cached topics,
      and the topic detail progress tile and the script timeline show the same
      status text as before

## Workflow follow-up

- Ask the user to apply the change only after these artifacts are reviewed; the
  apply workflow is a separate, explicit request.
- Archive the change once the review requirements are met and confirm the two
  spec files merge as expected: `feature-module-boundaries` becomes a new main
  spec and `static-analysis-gates` gains the guard requirement.
- Mark the section 8 status of `enable-rust-lint-gate` separately — it stays open
  and is not part of this change.
