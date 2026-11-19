# Tasks

## 1. Localization Keys

- [x] 1.1 Add English and German ARB entries in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` for the fetch-time filter labels and tooltip, the inline scope/type menu summary, the "More filters" button and active-count label, the time preset menu tooltip, and the topic header facts `+N` overflow chip tooltip/semantics, then run `flutter gen-l10n` (or `flutter analyze`) to verify generated localization classes compile cleanly.

## 2. Connection-Level Insecure TLS Marker

- [x] 2.1 Remove `InsecureTlsBadge` from the Explorer topic tab subtitle row in `lib/src/features/explorer/presentation/explorer_view.dart` while keeping the cluster profile name and `EnvironmentTagChip`.
- [x] 2.2 Add an optional `iconOnly` mode to `InsecureTlsBadge` (`lib/src/features/cluster/presentation/widgets/insecure_tls_badge.dart`) and render the badge on connection-level surfaces: `ExplorerView._buildClusterListTitle` (falling back to `iconOnly` when the sidebar is narrow so the cluster name truncates before the marker is dropped), `ClusterDropdown` (`lib/src/features/cluster/presentation/widgets/cluster_dropdown.dart`), and `EnvironmentBanner` (`lib/src/features/cluster/presentation/widgets/environment_tag.dart`).
- [x] 2.3 Update and add widget tests for `ExplorerView`, `ClusterDropdown`, and `EnvironmentBanner` to verify that topic tabs never show `InsecureTlsBadge`, that insecure profiles show the badge in the sidebar, dropdowns, and banner, and that narrow sidebars retain the badge icon and tooltip (`flutter test`).

## 3. Card Payload Preview & Diff Row Readability

- [x] 3.1 Update `TextPreviewUtils.getPayloadPreview` (`lib/src/ui/text_preview_utils.dart`) to format JSON object/array previews with a single space after every `:` and `,` outside string literals within the bounded preview length, leaving non-JSON payloads and string contents untouched, and add unit tests in `test/` verifying spaced JSON, strings containing `:`/`,`, and non-JSON text.
- [x] 3.2 Add a lightweight lexical JSON preview highlighter and update `TimelineMessageCard` (`lib/src/ui/messages/widgets/timeline_message_card.dart`) and `MessagesDiffView` (`lib/src/ui/messages/views/messages_diff_view.dart`) to render keys and payload previews with `AppFonts.robotoMono(height: 1.4)`, theme-derived syntax colors (`colorScheme`) that meet WCAG AA contrast in light, dark, and selected states, and overlaid search-phrase highlighting.
- [x] 3.3 Update `JsonDiffWidget` (`lib/src/features/scripting/presentation/widgets/diff/json_diff_widget.dart`) to use `AppFonts.robotoMono(height: 1.4)` scaled with the theme text size and replace hardcoded `Colors.green`/`red`/`orange`/`grey`/`black87` with `colorScheme`-derived status and text roles, rendering the new value of a changed row in `colorScheme.onSurface` (`FontWeight.w600`).
- [x] 3.4 Add widget tests for `TimelineMessageCard` and `JsonDiffWidget` covering light/dark theme contrast, `AppFonts.robotoMono` font family, text-scale responsiveness, and search highlight preservation (`flutter test`).

## 4. Single-Line Topic Header Facts Strip

- [x] 4.1 Refactor `_buildTopicTags` in `lib/src/features/topic/topic_detail_view.dart` into a single-line priority strip that pins warning/error/unreadable/unknown facts first, shows primary regular facts (partitions, replication factor, message estimate, schema) in priority order as width allows, and collapses remaining regular facts into a `+N` overflow `TopicTag` (`Key('topic_facts_overflow_tag')`) with a `MenuAnchor` popover and localized semantics.
- [x] 4.2 Add widget tests for `TopicDetailView` at laptop (`900 px`) and wide viewports verifying that regular facts collapse into the `+N` popover on narrow widths, interactive actions ("Load time range", "Retry") work from inside the popover, and warning/unreadable/unknown facts are never collapsed (`flutter test`).

## 5. One-Row Topic Search Bar & Compact Scan Bounds

- [x] 5.1 Embed a compact inline `Scope · Type` `MenuAnchor` selector inside the fetch filter `TextField` in `lib/src/features/search/presentation/widgets/topic_search_bar.dart` (including an error icon when a regex pattern is invalid), and update the field placeholder and tooltip to clearly distinguish fetch-time filtering from the in-memory results filter.
- [x] 5.2 Replace the inline `_buildAdvancedPanel` expansion in `TopicSearchBar` with an anchored "More filters" overlay popover (`MenuAnchor` / `OverlayPortal`) showing the active filter count badge `(N)` on the trigger button, containing `Field`, `Partition`, `Fast Trace` with its partition preview, and `FilterExpressionEditor` inside a height-bounded scrollable container, while keeping active filter summary chips in the compact bar when closed.
- [x] 5.3 Add a compact preset menu mode to `TimestampPickerField` (`lib/src/ui/timestamp_picker_field.dart`) and update `_buildTimeRangeRow` and `_buildOffsetEarliestRow` in `TopicSearchBar` so scan bounds render side by side in a single compact row with inline range validation instead of rendering two rows of preset chips.
- [x] 5.4 Update and add widget tests for `TopicSearchBar` and `TimestampPickerField` covering the inline scope/type menu, the "More filters" overlay popover (opening without pushing down results, active count badge, Escape/outside close, chip summary), compact time-range presets, and saved-search restoration (`flutter test`).

## 6. Diff Ignore-List Control in the Results Toolbar

- [x] 6.1 Move the "Ignored fields (n)" button, multi-topic ignore-list selector, and unreadable-ignore-list warning out of the dedicated top row in `MessagesDiffView` (`lib/src/ui/messages/views/messages_diff_view.dart`) into the `MessagesView` results toolbar (`lib/src/ui/messages/messages_view.dart`) next to `ViewModeSwitcher` whenever `_activeView == 'diff'`.
- [x] 6.2 Update widget tests for `MessagesView` and `MessagesDiffView` to verify that the "Ignored fields (n)" control, multi-topic selector, and load-error warning appear in the results toolbar only in Diff mode and that no extra row or divider is rendered above the diff timeline (`flutter test`).

## 7. Final Verification

- [x] 7.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and `scripts/check_read_only.sh` (plus `cargo test --workspace` in `rust/` if needed) and verify all checks pass with zero warnings.
