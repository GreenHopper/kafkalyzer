# Design: accessibility-and-l10n-sweep

## Context

See `proposal.md` (Why) for the motivation. Requirements are in `specs/complete-ui-localization-and-discoverability`
and `specs/accessibility-baseline`. All counts below were measured on the current working tree before any Phase 0/1
change was applied. They are a baseline: the sibling changes will remove some items before this change starts.

Facts checked in code:

- **ARB files.** `lib/l10n/app_en.arb` (template) and `app_de.arb` each have 669 top-level message entries, but only
  666 distinct keys. `matchesCount`, `noVariablesRequired` and `noDifferencesFound` are defined twice in both files,
  and `@matchesCount` twice in en. `gen-l10n` keeps the last definition, so:
  - `noDifferencesFound` reads "…between the selected versions" in `json_diff_widget.dart`, the script result diff,
    which is the wrong context.
  - `matchesCount` reads "{current} of {total}" in the inspector search, where "{current} / {total} matches" was
    intended. `script_run_sidebar.dart` uses the same key for "matched of examined".
  - `noVariablesRequired` has the same English text twice but two different German texts.
  - Both files have the same key set. No placeholder is undeclared or different between en and de. 4 keys use
    plural/select.
  - 110 keys are not referenced anywhere in `lib/`. About half are ready-made translations for the literals below
    (`raw`, `tree`, `apply`, `hideColumn`, `editVariable`, `noPastRunsFound`, …). The rest belong to removed
    features (`orders`, `simulateOrder`, `kiError`, `pmxcorStatus`, …).
- **Locale.** `app.dart` sets `supportedLocales` and no explicit `locale`, so the app follows the OS locale. Four
  consumer files compute `isGerman = Localizations.localeOf(context).languageCode == 'de'` themselves.
- **Theme.** `AppTheme` (FlexColorScheme indigo) uses `VisualDensity.adaptivePlatformDensity`. On desktop this is
  compact, so a default `IconButton` is 40×40. In widget tests the platform is Android, so the default is 48×48. No
  status-colour extension exists. `connection-diagnostics` (5.3, D8) already maps states to `primary`/`error`/
  `outline`.
- **Tests.** 73 test files pump widgets. 13 of them have no localization delegates, for example
  `json_or_string_viewer_test`, `hex_viewer_test`, `timestamp_picker_field_test`, `script_editor_test`,
  `topic_progress_tile_test` and `smart_composite_badge_test`. No test uses `meetsGuideline` yet. `analyzer` 13.3.0
  is resolved transitively in `pubspec.lock`.

### Inventory (reproducible)

Run from the repo root.

**A. Widget-position literals.** This finds a literal with at least two letters (interpolations removed) that is the
first argument of `Text`/`SelectableText`/`TextSpan`, or the value of a UI named argument. It also matches across
line breaks:

```bash
find lib/src -name '*.dart' -not -path 'lib/src/rust/*' -not -name '*.g.dart' -not -name '*.freezed.dart' -print0 |
xargs -0 perl -0777 -ne '
  while (/(?:\b(?:Text|SelectableText|TextSpan)\(\s*|\b(?:tooltip|message|label|labelText|hintText|helperText|errorText|title|dialogTitle|semanticLabel|semanticsLabel|subtitle|content|text|prefixText|suffixText|counterText|confirmText|cancelText|helpText):\s*(?:const\s+)?(?:Text\(\s*)?)r?([\x27"])((?:\\.|(?!\1).)*?)\1/sg) {
    my ($lit,$pos)=($2,$-[0]); (my $s=$lit)=~s/\$\{[^}]*\}|\$\w+//g; next unless $s=~/[A-Za-z]{2,}/;
    my $line=1+(substr($_,0,$pos)=~tr/\n//); print "$ARGV:$line: $lit\n" }' | sort
```

Result: **188 literals in 49 files**, classified as follows:

| Class | Count | Content |
|---|---:|---|
| Owned here | 154 | see table below |
| Owned here, verify after sibling | 6 | `topic_progress_tile.dart` ×2, `script_progress_widget.dart` (5.29); `group_lag_badge.dart` "Error", `topic_partition_table.dart` "Error: …" (5.24); `settings_view.dart` "Default: 30" (5.31) |
| Sibling-owned | 7 | inspector `'Key: '`, `TombstoneWidget` (5.27); inspector `'Key'`, `'Headers (n)'` (5.30); "Fast Trace (Hash Key)" (5.6); both 500k truncation banners (5.5 removes the cap) |
| Technical, allowlist | 14 | security protocols ×4, SASL mechanisms ×6, `YYYY-MM-DDTHH:mm:ss` ×2, `<topic>-key / <topic>-value` subjects, `Kafkalyzer v<version>` |
| Scanner false positive | 7 | nested quotes inside `${…}` (`padLeft(2, '0')`, `l10n?.x ?? '…'` inside interpolation) |

Owned literals per file: `script_history_list.dart` 19, `script_editor.dart` 17, `script_schemas_view.dart` 15,
`messages_table_view.dart` 13, `script_step_editor.dart` 9, `timestamp_picker_field.dart` 9,
`parameter_values_dialog.dart` 8, `topic_search_bar.dart` 6, `script_run_sidebar.dart` 5,
`topic_selection_dialog.dart` 5, `message_export_service.dart` 4, `hex_viewer.dart` 4, `json_or_string_viewer.dart` 4,
`script_run_details_view.dart` 3, `script_run_view.dart` 3, `smart_composite_badge.dart` 3, 2 each in
`script_selector.dart`, `field_value_explorer.dart`, `key_and_field_distribution_view.dart`,
`partition_balance_view.dart`, `settings_service.dart`, `topic_analysis_export_service.dart`,
`messages_diff_view.dart`, and 1 each in `cluster_basic_info_form.dart` ("e.g. …" hint), `explorer_view.dart`
("Error: …"), `cluster_overview_view.dart`, `quick_jump_dialog.dart`, `schema_diff_dialog.dart`,
`daily_production_view.dart`, `duplicate_details_dialog.dart`, `hourly_production_chart.dart` ("Peak: … UTC"),
`recent_production_chart.dart`, `topic_analysis_view.dart` ("msgs/sec"), `messages_view.dart` (no-results text),
`messages_timeline_view.dart`, `dlq_failure_diagnostics_card.dart` ("Stacktrace"). 66 of the 139 owned literals
without interpolation match an existing ARB value exactly.

**B. Literals in ternaries (missed by A, found by the analyzer guard):**
`grep -rnE "^\s*[?:]\s*['\"][A-Z][a-z]+[ a-z]" lib/src --include=*.dart --exclude-dir=rust | grep -v consumer/presentation`
gives 13 lines: `cluster_overview_view.dart` "Optional metadata registry", `smart_composite_badge.dart` "Entity Details",
`messages_timeline_view.dart` "Global (No Step)", `topic_selection_dialog.dart` "Select Topic(s) (n/m)" ×2,
`partition_balance_view.dart` "Offsets: …" ×2, `script_run_header.dart` "Running...", `script_schemas_view.dart` ×2,
`message_search_bar.dart` ×2 (verify after 5.27) and `topic_schema_inspector_view.dart` "Error loading schema"
(verify after 5.23).

**C. Language ternaries:** `grep -rn isGerman lib/src` gives 51 lines in `consumer_lag_view.dart` (25),
`consumer_group_controls.dart` (16), `group_details_view.dart` (5) and `topic_partition_table.dart` (5). 5.24 rewrites
some KPI texts and the badge. Whatever is left after 5.24 is owned here.

**D. Non-widget messages:** `grep -rnE "(_error|_errorMessage)\s*=\s*['\"][A-Z]" lib/src` plus the multi-line
assignments in `ActiveConnectionController.connect` give 6 connection messages
(`active_connection_controller.dart:380-400`), 3 in `topic_analysis_controller.dart` (251, 313, 318) and 1 in
`quick_jump_dialog.dart:134`. There are 8 FilePicker `dialogTitle:` literals in 3 services, plus 2 in
`script_history_list.dart` and `script_schemas_view.dart` (those two are counted in A).

**E. Unreachable fallbacks (not in scope):**
`grep -rnE "\?\?\s*['\"][A-Za-z]" lib/src --include=*.dart --exclude-dir=rust | grep -cE "(l10n|loc|localizations|t)\?\.[a-zA-Z]+(\([^)]*\))?\s*\?\?"`
gives 244.

**F. Accessibility:**

| Item | Command / method | Count |
|---|---|---:|
| `IconButton` without `tooltip:` and not wrapped in `Tooltip` | paren-matched scan of `IconButton(` / `.filled(` etc., excluding `styleFrom` | 23 of 94 |
| Icon-only `InkWell` without label | paren-matched scan, `Icon(` child, no `Text(`/`Tooltip`/`Semantics` | 4 (+ tab close, which has a tooltip but a 16 px target) |
| Shrunk hit areas | `grep -rnE "constraints: const BoxConstraints\(\)\|tapTargetSize: MaterialTapTargetSize.shrinkWrap\|BoxConstraints\(min(Width\|Height): (1[0-9]\|2[0-9]\|3[0-9])\b\|minimumSize: const Size\((1\|2\|3)[0-9]," lib/src` | 18 in 9 files (+ duplicate-tab 20×20) |
| Text ≤ 10 px | `grep -rnE "fontSize:\s*([0-9]\|10)(\.0)?\b" lib/src` | 26 in 12 files |
| Fixed `Colors.*`/`Color(0x…)` | `grep -rnE "Colors\.(green\|red\|orange\|amber\|…)\b\|Color\(0x" lib/src` | 159 in 37 files (status subset in D8) |

The 23 unlabelled `IconButton`s are: `messages_view.dart:721` (arrow_upward); `messages_table_view.dart:538`
(filter clear); `message_inspector_panel.dart:492`, `:595` (verify after 5.27); `message_search_bar.dart:133` (verify
after 5.27); `topic_selection_tree.dart:124`; `quick_jump_dialog.dart:200`; `explorer_view.dart:459` (refresh),
`:523` (clear); `topic_search_bar.dart:423`; `topic_schema_inspector_view.dart:432`; `schema_diff_dialog.dart:362`;
`consumer_lag_view.dart:769` (refresh); `topic_list_item.dart:274`; `script_manager_view.dart:290`;
`script_step_editor.dart:548`; `script_editor.dart:529`, `:533`, `:584`, `:646`, `:650`; `script_run_header.dart:38`;
`settings_view.dart:167` (folder picker). The icon-only `InkWell`s are: tree chevron
(`smart_virtual_json_tree.dart:270`), composite badge (`smart_composite_badge.dart:87`), the message table header
filter and remove-column icons (`messages_table_view.dart:717`, `:743`; hide-column `:757` has a hard-coded tooltip),
and the tab close icon (`explorer_view.dart:965`, 16 px).

Line numbers are from the baseline. The implementer re-runs the commands after rebasing onto the siblings.

## Goals / Non-Goals

**Goals:** empty the inventory classes A–D except allowlisted technical identifiers. Make both guard tests and the
guideline test part of `flutter test`. Fix the accessibility items in F for the listed widgets.

**Non-Goals (design level):** no new localization tooling (`gen-l10n` stays). No custom lint plugin. No change to
how the locale is chosen. No new widget library. No status-colour `ThemeExtension`.

## Decisions

### D1 Ownership: last in Phase 1, "verify after" instead of duplicate work

Strings and widgets that a sibling rewrites are not touched here before that sibling lands. Each task names its
sibling. When this change starts, the implementer re-runs the inventory commands. Every remaining hit is either fixed
or allowlisted with a reason. The guard test then enforces the result for all of `lib/src`, including widgets added by
the siblings. *Alternative:* sweep now and let siblings rebase. Rejected, because it would double the work on the same
widgets and cause merge conflicts in eight changes.

### D2 Keys: reuse first, one meaning per key, feature-prefixed names

- Before adding a key, search the template for the exact English value and use the existing key if it has the same
  meaning (about 66 cases, for example `apply`, `cancel`, `hideColumn`, `tree`, `raw`, `contentCopied`,
  `exportMessagesCsv`, `editVariable`, `noPastRunsFound`).
- New keys use the feature prefix already in use (`script…`, `schema…`, `lag…`, `table…`, `hex…`). Counted texts use
  ICU plurals (`{count, plural, =1{…} other{…}}`) with `int` placeholders. Numbers use `format: decimalPattern`
  (example: `matchesCount`).
- Duplicates are split by meaning:
  - `matchesCount` = "{current} / {total} matches" stays for the inspector search, next to 5.5's
    `matchesCountCapped`.
  - New `scriptRunMatchedOfExamined` = "{matched} of {examined}" for the run sidebar.
  - `noDifferencesFound` = "No differences found." stays for the script diff.
  - New `schemaNoDifferencesFound` for the schema version diff.
  - `noVariablesRequired` keeps one entry, German "Keine Variablen erforderlich.", which matches the existing
    `variables` = "Variablen".
- After the sweep, keys that are still unused are deleted from both files. They are found with
  `for k in $(grep -oP '^  "\K[a-zA-Z0-9_]+(?=":)' lib/l10n/app_en.arb | sort -u); do grep -rqE "\.$k\b" lib --include=*.dart --exclude-dir=l10n || echo $k; done`.
  Keys referenced only by tests are kept.

### D3 Messages from non-widget code

- `ActiveConnectionController` replaces `String? _error` with `ConnectionError? _error`. `ConnectionError` is a small
  immutable class with `ConnectionErrorKind kind` (`validationFailed`, `brokerTransport`, `connectionRefused`,
  `other`) and `String detail` (the first line of the raw error, or the `AnyhowException` message). The classification
  is the same string matching as today and moves into a pure function with a unit test. `clearError()` stays.
  `explorer_view.dart` maps the kind to an ARB text and shows `detail` unchanged. If 5.26 has already added a
  localized bootstrap-validation error in `connect`, it becomes the kind `invalidBootstrapServers` with the issue text
  as detail, and its ARB key is kept.
- `TopicAnalysisController` gets the same pattern for its 3 validation errors (`emptyFieldPath`, `noPreviousScope`).
  Errors that come from Rust are still shown raw.
- Services do not localize. `SettingsService.export/importConfiguration`, `MessageExportService` (4 methods) and
  `TopicAnalysisExportService` (2) get a required `String dialogTitle` parameter. Callers pass the existing ARB keys
  (`exportConfiguration`, `importConfiguration`, `exportMessages`, `exportMessagesCsv`) or new
  `exportTopicAnalysis`/`importTopicAnalysis`. If 5.28 or 5.7 changed these signatures, the parameter is added to the
  new ones.
- *Alternatives:* (a) `lookupAppLocalizations(PlatformDispatcher.instance.locale)` inside services and controllers.
  Rejected: it duplicates locale resolution, and it would break as soon as 5.31 adds an in-app language choice.
  (b) Passing `AppLocalizations` into controllers. Rejected: controllers outlive a locale change, so the stored
  sentence would stay in the old language.

### D4 Hard-coded-string guard: analyzer parse-only test with allowlist

`test/l10n/hardcoded_strings_guard_test.dart` walks `lib/src/**.dart`, skipping `lib/src/rust/`, `*.g.dart` and
`*.freezed.dart`. It parses each file with `parseString(content:, throwIfDiagnostics: false)` and visits the AST with
a `RecursiveAstVisitor`. No type resolution, so it is fast and independent of the build. Rules:

1. A *text literal* is a `SimpleStringLiteral`, `AdjacentStrings` or `StringInterpolation` whose literal parts,
   without interpolations, contain `[A-Za-z]{2,}`.
2. A *UI position* is:
   - the first positional argument of an invocation named `Text`, `SelectableText` or `TextSpan`;
   - the value of a named argument in {`tooltip`, `message`, `label`, `labelText`, `hintText`, `helperText`,
     `errorText`, `title`, `subtitle`, `dialogTitle`, `semanticLabel`, `semanticsLabel`, `content`, `text`,
     `confirmText`, `cancelText`, `helpText`, `prefixText`, `suffixText`, `counterText`}, except inside
     `ClipboardData(...)`;
   - an assignment to a field named `_error`, `_errorMessage` or `errorMessage` in `presentation/` code.
   The visitor descends through `ConditionalExpression` branches, parentheses and `??` right operands. Exception:
   the right operand of `x ?? '…'` is skipped when `x` is a null-aware access on an identifier named `l10n`, `loc`,
   `localizations` or `AppLocalizations.of(...)` (class E, non-goal).
3. Any `BinaryExpression` with `==`/`!=` where one side is a property access named `languageCode` is a finding.
4. Allowlist file `test/l10n/hardcoded_strings_allowlist.txt`, one entry per line:
   `<path relative to repo>␉<literal source text>␉<reason>`. Matching ignores line numbers, so unrelated edits do not
   break it. An entry that matches nothing is reported as stale and fails the test. Expected entries: the 14
   technical literals from inventory A, plus any brand-name string.
5. The failure message lists `path:line: literal` for every finding, so the developer can fix all of them in one run.

*Why analyzer over regex:* the regex in inventory A misses literals in ternaries (class B), misreads nested quotes
inside interpolations (7 false positives) and cannot tell `l10n?.x ?? '…'` from a real fallback. A parse-only visitor
handles all three in about 120 lines. `analyzer` is already resolved, so it only becomes an explicit
`dev_dependency` (constraint `^13.3.0`, matching the lock). Nothing new is downloaded and it builds anywhere Dart runs.
*Fallback (spike 1.1):* if making it explicit changes other resolved versions or `parseString` fails on a file, the
guard uses the inventory-A pattern, ported to Dart, with the same allowlist format. The ternary and `languageCode`
rules then become separate regexes. *Rejected:* `custom_lint`/analyzer plugin (new dependencies, IDE plugin
lifecycle, slower CI).

Known limits (documented in the test header): strings built in helper methods and passed positionally to custom
widgets (for example `_buildHeaderCell(0, 'Group ID')`) are not detected. Strings thrown as exceptions and shown later
are not detected either. This is why classes C and D get explicit tasks.

### D5 ARB consistency test

`test/l10n/arb_consistency_test.dart` reads both ARB files as text.

- **Duplicates:** count the top-level keys with `^  "(@?[^"@][^"]*)"\s*:`, which is valid because both files use
  2-space top-level indentation. The test first asserts that this count equals the number of `jsonDecode` entries
  plus the duplicates. A count above 1 is a failure.
- **Parity:** the message key sets (no `@` prefix) of en and de must be equal.
- **Placeholders:** top-level ICU argument names (identifiers right after `{` at brace depth 0, so plural/select
  branches are skipped) must be equal between en and de. Every name in en must be in `@key.placeholders`.

No new dependency.

### D6 Hit areas: 40×40 standalone, 24×24 inline

- Material's 48×48 dp is a touch guideline. Applied to the dense desktop table headers and tree rows, it would make
  the rows taller and show fewer messages.
- Flutter on desktop already gives `IconButton` 40×40 (compact density), and the app uses that density.
- WCAG 2.2 SC 2.5.8 (AA) requires at least 24×24 CSS px.
- Rule: standalone icon buttons drop the `constraints: BoxConstraints()`/`shrinkWrap` overrides and keep the theme
  default.
- Inline controls use `IconButton` with `iconSize` 14–16, `padding: EdgeInsets.all(4)`,
  `constraints: BoxConstraints(minWidth: 24, minHeight: 24)` and `visualDensity: VisualDensity.compact`.
- Icon-only `InkWell`s become such `IconButton`s, which also gives them focus, hover and a semantic button role.

The check uses `MinimumTapTargetGuideline(size: Size(24, 24), link: …)`. The 40×40 rule is checked in a widget test
for the explorer refresh and clear buttons, which currently have zero constraints.

### D7 Text size floor 11 px

The 26 sites with 9–10 px use `textTheme.labelSmall` (Material 3: 11 sp) or `bodySmall` and keep only the needed
`copyWith`. Fixed `Colors.black87`/`Colors.grey` text in `message_metadata_card.dart` and `timeline_metadata_card.dart`
uses `colorScheme.onSurface`/`onSurfaceVariant`. Chart labels at 9 px become 11. If the existing chart tests show
overlap, every n-th label is shown (spec scenario "Chart axis labels").

### D8 Status colours from `ColorScheme` roles

The mapping matches 5.3's D8:

| Status | Foreground | Badge / container |
|---|---|---|
| success / ok / stable | `primary` | `primaryContainer` / `onPrimaryContainer` |
| error / failed / dead / DLQ | `error` | `errorContainer` / `onErrorContainer` |
| warning / skewed / retry / unusual | `tertiary` | `tertiaryContainer` / `onTertiaryContainer` |
| running / info | `secondary` | `secondaryContainer` / `onSecondaryContainer` |
| neutral / unknown / empty | `outline` | `surfaceContainerHighest` / `onSurfaceVariant` |

In-scope widgets (status semantics only):
- `consumer_lag_view.dart` (`_getStateColor`, KPI icons), `group_details_view.dart`, `group_delta_badge.dart`,
  `group_estimate_badge.dart`, `topic_partition_table.dart` (verify after 5.24);
- `topic_list_item.dart` and `explorer_view.dart` DLQ/retry badges, `topic_tag.dart`;
- `script_progress_widget.dart` and `topic_progress_tile.dart` (verify after 5.29), `script_history_list.dart`,
  `script_timeline_widget.dart`, `script_run_view.dart` (stop/error);
- delete icons in `script_editor.dart`/`script_step_editor.dart`;
- `partition_balance_view.dart` skew, `recent_production_chart.dart` unusual bar, `duplicate_analysis_view.dart`,
  `topic_analysis_summary_cards.dart` compaction chip, `topic_report_comparison_view.dart`;
- `messages_diff_view.dart` error text, `schema_diff_dialog.dart` compatibility result and error box,
  `update_dialog.dart` success, `topic_detail_view.dart:561` snackbar;
- `message_metadata_card.dart`, `timeline_metadata_card.dart` (verify after 5.27), `tombstone_widget.dart` (5.27
  localizes it; colours here if 5.27 did not).

`cluster_config_dialog.dart` green/red is removed by 5.3; verify only.

Colour-only states found: the skewed partition bar and the unusual-hour bar. They get a warning icon with a localized
label, and a `★` marker that matches the existing tooltip text. All other status widgets already show an icon or text.
This is checked again per widget during the task.

*Alternative:* a `StatusColors` `ThemeExtension` with green/amber. Rejected: it creates a second convention next to
5.3, and the contrast of four extra colour pairs would need tuning for two themes. Trade-off: "success" is drawn in the
indigo primary instead of green. Because the icon and the label always carry the meaning, this is acceptable.

### D9 Shared `ErrorBanner`

`lib/src/ui/widgets/error_banner.dart` is a presentational widget with error icon, localized title, `SelectableText`
detail, a "Copy" `TextButton`, an optional close `IconButton` (`onDismiss`) and an optional "Retry" (`onRetry`).
Colours come from `errorContainer`/`onErrorContainer`.

- Copy calls `Clipboard.setData` in `try/catch` and shows the confirmation or failure SnackBar. If 5.25/5.27 already
  added a shared clipboard helper with this behaviour, the banner uses it instead.
- Users:
  - `explorer_view.dart` connection error (dismiss → `clearError()`; a new error sets `_error` again, so the banner
    comes back);
  - `schema_diff_dialog.dart:730` error box;
  - `topic_schema_inspector_view.dart` error (verify after 5.23);
  - `script_run_details_view.dart` "Failed to load details" (Retry/Back kept, Copy added).
- 5.23's error card in `ActionableTopicEmptyState` and its inline error row get the Copy action. If their widget is a
  plain card, it is replaced by `ErrorBanner` (content-replacing state: no dismiss).

### D10 Accessibility guideline tests

`test/src/a11y/accessibility_guidelines_test.dart` pumps each screen in `MaterialApp(theme: AppTheme.light | dark,
localizationsDelegates: AppLocalizations.localizationsDelegates, locale: en)`. It reuses the mock setup of the
screen's existing test (copy the setup, no shared harness refactor). With `tester.ensureSemantics()` it runs
`labeledTapTargetGuideline`, `MinimumTapTargetGuideline(size: Size(24, 24))` and `textContrastGuideline`.

Screens:
1. Explorer with an open topic tab;
2. `MessagesTableView` with a projected column;
3. `MessageInspectorPanel`;
4. `ConsumerLagView` with loaded groups;
5. `ClusterConfigDialog`;
6. `SettingsView`;
7. `ScriptEditor`;
8. `TopicSearchBar`;
9. the command palette (after 5.4).

`textContrastGuideline` only evaluates text on opaque backgrounds and may report false positives over images or
gradients. A known false positive is excluded with a comment, never by lowering the threshold.

### Layering

Everything is Dart UI or test code. `ConnectionError` classification is presentation-adjacent string matching on
errors that already reached Dart. It has one caller, so it stays in Dart (no second caller, no move to
`kafkalyzer-core`). No bridge or Rust change.

## Risks / Trade-offs

- [Sibling changes land later than planned or add new literals] → The guard test runs over the whole tree and fails on
  any new literal. Rebase this change last and re-run the inventory.
- [Many widget tests look for English literals or pump without delegates] → A dedicated task updates the 13 tests
  without delegates and switches literal finders to the en ARB values. `flutter test` must be green before the guard
  is enabled.
- [Analyzer API drift on a future major upgrade] → Only `parseString` and stable AST node classes are used. The regex
  fallback is documented.
- [Guard false positives (for example `title:` on a non-UI model)] → Allowlist with a reason, reviewed in PR. If one
  parameter name produces many false positives, it is removed from the rule list rather than allowlisted file by file.
- [Removing unused keys that a test or sibling still needs] → Removal is the last step and checked by `flutter
  analyze` and `flutter test`. Generated `app_localizations*.dart` are regenerated by `flutter gen-l10n` (run by the
  build).
- [Visible changes] → `matchesCount` in the inspector search changes from "1 of 5" to "1 / 5 matches" (the intended
  text). Success states turn from green to the theme primary. Some icons get larger hit areas, so header rows may grow
  by a few pixels. These are intended. Screenshots in PR.
- [Contrast check flakiness] → Pump with fixed sizes, wait with `pumpAndSettle`, and test both themes separately so a
  failure names the theme.

## Migration Plan

No stored data changes. Rollback is a revert of the change. The only additive dependency change is `analyzer` as a
`dev_dependency`.

## Open Questions

- Whether 5.31 adds an explicit in-app language selection. The design already avoids reading the locale outside
  widgets, so either outcome needs no change here.
