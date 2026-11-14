# Proposal: accessibility-and-l10n-sweep

Roadmap: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.32 (Phase 1b, effort M). Guardrail L5, finding
group C ("no language/theme choice"), §6.4 ("en/de ARB complete" in every phase).

## Why

The GUI still contains English text that German users see, and the code has no check that stops new cases. A read of
`lib/src` found 188 English string literals in widget text positions in 49 files. Four consumer-lag files decide the
language with `languageCode == 'de'` ternaries (51 lines). Three controllers and three services build user-facing
messages or file-dialog titles in English. The ARB files define three keys twice with different texts, so
`noDifferencesFound` and `matchesCount` show the wrong sentence on one of their two screens. For accessibility,
23 of 94 `IconButton`s have no tooltip, so screen readers get no label. 18 controls shrink their hit area below the
desktop default. 26 texts are 9–10 px. 159 places use hard-coded `Colors.*`, some of them as the only sign of a state
(skewed partition, unusual hour), and `Colors.black87` text becomes unreadable in the dark theme. The connection error
box cannot be closed or copied, although `ActiveConnectionController.clearError()` exists.

This change runs last in Phase 1. The sibling changes rework many of these screens and localize the text they touch.
This change cleans up what is left and adds guard tests so the result stays clean.

## What Changes

- **Remaining hard-coded texts move to the ARB files (en + de).** Concrete widgets, listed in `design.md` §Inventory:
  table header titles and filter dialog, "Hide column", Raw/Tree switch, "Copy content", hex viewer, timestamp picker,
  topic search bar fields, topic selection dialog, cluster overview, quick-jump dialog, Settings "Default: 30", the
  script editor, step editor, parameter values dialog, run history, run sidebar, run details, schemas view, analysis
  chart units ("msgs", "Partition n", "Offsets"), the composite badge and the explorer connection error. About 66 of
  these literals already have a matching ARB key that is not used. The change uses those keys and does not add
  duplicates.
- **No language branching in widgets.** All `isGerman` ternaries in `consumer_lag_view.dart`, `group_details_view.dart`,
  `topic_partition_table.dart` and `consumer_group_controls.dart` are replaced by `AppLocalizations` keys.
- **Messages from non-widget code are localized by the UI.** `ActiveConnectionController.connect` reports a
  `ConnectionError` with a kind and the raw detail instead of an English sentence. The topic analysis controller does
  the same for its validation errors. File-picker dialog titles are passed in by the calling widget. Services do not
  hold English text.
- **ARB defects fixed.** The duplicate keys `matchesCount`, `noVariablesRequired` and `noDifferencesFound` are split
  into one key per meaning. ARB keys that are still unused after the sweep are removed.
- **Guard tests.** (1) `test/l10n/arb_consistency_test.dart`: en and de have the same keys, no key is defined twice,
  placeholders match and the template declares them. (2) `test/l10n/hardcoded_strings_guard_test.dart`: parses
  `lib/src` with `package:analyzer` (parse only, no type resolution). It fails on a string literal with words in a UI
  text position, or on a `languageCode` comparison. The only exceptions are entries in a reviewed allowlist file.
- **Accessibility baseline.** Every icon-only control has a tooltip, which also serves as its semantic label. Icon-only
  `InkWell`s become `IconButton`s. Standalone icon buttons keep the platform default hit size (40×40 on desktop).
  Inline controls in dense rows (table headers, tree rows, tabs, chips) have at least a 24×24 hit area. No text is
  smaller than 11 px. Status colours come from `ColorScheme` roles. A state is never shown by colour alone. Error boxes
  offer "Copy", and error banners that sit above other content can also be closed.
- **Accessibility tests.** Widget tests run Flutter's `labeledTapTargetGuideline`, a 24×24 `MinimumTapTargetGuideline`
  and `textContrastGuideline`, in the light and the dark theme, over a fixed list of screens.

## Capabilities

### New Capabilities
- `accessibility-baseline`: labelled icon-only controls, minimum hit areas, minimum text size, status colours from the
  colour scheme with sufficient contrast in both themes, no colour-only state, and copyable/dismissible error boxes.

### Modified Capabilities
- `complete-ui-localization-and-discoverability`: the localization requirement is extended from the named views to all
  user-facing text of the graphical application. New requirements cover: no language branching in widget code,
  localization of messages that come from controllers and services, ARB catalogue consistency, and the
  hard-coded-string guard.

Fixes without a spec delta: some of the hard-coded texts are in views that existing specs already require to be
localized. These are `MessagesView` and `ClusterConfigDialog` with its forms
(`complete-ui-localization-and-discoverability`), the topic analysis import/export dialog titles
(`topic-analysis-export-import`, "Localize new export/import user-facing text") and the analysis validation messages
(`topic-analysis-value-filter`). The change fixes these places to match their specs and adds no spec delta for them.

## Impact

- **Code (Dart only):** `lib/src/ui/**` (viewers, timestamp picker, smart tree badge, messages table/timeline/diff
  empty states, progress tiles, metadata card), `lib/src/features/{explorer,navigation,search,schema,consumer,topic,
  scripting,settings}/**`, `lib/src/services/{settings_service,message_export_service,
  topic_analysis_export_service}.dart` (dialog title parameter), `active_connection_controller.dart`,
  `topic_analysis_controller.dart`, a new `lib/src/ui/widgets/error_banner.dart`, `lib/l10n/app_en.arb`,
  `lib/l10n/app_de.arb`.
- **Tests:** two new guard tests plus an allowlist under `test/l10n/`, a new accessibility guideline test, and updates
  to widget tests that look for English literals or pump widgets without localization delegates (13 test files have
  no delegates today).
- **Dependencies:** `analyzer` moves from transitive to an explicit `dev_dependency`, pinned to the version already in
  `pubspec.lock`. Nothing new is downloaded. A spike checks this first. If it fails, the guard uses the regex scanner
  documented in `design.md`.
- **No Rust, no bridge, no new runtime dependency.**
- **Read-only impact:** no new Kafka or Schema Registry calls. `scripts/check_read_only.sh` must pass unchanged.
- **Prerequisites (implement first):** all Phase 0 changes and all other Phase 1 changes. In particular,
  `fix-consumer-lag-accuracy` (consumer KPIs, lag badge, partition table), `fix-result-view-defects` (error states,
  column filter), `message-selection-copy-and-display` (inspector key, tombstone, search bar, timeline card),
  `nested-payload-decoding` (inspector Key/Headers), `chunked-raw-and-hex-viewer` (removes truncation banners),
  `fast-trace-partition-preview` (Fast Trace label), `live-tail-controls` (progress tiles, Settings field),
  `connection-diagnostics` (removes the green/red test-connection row), `cluster-profile-ergonomics` (bootstrap error
  in `connect`), `app-diagnostics-and-error-reporting` (About/Settings), `appearance-window-and-update-settings`
  (settings layout, text size), `command-palette` (palette UI, reviewed by the guideline test). Strings and widgets
  these changes rework are excluded here, or marked "verify after <change>" in `tasks.md`.

## Non-Goals

- New languages beyond en and de, and a language selector (5.31 owns appearance settings).
- Removing the about 250 unreachable `l10n?.key ?? 'English'` fallbacks. They never render when localization
  delegates are present. Some tests may depend on them, and the guard ignores this exact pattern. This is a possible
  follow-up.
- Diff colouring (added/removed) in `json_diff_widget.dart`, `schema_diff_dialog.dart` field lines and
  `messages_diff_view.dart`. The state is already shown by `+`/`-` prefixes and icons, and `structural-message-diff`
  (5.8) reworks these views.
- Categorical and decorative colours (chart palettes, JSON value-type colours, per-topic hash colours, entity
  formatter accents).
- A full WCAG audit, screen-reader walkthroughs on all three platforms, keyboard focus order and shortcut work (5.25,
  5.27, 5.4).
- Localizing text that comes from Kafka, librdkafka or the Schema Registry. Raw errors are shown as reported.
- Any write access to Kafka or the Schema Registry (L1).
