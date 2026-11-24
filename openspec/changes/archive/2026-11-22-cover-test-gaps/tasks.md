# Tasks

## 1. Schema simplifier unit tests

- [x] 1.1 Add `test/src/features/schema/utils/schema_simplifier_test.dart` covering record, array, union, documented primitive, and non-map passthrough cases; verify with `flutter test test/src/features/schema/utils/schema_simplifier_test.dart`

## 2. Zero-coverage dialogs

- [x] 2.1 Add widget tests for the topic selection dialog (search filter, internal-topic toggle, multi-select confirm, cancel); verify with `flutter test` on that new test file
- [x] 2.2 Add widget tests for the parameter-values dialog (search, toggle, confirm/cancel, empty filter); verify with `flutter test` on that new test file — fix the search-listener dispose leak only if the new tests force it

## 3. Script history directory

- [x] 3.1 Add widget tests for the script-history list (empty and populated selection); verify with `flutter test` on the new test file
- [x] 3.2 Add widget tests for the script-run sidebar (selected run summary, unknown fields stay unknown); verify with `flutter test` on the new test file
- [x] 3.3 Extend `test/src/features/scripting/presentation/widgets/script_run_details_view_test.dart` with failure-run presentation; verify that file's tests pass

## 4. Deepen partial editor and schemas suites

- [x] 4.1 Extend `test/src/features/search/filter_expression_editor_test.dart` so invalid expressions block the builder path and suggestion precedence stays covered; verify with `flutter test test/src/features/search/filter_expression_editor_test.dart`
- [x] 4.2 Extend `test/src/features/scripting/presentation/widgets/script_schemas_view_test.dart` for empty list and unavailable/error schema data (not empty-success); verify with `flutter test` on that file

## 5. Headless runner edges

- [x] 5.1 Extend `test/src/features/scripting/headless_script_runner_test.dart` for missing required parameter (abort before connect, non-zero outcome) and one substitute-driven failure path; verify with `flutter test test/src/features/scripting/headless_script_runner_test.dart`

## 6. Coverage floors and gate check

- [x] 6.1 Run `flutter test --coverage`, apply the hand-written awk filters from backlog §1, and confirm ≥86 % hand-written, no file under 40 % except `lib/main.dart`, and `script_history/` >70 %; if short, add cases only inside the Q-5 surfaces already listed — expanded (user option 2) to also cover `app.dart`, `virtual_json_node`, `topic_config_service`, `cluster_profile_tools`, and deepen `update_dialog`; measured 86.0% / script_history 74.6% / below40=0
- [x] 6.2 Run `scripts/quality_gates.sh`, `flutter analyze`, full `flutter test`, and `scripts/check_read_only.sh`; confirm all pass (no Rust/bridge work in this change — skip codegen)

## Workflow follow-up

- Mark Q-5 / `cover-test-gaps` status in `design/code-quality-refactoring-backlog.md` §2 and §8 when archiving.
- Do not add a coverage ratchet to `openspec/config.yaml` or `scripts/quality_gates.sh`.
- Archive the change after review.
