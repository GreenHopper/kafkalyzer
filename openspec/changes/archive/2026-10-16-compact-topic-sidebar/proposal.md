# Proposal

## Why

In the current Explorer topic sidebar, each topic item renders as a tall card (~95–110px height) displaying up to 6 separate metadata tags (`<N> Partitions`, `RF: <N>`, `<cleanup.policy>`, `<retention.ms>`, `Avro`, and an inline `[Schema]` button). Consequently, only 3 to 4 topics can be seen at a time on standard desktop displays, requiring extensive scrolling in clusters with dozens or hundreds of topics.

Broker configuration parameters such as replication factor (`RF: 3`), cleanup policy (`delete`), and retention (`90.0 days`) are redundant in the sidebar during topic browsing; they are already prominently visible in the header of `TopicDetailView` once a topic is opened. Additionally, the internal and stream topic filter controls occupy two full-width `SwitchListTile` rows above the search list, consuming critical vertical space.

Re-architecting the sidebar with high-density topic items (~44–48px height), visual topic name hierarchy (dimmed namespace prefix, bold leaf name), micro-badges, and compact filter chips will double or triple the number of visible topics (8–10 topics at a glance), significantly streamlining topic discovery.

## What Changes

1. **High-Density Topic List Items (`TopicListItem`):**
   - Reduce vertical item height to ~44–48px.
   - Render topic names with clear visual hierarchy: Dimmed/secondary styling for namespace prefixes (all segments before the last dot) and emphasized/bold styling for the leaf name segment (e.g., `kaenup.pmxcor.temp.` in dimmed text + `incomingOutlookMessage` in bold primary text). Single-segment topic names remain bold.
   - Display at most two compact micro-badges aligned to the right: partition count (e.g., `12P`) and schema indicator badge (e.g., `Avro`).
   - Remove low-priority broker configuration tags (`RF`, `cleanup.policy`, `retention.ms`) and the inline `[Schema]` button from the sidebar card, exposing them via tooltip on hover and within the `TopicDetailView` header.
   - Retain full support for single-click selection, double-click instant streaming, and the "open in new tab" action button.

2. **Compact Filter Controls in Topic Sidebar:**
   - Replace the two full-height `Switch` rows (`Internal Topics`, `Kafka Stream Topics`) with compact `FilterChip` elements placed under the search input, minimizing vertical padding.
   - Display clear active/inactive visual states for internal and stream topic filtering.

3. **Accessibility & Localization:**
   - Full German and English localization for all badges, filter chip labels, and tooltips in `app_en.arb` and `app_de.arb`.

## Capabilities

### New Capabilities

- `compact-topic-sidebar`: Provides high-density topic list items with name hierarchy, compact metadata badges, and streamlined filter controls in the Explorer sidebar.

### Modified Capabilities

*(None)*

## Impact

- **Affected Components:**
  - `lib/src/features/topic/presentation/widgets/topic_list_item.dart`: Layout refactored to high-density single/two-line presentation with prefix/suffix formatting and micro-badges.
  - `lib/src/features/explorer/presentation/explorer_view.dart`: Replacement of switch rows with compact filter chips in the topic sidebar header.
  - Localization files: `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`, and generated localization classes.
- **Testing:**
  - `test/src/features/topic/presentation/widgets/topic_list_item_test.dart`: Updated and augmented with name hierarchy and badge rendering tests.
  - `test/src/features/explorer/presentation/explorer_view_test.dart`: Updated to verify new compact filter chip interactions.
- **Dependencies & APIs:**
  - Pure Flutter UI changes; no Rust backend or bridge changes required.
