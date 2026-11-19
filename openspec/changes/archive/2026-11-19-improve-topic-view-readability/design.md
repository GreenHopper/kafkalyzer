# Design: Improve Topic View Readability

## Context

See `proposal.md` for motivation and scope. All changes in this proposal are confined to the Dart/Flutter presentation
and UI utility layer (`lib/src/`). No Rust crates (`kafkalyzer-core`, `kafkalyzer-kafka`, `rust_lib_kafkalyzer`), no
`flutter_rust_bridge` APIs or DTOs, and no persisted JSON formats (cluster profiles, saved search presets, tab session
state, diff ignore lists) are modified. All Material components MUST continue to import
`package:material_ui/material_ui.dart` (L5).

## Goals / Non-Goals

**Goals:**
- Reclaim vertical and horizontal space in the Explorer topic tab view on laptop viewports (1280×800 to 1440×900)
  without losing any diagnostic capability or accessibility guarantee.
- Ensure card payload previews and diff entries use consistent code typography (`AppFonts.robotoMono`), spaced JSON
  formatting, and WCAG AA compliant theme colors in both light and dark themes.
- Replace inline expansion of advanced topic filters with an overlay popover and an inline scope/type menu inside the
  fetch filter field.
- Condense topic header facts into a single-line priority strip with a `+N` overflow popover that never hides warning or
  error states.
- Co-locate the diff ignore-list trigger inside the `MessagesView` results toolbar.

**Non-Goals:**
- No changes to Rust message filtering, `kafkalyzer_core::json_path`, or structural diff computation.
- No changes to `SearchStreamConfiguration` used inside the Scripting step editor (the compact search bar changes apply
  to `TopicSearchBar`).

## Decisions

### 1. Layer Assignment

Every change in this proposal is pure presentation logic and view state with a single caller (the Flutter desktop GUI),
so all logic lives in Dart under `lib/src/`:
- **Connection-level Insecure TLS badge**: `explorer_view.dart` (`_buildClusterListTitle`, tab builder),
  `cluster_dropdown.dart`, `environment_tag.dart` (`EnvironmentBanner`), `insecure_tls_badge.dart`.
- **Card payload preview & diff typography**: `text_preview_utils.dart`, `timeline_message_card.dart`,
  `json_diff_widget.dart`, `messages_diff_view.dart`.
- **Single-line topic facts strip**: `topic_detail_view.dart` (`_buildTopicTags` and a dedicated priority/overflow strip
  widget).
- **One-row search bar & popover**: `topic_search_bar.dart`, `timestamp_picker_field.dart`.
- **Diff ignore-list toolbar integration**: `messages_view.dart`, `messages_diff_view.dart`.

### 2. Connection-Level Insecure TLS Marker

- **Remove from topic tabs**: In `ExplorerView._buildTopicTab`, remove the `InsecureTlsBadge(compact: true)` below the
  topic title. Keep the profile name and `EnvironmentTagChip(compact: true)`.
- **Add to connection-level surfaces**:
  - `ExplorerView._buildClusterListTitle`: When `cluster.tlsVerification == TlsVerification.disabled`, render
    `InsecureTlsBadge(compact: true)` after the cluster name (and environment chip). Wrap the row in a `LayoutBuilder`
    so that when the sidebar is narrow (`maxWidth < 210`), `InsecureTlsBadge` switches to an icon-only compact mode
    (`iconOnly: true`) that preserves the `Icons.gpp_bad_outlined` icon, tooltip, and `Semantics(label: ...)` while let
    the cluster name take priority before truncating.
  - `ClusterDropdown`: Render `InsecureTlsBadge(compact: true)` next to the cluster name and `EnvironmentTagChip` in
    each `DropdownMenuItem`.
  - `EnvironmentBanner`: When `profile.tlsVerification == TlsVerification.disabled`, render `InsecureTlsBadge(compact:
    true)` at the trailing end of the banner row.
- **Alternatives considered**: Keeping an icon-only badge on every tab was rejected by the user during discovery because
  it still repeats connection state across every open topic tab of the same cluster.

### 3. Spaced & Syntax-Tinted JSON Preview and Diff Row Styling

- **Spaced single-line JSON formatting (`TextPreviewUtils.getPayloadPreview`)**:
  - After pruning nulls (when `filterNulls` is true) or scanning a valid JSON object/array, format the single-line
    preview with a single space after `:` and `,` tokens that occur outside double-quoted string literals.
  - To stay fast in viewport builders (lazy UI formatting guardrail), perform the spacing in a single linear pass over
    the truncated character prefix (`maxLength`, default 300 chars) tracking `inString` and `escaped` booleans rather
    than formatting an entire multi-megabyte JSON document before truncating.
  - If the payload is not valid JSON (or does not start with `{` or `[`), keep the existing whitespace-collapsed raw
    string behavior without inserting spaces after colons or commas.
- **Lightweight lexical syntax tinting + search highlight**:
  - Add a helper in `TextPreviewUtils` (or a dedicated `JsonPreviewHighlighter`) that tokenizes the bounded preview
    string (≤ 300 chars) into `key`, `string`, `number`, `literal` (`true`, `false`, `null`), and `punctuation` spans.
  - Map token kinds to theme-derived colors from `Theme.of(context).colorScheme` that meet WCAG AA contrast on both
    `colorScheme.surface` / `surfaceContainerLow` and `colorScheme.primaryContainer` (when `isSelected` is true):
    - Keys: `colorScheme.onSurface` with `FontWeight.w600` (or `onPrimaryContainer` when selected).
    - Strings: `colorScheme.primary` (or `onPrimaryContainer` when selected).
    - Numbers & booleans/null: `colorScheme.tertiary` (or `onPrimaryContainer` with distinct weight when selected).
    - Punctuation (`{ } [ ] : ,`): `colorScheme.onSurfaceVariant`.
  - Overlay `HighlightTextUtils` search-phrase highlighting onto the token spans so in-memory search matches remain
    highlighted with `colorScheme.primaryContainer` / `onPrimaryContainer` (or `tertiaryContainer` when the card itself
    is selected).
- **Consistent code typography**:
  - In `TimelineMessageCard` (`_buildKey` and `_buildPayloadPreview`), `MessagesDiffView` (non-JSON fallback), and
    `JsonDiffWidget`, replace raw `TextStyle(fontFamily: 'monospace')` with `AppFonts.robotoMono(height: 1.4)` scaled by
    the theme's `bodyMedium` / `titleSmall` font size so the global text-size setting applies uniformly.
- **Theme-based diff row colors (`JsonDiffWidget`)**:
  - Replace hardcoded `Colors.green`, `Colors.red`, `Colors.orange`, `Colors.grey`, and `Colors.black87` with
    `colorScheme`-derived colors:
    - Added node: icon `Icons.add`, key and value in a high-contrast theme green/tertiary role (using the app's semantic
      status colors on `colorScheme` or `colorScheme.tertiary` / `onSurface` so dark mode contrast ≥ 4.5:1).
    - Removed node: icon `Icons.remove`, `colorScheme.error` with `TextDecoration.lineThrough`.
    - Changed node: icon `Icons.edit` (`colorScheme.tertiary`), key in `colorScheme.onSurface` bold, old value in
      `colorScheme.error` with `TextDecoration.lineThrough`, arrow `➔` in `colorScheme.onSurfaceVariant`, and new value
      in `colorScheme.onSurface` (`FontWeight.w600`) so the current value is the highest-contrast element in the row.

### 4. One-Row Topic Search Bar with Inline Scope/Type Menu and "More Filters" Popover

- **Inline Scope & Match Type menu inside the fetch filter `TextField`**:
  - Replace the separate `FilterType` and `SearchScope` segmented selectors in the advanced panel with a compact
    leading/prefix `MenuAnchor` button embedded inside `_buildQuickFilterInput`.
  - The button displays the localized summary `<Scope> · <Type>` (for example `Both · Contains` / `Key · Exact`) and a
    dropdown chevron. If `_invalidPattern != null` (invalid regex), it also renders `Icons.error_outline` in
    `colorScheme.error`.
  - Opening the menu shows two grouped sections (`Search Scope`: Key, Value, Both; `Filter Type`: Contains, Regex,
    Exact) with radio/check indicators.
  - The `TextField` hint text adapts to the selected scope (e.g., "Filter while fetching (key & value)...") and the
    field wrapper carries a localized tooltip explaining that this filter is evaluated while reading messages from the
    Kafka topic (distinguishing it from the in-memory results toolbar filter).
- **"More filters" (`MenuAnchor` / `OverlayPortal`) popover**:
  - The trailing toggle button ("More filters" / "Weitere Filter") opens an overlay popover anchored below the right
    edge of the search bar instead of rendering `_buildAdvancedPanel` inline in the `Column`.
  - The button displays a count badge (`(N)`) whenever any of the popover-hosted filters (`Field`, `Partition`,
    `Fast Trace`, or `FilterExpression`) is non-default.
  - Inside the popover (constrained to `maxWidth: 680` and `maxHeight: MediaQuery.sizeOf(context).height * 0.75` with
    `SingleChildScrollView`):
    - Row 1: `Field (Opt.)` autocomplete and `Partition (Opt.)` text field.
    - Row 2: `Fast Trace (Hash Key)` switch and, when enabled, `_buildFastTracePreview` with its assumption disclosure.
    - Row 3: `FilterExpressionEditor` (Builder / Text modes).
  - Clicking outside, pressing `Escape`, or clicking the button again closes the popover without losing state.
  - While the popover is closed, active filters from inside the popover (`Field`, `Partition`, `Fast Trace`,
    `Expression`) render as compact `InputChip`s below the primary row; clicking a chip opens the popover, and clicking
    its delete icon clears that filter. (`Scope` and `FilterType` are always visible in the inline field menu, so they
    no longer need separate chips unless `FilterType` is in an invalid regex state.)
- **Compact Scan Bounds Row (`Time Range` and `Offset / Earliest`)**:
  - In `TimestampPickerField`, add a compact preset mode (`compactPresets: true`, or update `showInlineChips`) that
    replaces the full row of 8 `ActionChip`s below the input with a single compact `MenuAnchor` / `PopupMenuButton` icon
    or text button ("Presets" / clock-history icon with tooltip) inside the `TextField.suffixIcon` alongside the
    "Now" and calendar buttons.
  - In `TopicSearchBar._buildTimeRangeRow` and `_buildOffsetEarliestRow`, reduce container padding to a single compact
    row (`LayoutBuilder`: side-by-side `Row` when `maxWidth >= 640`, wrapping to a 2-line `Column` below 640 px) and
    validate start/end timestamp ordering inline.
- **Alternatives considered**: Removing `Field`/`Type`/`Scope` in favor of `FilterExpression` alone was considered, but
  keeping the simple fetch filter with an inline `Scope · Type` pill preserves instant one-field substring/regex
  filtering and 100% compatibility with existing saved search presets.

### 5. Single-Line Topic Header Facts Strip with Priority Overflow

- **Fact Classification & Priority Order**:
  - Partition every header fact into one of two buckets:
    1. **Pinned / Warning facts (never collapsed)**:
       - Topic metadata error tag (`topic_metadata_error_tag`)
       - Unhealthy partitions warning (`topic_health_tag`, when `underReplicated + leaderless > 0`)
       - Config error/unreadable tags (`topic_config_not_readable_tag`, `topic_config_failed_tag`,
         `topic_retention_not_readable_tag`)
       - Estimate error/unknown/unreadable tags (`topic_estimate_not_readable_tag`, `topic_estimate_unknown_tag`)
       - Time range error/partial warning state (`topic_time_range_error`, partial result tag)
    2. **Regular facts (ordered by priority)**:
       1. Partitions (`topic_partitions_tag`)
       2. Replication factor (`topic_rf_tag`)
       3. Estimated message count (`topic_estimate_tag` / `topic_estimate_loading_tag`)
       4. Schema tag & local schema tag (`topic_schema_tag`, `topic_header_local_schema_tag`)
       5. Cleanup policy tag
       6. Retention duration (`topic_retention_tag`)
       7. Retention bytes (`topic_retention_bytes_tag`)
       8. Time range action / loaded timestamps (`_buildTimeRangeWidget`)
- **Responsive Single-Line Layout**:
  - Replace the multi-line `Wrap` in `_buildTopicTags` with a single-line `LayoutBuilder` strip.
  - Measure or budget the horizontal width of each chip (using deterministic width estimation from label length + icon +
    padding, or a custom single-line overflow layout delegate) against `constraints.maxWidth`.
  - All pinned/warning facts are placed first and guaranteed to be rendered in the strip (wrapping only in the extreme
    case where warnings alone exceed the entire pane width).
  - Regular facts are added in priority order while their cumulative width plus a reserved `56 px` for the `+N` overflow
    chip fits within `constraints.maxWidth`.
  - If one or more regular facts do not fit, render an interactive `TopicTag('+${hidden.length}', key: const
    Key('topic_facts_overflow_tag'))` wrapped in a `MenuAnchor` and `Semantics` / `Tooltip` with localized label
    (e.g. `l10n.topicFactsMoreCount(hidden.length)`).
  - Opening the `+N` popover displays the hidden fact widgets in a vertical/wrapped list inside the menu so interactive
    chips ("Load time range", "Retry", partition health dialog) work identically when activated from the popover.

### 6. Co-locating "Ignored fields (n)" in the Results Toolbar

- In `MessagesDiffView`:
  - Lift the ignore-list toolbar controls (`_topics` dropdown when `_topics.length > 1`, the `TextButton.icon` for
    `diffIgnoredFieldsHeader(ignoredCount)`, and the `hasLoadError` warning icon + message) out of `MessagesDiffView`'s
    body `Column` and remove the top `Padding` + `Divider(height: 1)`.
- In `MessagesView`:
  - When `_activeView == 'diff'`, render the diff ignore-list controls directly inside the results toolbar `Wrap` right
    after `ViewModeSwitcher`.
  - Because `MessagesView` owns the parent state and builds `MessagesDiffView`, share the `DiffIgnoreListService`
    interaction (or pass a toolbar-action builder / controller callback from `MessagesView` to `MessagesDiffView`) so
    that editing the ignore list from either the toolbar button or a diff row's context menu ("Ignore this field")
    immediately updates the toolbar badge count and recomputes visible diff cards.

## Risks / Trade-offs

- **[Risk] Existing widget tests look for fact tags or filter chips that might be inside the overflow/popover on small
  test surfaces** → **Mitigation**: Keep all existing widget `Key`s unchanged (`topic_partitions_tag`, `topic_rf_tag`,
  `topic_estimate_tag`, `topic_retention_tag`, `filter_expression_chip`, `quick_filter_pattern_error`, etc.). On the
  default desktop test surface (`800×600` or wider when configured), primary facts remain visible, and when the `+N`
  overflow or "More filters" popover is opened in tests, the exact same keyed widgets are mounted.
- **[Risk] Linear JSON preview spacing/tokenization could add latency if run on multi-megabyte payloads** →
  **Mitigation**: Always slice/truncate raw string input or stop JSON spacing once `maxLength` (300 characters) is
  reached, and run it lazily inside `TimelineMessageCard.build` only for currently visible timeline/diff tiles.
- **[Risk] Popover positioning on short windows** → **Mitigation**: Constrain the "More filters" popover height to 75%
  of the window height and wrap its body in a `SingleChildScrollView` so the expression builder is always scrollable.

## Migration Plan

No data migration is required. Existing saved search presets, tab session snapshots, cluster profiles, and per-topic
diff ignore lists use their existing keys and schemas unchanged.
