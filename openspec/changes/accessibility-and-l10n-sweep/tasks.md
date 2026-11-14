# Tasks

Dart only. `rust/` and `rust/src/api/` stay untouched, so no `cargo` steps, no `flutter_rust_bridge_codegen generate`
and no `dart run build_runner build`. Start only after all other Phase 0 and Phase 1 changes are merged (see
proposal, Prerequisites). "Verify after X" means: check what change X left, then fix only what is still wrong. Every
group adds its en + de ARB keys (`lib/l10n/app_en.arb` template, `lib/l10n/app_de.arb`) following design D2 (reuse an
existing key with the same meaning first). Then it runs `flutter gen-l10n` and its widget tests in German (`locale:
Locale('de')`).

## 1. Spike and baseline

- [ ] 1.1 Spike: add `analyzer: ^13.3.0` (the version in `pubspec.lock`) under `dev_dependencies`, run
      `flutter pub get`, and check with `git diff pubspec.lock` that only `analyzer` changes from `transitive` to
      `direct dev`. Write a throwaway test that calls `parseString(content:, throwIfDiagnostics: false)` on every
      `lib/src/**/*.dart` file outside `lib/src/rust/` and prints the file count. Verify: no other package version
      moves, every file parses, and the run takes less than 10 s. If either check fails, remove the dependency and
      use the regex fallback from design D4 in group 3.
- [ ] 1.2 Re-run inventory commands A–F from `design.md` on the rebased tree and save the output as
      `/tmp/a11y-baseline.txt` (not committed). Compare it with the design baseline and list in the PR description
      every item a sibling already fixed. Verify: each "verify after" task below is either marked done-by-sibling in
      the PR description or still has a hit in the output.

## 2. ARB catalogue consistency (spec: Consistent Translation Catalogues)

- [ ] 2.1 Write `test/l10n/arb_consistency_test.dart` (design D5): duplicate top-level keys per file, en/de key
      parity, en/de top-level ICU placeholder equality, en placeholders declared in `@key.placeholders`. Verify RED: it
      fails on `matchesCount`, `@matchesCount`, `noVariablesRequired` and `noDifferencesFound`.
- [ ] 2.2 Split the duplicates (design D2): keep `matchesCount` = "{current} / {total} matches" (+ de), add
      `scriptRunMatchedOfExamined` and use it in `script_run_sidebar.dart`, keep `noDifferencesFound` = "No differences
      found." for `json_diff_widget.dart`, add `schemaNoDifferencesFound` and use it in `schema_diff_dialog.dart`, and
      keep one `noVariablesRequired` (de "Keine Variablen erforderlich."). Verify: 2.1 is GREEN, and widget tests
      `message_inspector_panel_search_test.dart` and `schema_diff_dialog_test.dart` (updated) find the respective
      texts.

## 3. Hard-coded-string guard with shrinking baseline (spec: Guard Against Hard-coded User-facing Text)

- [ ] 3.1 Write `test/l10n/hardcoded_strings_guard_test.dart` (design D4 rules 1–5) and
      `test/l10n/hardcoded_strings_allowlist.txt`. Add unit cases on in-memory source snippets: literal in `Text`,
      `tooltip:`, a ternary inside `Text`, `l10n?.x ?? 'Fallback'` (ignored), `ClipboardData(text: 'x')` (ignored),
      `languageCode == 'de'` (finding), and a stale allowlist entry (failure). Verify: the unit cases pass.
- [ ] 3.2 Generate the initial allowlist from the guard's findings. Mark the 14 technical literals with their reasons
      (protocol, SASL mechanism, date pattern, subject name, product name). Mark every other entry with reason
      `TODO accessibility-and-l10n-sweep group <n>`. Verify: the guard test passes on the full tree. From now on every
      group below removes its entries, and the stale-entry check enforces that.

## 4. Test harness preparation

- [ ] 4.1 Add `localizationsDelegates: AppLocalizations.localizationsDelegates` and `supportedLocales` to the 13 test
      files that pump without them (design Context list, e.g. `json_or_string_viewer_test.dart`,
      `hex_viewer_test.dart`, `timestamp_picker_field_test.dart`, `script_editor_test.dart`,
      `topic_progress_tile_test.dart`, `smart_composite_badge_test.dart`, `tombstone_widget_test.dart`,
      `script_progress_widget_test.dart`, `kafka_message_table_test.dart`, `scroll_utils_test.dart`,
      `messages_table_view_projection_test.dart`, `cluster_dropdown_test.dart`, `lag_trend_test.dart`). Verify:
      `flutter test` is green with no production code changed.

## 5. Messages from non-widget code (spec: Localized Messages From Background Operations)

- [ ] 5.1 Add `ConnectionError`/`ConnectionErrorKind` and a pure `classifyConnectionError(Object error)` function
      (design D3). Unit test: `BrokerTransportFailure` → `brokerTransport`, "Connection refused" →
      `connectionRefused`, `AnyhowException(msg)` → `other` with detail `msg`, failed validation →
      `validationFailed`, an unknown error → `other` with its first line, never an empty detail. Verify RED, then GREEN.
- [ ] 5.2 Switch `ActiveConnectionController.connect` to `ConnectionError`. If 5.26 added a bootstrap-validation
      error there, map it to `invalidBootstrapServers` and keep its ARB key. Update
      `active_connection_controller_test.dart` to assert kinds instead of English substrings. Add ARB keys for each
      kind's title. Verify: controller tests pass.
- [ ] 5.3 `TopicAnalysisController`: replace the 3 English validation strings (`emptyFieldPath`, `noPreviousScope`)
      with an error kind mapped to ARB in `topic_analysis_view.dart`. Keep raw Rust errors as they are. Verify: the
      updated `topic_analysis_controller_test.dart` asserts kinds, and a German widget test shows the German message.
- [ ] 5.4 Add a required `String dialogTitle` to the FilePicker-calling methods of `SettingsService` (2),
      `MessageExportService` (4) and `TopicAnalysisExportService` (2). Pass `l10n.exportConfiguration`,
      `importConfiguration`, `exportMessages`, `exportMessagesCsv` and new `exportTopicAnalysis`/`importTopicAnalysis`
      from the callers. Also localize the `dialogTitle`s in `script_history_list.dart` ("Save Run Archive - {name}")
      and `script_schemas_view.dart`. Verify: service tests compile with the parameter. A test with a mocked
      `FilePicker` platform asserts the title it receives. Remove the corresponding allowlist entries; the guard is
      green.

## 6. Messages and payload viewers

- [ ] 6.1 `messages_table_view.dart`: header titles (Timestamp, Step, Topic, Partition, Offset, Key, Content via
      existing keys), filter dialog (title with `{column}`, hint, Clear, Apply), "Hide column" (`hideColumn`). Verify:
      a German widget test in `messages_table_view_customization_test.dart` opens the filter dialog and finds the
      German texts. Remove the allowlist entries.
- [ ] 6.2 `json_or_string_viewer.dart` (Raw/Tree via `raw`/`tree`, "Copy content", `contentCopied`) and
      `hex_viewer.dart` (empty notice, preparing/copied notices, "Copy Full Hex Dump"). Verify after 5.5 that the
      truncation banners are gone; localize them if they still exist. Verify: German widget tests in
      `json_or_string_viewer_test.dart` and `hex_viewer_test.dart`.
- [ ] 6.3 `smart_composite_badge.dart` (copied notice, "Copy whole object", "Close", "Entity Details"),
      `messages_timeline_view.dart`/`messages_diff_view.dart` (`noMessagesToDisplay`, "Error computing diff",
      "Global (No Step)"), `dlq_failure_diagnostics_card.dart` ("Stacktrace"). Verify after 5.27: `messages_view.dart`
      "No results found matching '{phrase}'" and the `message_search_bar.dart` show/hide tooltips. Verify: German
      widget tests for the badge, timeline and diff empty states. Allowlist entries removed.

## 7. Explorer, search, navigation, schema and settings

- [ ] 7.1 `cluster_overview_view.dart` ("Available Topics", "Optional metadata registry"), `quick_jump_dialog.dart`
      ("No cluster selected", "Topic: {topic}"), `cluster_basic_info_form.dart` (registry URL hint as an ARB text with
      the URL as placeholder). Verify: German tests in `cluster_overview_view_test.dart` and
      `quick_jump_dialog_test.dart`.
- [ ] 7.2 `topic_search_bar.dart` (Start/End Time, `partitionOptional`, Field (Opt.), `type`, `scope`; verify after
      5.6 for the Fast Trace label), `topic_selection_dialog.dart` (filters, search, title plurals, Cancel,
      "Select ({n})"), `timestamp_picker_field.dart` (9 texts, mostly existing keys). Verify: German tests in
      `topic_search_bar_test.dart` and `timestamp_picker_field_test.dart`.
- [ ] 7.3 `schema_diff_dialog.dart` ("Select versions to compare"). Verify after 5.23: `topic_schema_inspector_view.dart`
      "Error loading schema: …" becomes ARB text plus the raw error. Verify after 5.31: `settings_view.dart`
      "Default: 30" becomes an ARB text with a `{count}` placeholder. Verify: German tests in
      `schema_diff_dialog_test.dart` and `settings_view_test.dart`. Allowlist entries removed.

## 8. Consumer Lag (verify after 5.24; spec: Language-Neutral Widget Logic)

- [ ] 8.1 Replace every remaining `isGerman` ternary in `consumer_lag_view.dart`, `consumer_group_controls.dart`,
      `group_details_view.dart` and `topic_partition_table.dart` with ARB keys. Reuse existing keys such as
      `consumerGroups` and `autoRefresh`. Group states (Stable/Empty/Dead) are localized labels, and the filter value
      stays the raw state. Also localize `group_lag_badge.dart` "Error" and `topic_partition_table.dart` "Error: …" if
      5.24 left them. Verify: `grep -rn "languageCode ==" lib/src` is empty, and German widget tests in
      `consumer_lag_view_test.dart` and `group_details_view_test.dart` find the German headers and KPIs. Add an
      `fr` test that expects English. The guard has no `languageCode` finding.

## 9. Scripts workspace

- [ ] 9.1 `script_editor.dart` (17: variable dialog, table headers, steps, "Extracted/Used: …") and
      `script_step_editor.dart` (9 + delete tooltip). Verify: German tests in `script_editor_test.dart` and
      `script_step_editor_test.dart`.
- [ ] 9.2 `parameter_values_dialog.dart` (8), `script_selector.dart` (2), `script_run_view.dart` (3),
      `script_run_header.dart` ("Running..." + back tooltip). Verify: German tests in `script_run_view_test.dart` and
      `script_run_header_test.dart`.
- [ ] 9.3 `script_history_list.dart` (19, tooltips, delete confirmation, SnackBars with `{error}`),
      `script_run_sidebar.dart` (5, "Cluster/Started/Finished/Total Runtime" labels with placeholders),
      `script_run_details_view.dart` (3), `script_schemas_view.dart` (15 + 2 ternaries, plurals for "Found {n}
      time(s) across {m} topic(s)"). Verify after 5.29: `topic_progress_tile.dart` and `script_progress_widget.dart`
      progress texts become plurals. Verify: German tests in `script_run_details_view_test.dart`,
      `script_progress_widget_test.dart` and `topic_progress_tile_test.dart`. Allowlist entries removed.

## 10. Topic analysis views

- [ ] 10.1 Units and labels: "msgs"/"msgs/sec" (plural ARB texts with `decimalPattern`), "Partition {n}",
      "Offsets: {from} .. {to}" / "Offsets: -", "Peak: {hour}:00 UTC", "Partition {p} • Offset {o}", "No keyed messages
      found", "No content types recorded", "No structured fields detected", "No scalar values recorded for this field"
      in `daily_production_view.dart`, `partition_balance_view.dart`, `recent_production_chart.dart`,
      `hourly_production_chart.dart`, `duplicate_details_dialog.dart`, `key_and_field_distribution_view.dart`,
      `field_value_explorer.dart` and `topic_analysis_view.dart`. Verify: the existing analysis widget tests pass with
      updated finders, plus one German test in `partition_balance_view_test.dart`. The guard allowlist now contains
      only technical entries (no `TODO` reason left).

## 11. Labelled controls and hit areas (spec: Labelled Icon-only Controls, Minimum Hit Area)

- [ ] 11.1 Add localized tooltips to the 23 unlabelled `IconButton`s listed in design §Inventory F. Verify after 5.27:
      inspector `:492`/`:595` and search bar `:133`. Verify: a widget test per touched screen finds each control
      `byTooltip` in German.
- [ ] 11.2 Replace the icon-only `InkWell`s with compact `IconButton`s (design D6) that have tooltips: tree
      chevron (expand/collapse), composite badge, table header filter ("Filter {column}"), remove projected column,
      hide column, tab close. Verify: widget tests tap them by tooltip and check that keyboard focus reaches the tab
      close button.
- [ ] 11.3 Fix the 18 shrunk hit areas and the 20×20 duplicate-tab button: standalone buttons use the theme default,
      inline ones use the 24×24 minimum (design D6). Verify: a widget test asserts that the explorer refresh/clear
      buttons are at least 40×40 under `VisualDensity.compact`, and that the table header filter button is at least
      24×24 (`tester.getSize`).

## 12. Text size, status colours, colour-only states (spec: Minimum Text Size, Theme-based Status Colours, State Not Conveyed by Colour Alone)

- [ ] 12.1 Replace the 26 `fontSize` 9–10 sites with `textTheme.labelSmall`/`bodySmall`, and replace fixed
      `Colors.black87`/`Colors.grey` text in `message_metadata_card.dart` and `timeline_metadata_card.dart` (verify
      after 5.27) with scheme roles. Check the chart tests for label overlap and thin labels out if needed. Verify:
      `grep -rnE "fontSize:\s*([0-9]|10)(\.0)?\b" lib/src` is empty, and chart tests pass.
- [ ] 12.2 Map the status colours of the widgets listed in design D8 to `ColorScheme` roles. Verify after 5.3: no
      `Colors.green`/`Colors.red` remains in `cluster_config_dialog.dart`. Verify: the remaining
      `grep -rnE "Colors\.(green|red|orange|amber)" lib/src` hits are only in the non-goal files (diff widgets,
      charts' categorical palette, entity formatter, JSON value colours), and are listed in the PR description.
- [ ] 12.3 Add a warning icon with a localized "skewed" label to skewed partition rows in `partition_balance_view.dart`,
      and the `★` marker to unusual bars in `recent_production_chart.dart`. Verify: widget tests find the icon/label
      and the marker, and the semantics tree contains the label.

## 13. Error boxes (spec: Copyable and Dismissible Error Boxes)

- [ ] 13.1 Create `lib/src/ui/widgets/error_banner.dart` (design D9; use an existing shared clipboard helper from 5.25
      or 5.27 if one exists). Widget tests: Copy puts title and detail on a mocked clipboard and shows the
      confirmation. A failing clipboard channel shows the failure notice. The dismiss callback fires.
- [ ] 13.2 Use `ErrorBanner` for the explorer connection error (dismiss → `clearError()`, localized title per
      `ConnectionErrorKind`, raw detail), the `schema_diff_dialog.dart` error box, `script_run_details_view.dart`
      failure state and `topic_schema_inspector_view.dart` error (verify after 5.23). Add Copy to 5.23's error card
      and inline error row. Verify: `explorer_view_test.dart` shows the banner after a failed connect, hides it after
      close, shows it again on the next failure, and finds the German title.

## 14. Accessibility guideline tests (spec: Automated Accessibility Checks)

- [ ] 14.1 Write `test/src/a11y/accessibility_guidelines_test.dart` (design D10) for the 9 listed screens, light and
      dark theme. Each case runs `labeledTapTargetGuideline`, `MinimumTapTargetGuideline(size: Size(24, 24), link: …)`
      and `textContrastGuideline`. Verify: all cases pass. Temporarily remove one tooltip and check that the
      labelled-target case fails and names the element (do not commit this check).

## 15. ARB finalization

- [ ] 15.1 Remove the ARB keys that are still unused (design D2 command), from both files in the same commit. Then
      run `flutter gen-l10n`. Verify: the D2 command prints nothing, `arb_consistency_test.dart` is green, and
      `flutter analyze` has no undefined getters.
- [ ] 15.2 Review all German texts added in this change for consistent terms with existing keys (Topic,
      Consumer-Gruppe, Partition, Lag, Variable). Verify: `flutter gen-l10n` reports no untranslated messages for `de`.

## 16. Final verification

- [ ] 16.1 Run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test` and
      `scripts/check_read_only.sh`. Verify: all exit 0. The guard allowlist contains only entries with a technical
      reason. `grep -rn isGerman lib/src` is empty. No `cargo` steps (no Rust touched).
- [ ] 16.2 Manual check in German and English, light and dark theme: Explorer with a failed connection (close and
      copy the banner), message table filter dialog, Raw/Tree/Hex viewer, Consumer Lag, Script editor and run
      history, topic analysis. Verify: screenshots attached to the PR. No English text in the German run except
      allowlisted identifiers.
