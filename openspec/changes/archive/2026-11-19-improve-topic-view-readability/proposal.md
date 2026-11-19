# Proposal: Improve Topic View Readability

## Why

The topic search view (Explorer → topic tab → Messages) wastes vertical and horizontal space and is hard to read on
laptop-sized screens: every tab of an insecure profile repeats a red "Insecure TLS" badge, the payload text in the
timeline and diff cards is minified JSON in a generic monospace font with fixed colours, the filter area grows by up
to three rows and mixes two filter models without explaining them, the topic header facts wrap into several rows of
chips, and the diff view spends a whole row on the "Ignored fields" button. Users see fewer messages and need longer
to read each one. This change is not part of the roadmap catalogue in
`design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5; it is a UX follow-up to the delivered changes
`restore-tls-verification` (5.21), `structured-message-filter` (5.9), `structural-message-diff` (5.8) and
`cluster-overview-and-topic-facts` (5.34) and keeps their guardrails (L1, L5, E5, E13).

## What Changes

- **Insecure TLS marker moves to the connection level.** Topic tabs no longer show the marker. It is shown on the
  cluster entry in the Explorer sidebar, in the cluster switcher and (unchanged) in Settings, the cluster dialog and the
  topic configuration views. E13 ("visible insecure flag per profile") stays fulfilled because the flag remains visible
  wherever the profile itself is shown and chosen.
- **Readable card payloads.** Timeline and diff cards render the payload preview in the app's monospace font (the same
  one the table and inspector use), with spaces after `:` and `,`, theme-based colours for keys, strings, numbers and
  literals, a comfortable line height and full-contrast text. Diff rows (added, removed, changed) use colours from the
  colour scheme instead of fixed `green`/`red`/`black87` values (fix of the existing `accessibility-baseline`
  requirement, no delta for that part) and follow the text-size setting.
- **One-row filter bar.** The fetch filter field keeps its scope (key / value / both) and match type (contains / regex
  / exact) as a compact inline menu inside the field. Field path, partition, Fast Trace and the structured filter
  expression move into one "More filters" popover opened from a button that shows the number of active filters. The
  popover no longer pushes the result list down. The time-range and offset bounds of the scan modes render in a single
  compact row with one preset menu instead of two rows of preset chips. Labels distinguish "filter while fetching" from
  the in-memory "filter loaded messages" field. Saved searches and session state stay loadable unchanged.
- **Single-line topic facts strip.** The header facts render in one line. Partitions, RF, the message estimate and the
  schema stay visible; further facts collapse into a "+N" overflow chip with a popover. Health warnings, "not readable"
  and "unknown" states are never collapsed.
- **Ignored fields in the results toolbar.** In diff mode the "Ignored fields (n)" control sits in the results toolbar
  next to the view-mode switcher; the separate row above the timeline is removed. The topic selector for multi-topic
  results and the "ignore list unreadable" warning move into this control.

No new Kafka or Schema Registry calls. No bridge, Rust or persisted-format changes.

## Capabilities

### New Capabilities

- `message-card-payload-preview`: typography, formatting and colours of the payload preview and the diff rows inside
  timeline and diff message cards.

### Modified Capabilities

- `tls-verification`: the requirement "Insecure Marker on Explorer Tabs" is replaced by a connection-level marker
  (sidebar cluster entry, cluster switcher, Explorer header banner); tabs no longer show it. The "flagged wherever
  shown" scenario is narrowed to places where the profile itself is listed, selected or edited.
- `ergonomic-settings-and-cluster-onboarding`: the scenario "Tag shown together with the insecure marker" no longer
  requires the marker on tabs; tabs keep the environment chip.
- `topic-header-facts`: adds a single-line facts strip with overflow that never hides warnings or unknown states.
- `topic-consumption`: "Progressive Disclosure for Advanced Topic Search Filters" changes from an inline expandable
  panel to an inline scope/type menu plus a "More filters" popover; adds a compact single-row layout for scan bounds and
  distinct labels for fetch-time and in-memory filtering.
- `unified-results-toolbar`: adds view-specific actions in the toolbar; the diff ignore-list control lives there.

## Impact

- **Dart only**: `explorer_view.dart` (tab and sidebar cluster title), `cluster_dropdown.dart`,
  `topic_detail_view.dart` (header tags), `topic_search_bar.dart`, `timestamp_picker_field.dart` (compact preset menu),
  `messages_view.dart` (toolbar slot), `messages_diff_view.dart`, `timeline_message_card.dart`,
  `json_diff_widget.dart`, `text_preview_utils.dart`, new en/de ARB keys.
- **Tests**: widget tests for tab, sidebar, header strip, search bar, toolbar and cards; existing keys
  (`topic_*_tag`, `filter_expression_chip`, `filter_type_chip`, `quick_filter_pattern_error`) are kept so existing tests
  keep their anchors.
- **Read-only impact**: none — no new Kafka or Schema Registry calls; `scripts/check_read_only.sh` passes unchanged.
- **Dependencies**: none new (`google_fonts` already provides Roboto Mono via `AppFonts`).
- **Prerequisites**: none; all referenced changes are archived.

## Non-Goals

- No change to filter semantics, the filter expression grammar (E5, L7) or the scan-mode presets.
- No change to the table view, the inspector panel or the topic analysis / configuration modes.
- No removal of the Field / Type / Scope filter model; no conversion of saved searches.
- No new navigation destination (L6), no change to TLS behaviour itself.
