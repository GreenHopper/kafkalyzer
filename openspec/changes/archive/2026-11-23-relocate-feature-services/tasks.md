# Tasks

No Rust, bridge or ARB changes: this is a Dart source re-organisation plus one
guard. After every group, run `flutter analyze` and the tests of the files that
moved, and keep `KAFKALYZER_BASE_REF=origin/main bash scripts/quality_gates.sh cycle-guard`
and `locator-guard` green.

## 1. Baseline and go/no-go

- [x] 1.1 Record in `baseline-feature-graph.md`: the direct feature matrix (23 pairs, 0 cycles), the hidden-path matrix with its 10 mutually reachable pairs and the 7 hidden edges, and the 11 shared → feature sources from design.md Context. Use one script that counts both and keep it in the file
- [x] 1.2 Project the end state (D1–D6 applied on paper) with the same script and record it: expect 27 direct pairs (+`settings → topic`, `settings → scripting`, `consumer → schema`, `search → schema`), 0 direct cycles, 0 hidden pairs. Any projected cycle is a stop: revise the design before moving anything
- [x] 1.3 Record the stored-data keys and file names each of the seven services uses (grep the preference keys and paths), so 7.x can confirm they are byte-identical after the moves

## 2. Single-consumer moves (D5)

- [x] 2.1 `git mv lib/src/features/schema/utils/schema_path_utils.dart lib/src/ui/smart_tree/` and its test to `test/src/ui/smart_tree/`; rewrite imports
- [x] 2.2 `git mv lib/src/ui/script_progress_widget.dart lib/src/features/scripting/presentation/widgets/` and its test; rewrite imports
- [x] 2.3 Move `SearchProgress` from `multi_search_controller.dart` to `lib/src/ui/topic_progress_tile.dart`, next to `StepStatus`. Point `multi_search_controller`, `script_runner` and `topic_detail_progress_tile` at it and drop the tile's search import. Analyze + run the tile, search and script-runner tests

## 3. Service moves (D1)

- [x] 3.1 `topic`: `git mv` `topic_analysis_history_service`, `topic_analysis_export_service`, `topic_list_preferences_service` → `lib/src/features/topic/data/` (+ tests → `test/src/features/topic/data/`); rewrite imports including `dependency_injection.dart` and `settings/.../general_settings_section.dart`
- [x] 3.2 `search`: `saved_searches_service` → `lib/src/features/search/data/` (+ test)
- [x] 3.3 `messages`: `message_export_service` → `lib/src/features/messages/data/` (+ test); rewrite `search/domain/search_json_serializer.dart`
- [x] 3.4 `schema`: `local_schema_assignment_service` → `lib/src/features/schema/data/` (+ test); rewrite the topic, consumer, search and schema importers
- [x] 3.5 `cluster`: `recent_topics_service` → `lib/src/features/cluster/data/` (+ test); rewrite the cluster and explorer importers
- [x] 3.6 Run `dart run build_runner build` and confirm that only the import paths in checked-in `*.mocks.dart` changed. Check with `git diff -M --stat` that every moved file is ≥ 95 % similar (import lines only). Run analyze and the full Dart test suite

## 4. Remove the last shared → feature imports (D3, D4)

- [x] 4.1 Delete the two controller reloads from `SettingsService.importConfiguration`. Add them to the import handler in `settings_config_section.dart`, after a successful return and before the success feedback. Drop the stub-controller registrations from `settings_service_test.dart` and `passphrase_redaction_test.dart`
- [x] 4.2 Add a widget test in `settings_view_test.dart`: after a successful import, both the cluster list and the script list reload before the success message; on a failed import, neither reloads
- [x] 4.3 `git mv lib/src/ui/storage_notice_banner.dart lib/src/features/settings/presentation/widgets/` and its test; rewrite `main_layout.dart`. Run `locator-guard`; if the `settings` count rises, pass both controllers in from `main_layout` instead of weakening the guard (design Risks)

## 5. Composition root (D6)

- [x] 5.1 `git mv lib/src/ui/main_layout.dart lib/src/main_layout.dart` and `test/src/ui/main_layout_test.dart` → `test/src/main_layout_test.dart`; rewrite `app.dart` and relative imports in the test
- [x] 5.2 Confirm with `rg` that no hand-written file under `lib/src/{ui,services,utils}/` references `features/` (package or relative), and re-run the 1.1 script: direct and hidden matrices must be identical, with 0 cycles. Append the result to `baseline-feature-graph.md`

## 6. Shared-module import guard (D7)

- [x] 6.1 Add `check_shared_imports` to `scripts/quality_gates.sh`: list hand-written `*.dart` under `lib/src/ui`, `lib/src/services`, `lib/src/utils` (same generated-file exemption as the size guard), resolve `import`/`export` targets (package and relative), and fail with `file → feature` per finding. An unreadable listed file is a named tooling error. Add a `shared-guard` entrypoint and run it in the full gate after the cycle guard
- [x] 6.2 Fixtures in `scripts/test_quality_gates.sh`: clean tree passes; shared file with a package import of a feature fails and names both; relative import into a feature fails; `export` of a feature fails; `.g.dart` under a shared folder is exempt; a top-level `lib/src/*.dart` importing a feature passes; an unreadable listed file fails with a tooling error
- [x] 6.3 Run `bash scripts/test_quality_gates.sh`: all old and new fixtures pass

## 7. Rules, backlog, verification

- [x] 7.1 `openspec/config.yaml`: in Tech Stack source layout, say that `lib/src/services/` holds services no single feature owns, that a service whose stored data one feature owns lives in that feature's `data/`, and that the top level of `lib/src/` is the composition root. In the Code Quality boundary bullet, say that shared modules import no feature module and that the shared-module guard enforces it. In `rules.design` "Module boundaries", add that no shared module gains a feature import. Add the guard to verification step 6
- [x] 7.2 `design/code-quality-refactoring-backlog.md`: correct and close the Q-8 row (seven services incl. `message_export_service`, `diff_ignore_list_service` stays shared, why `recent_topics_service` goes to `cluster`). Replace the §5 matrix, noting that the hidden-path count is now 0, and set §8 to implemented
- [x] 7.3 Confirm that the stored keys and file names from 1.3 are unchanged (grep against the moved files)
- [x] 7.4 Full verification, every step exits 0: `cargo fmt --all --check`, `cargo clippy --workspace --all-targets`, `cargo test --workspace`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, `scripts/check_read_only.sh` (no new exception), `KAFKALYZER_BASE_REF=origin/main bash scripts/quality_gates.sh`, `bash scripts/test_quality_gates.sh`
- [x] 7.5 Manual app check (user): saved searches, recent topics, topic-list sort and filter, saved analysis reports (open and delete from Settings), local schema assignment, message export, settings import refreshing the cluster and script lists, and the storage notice banner, all as before
