# Design

## Context

The topic search and consumption interface in Kafkalyzer is managed by `TopicDetailView` (`lib/src/features/topic/topic_detail_view.dart`) in combination with `MessageStreamController`. The current interface uses an `ExpansionTile` containing two heavy child widgets: `StartConditionConfiguration` and `EndConditionConfiguration`, exposing a 2x4 matrix of start and stop combinations plus 6 additional filter and partition inputs simultaneously.

Additionally, the message streaming action button is decoupled from the search panel, residing in `_buildProgressActions` in the topic tab header.

See `proposal.md` for full motivation and problem analysis.

## Goals / Non-Goals

**Goals:**
- Provide 4 intuitive, preset-based scan modes (`TopicScanMode`):
  1. `latestN`: Bounded fetch of the latest $N$ messages (defaults to 200).
  2. `liveTail`: Continuous real-time stream from latest offset (`run_forever = true`).
  3. `timeRange`: Bounded time-window scan with datetime pickers.
  4. `offsetEarliest`: Earliest topic consumption or custom offset range.
- Provide a clean, compact 1-row primary search bar with quick text filter, limit dropdown, preset selector, advanced filter toggle, and context-sensitive action button.
- Implement progressive disclosure: Collapse advanced inputs (`Field`, `Filter Type`, `Search Scope`, `Partition`, `Fast Trace`) into an expandable panel (`_isAdvancedExpanded = false` by default).
- Render non-default advanced filters as visual chips in the compact bar when collapsed.
- Implement a context-sensitive action button directly in the search bar with dynamic labeling and a visual dirty-state indicator when parameters change after messages have been loaded.
- Modularize the search bar into a dedicated, testable widget `TopicSearchBar` (`lib/src/features/search/presentation/widgets/topic_search_bar.dart`).

**Non-Goals:**
- Modifying backend Rust Kafka consumer streaming logic or protocol (all required strategies are already supported by the native consumer).
- Modifying `MessageStreamController` backend consumption methods.
- Redesigning the topic sidebar or results table toolbar (handled by separate changes).

## Decisions

### Decision 1: `TopicScanMode` Preset Architecture
- **Choice:** Define an explicit enum `TopicScanMode` with 4 values:
  - `latestN`: Maps to `startStrategy = MultiSearchStartStrategy.latest`, `endStrategy = MultiSearchEndStrategy.latest`, with `limitResults = true`.
  - `liveTail`: Maps to `startStrategy = MultiSearchStartStrategy.latest`, `endStrategy = MultiSearchEndStrategy.latest` (or `earliest`), with continuous streaming (`run_forever = true`).
  - `timeRange`: Maps to `startStrategy = MultiSearchStartStrategy.customTimestamp`, `endStrategy = MultiSearchEndStrategy.customTimestamp`.
  - `offsetEarliest`: Maps to `startStrategy = MultiSearchStartStrategy.earliest` or `customOffset`.
- **Rationale:** Replacing the combinatorial 2x4 start/stop condition matrix with 4 purposeful presets aligns with user mental models and eliminates contradictory configurations.
- **Alternatives Considered:** Keeping the low-level start/stop matrix and adding a "wizard". Rejected because it introduces unnecessary modal complexity without fixing the default clutter.

### Decision 2: Dedicated Component Extraction (`TopicSearchBar`)
- **Choice:** Extract the search bar into `lib/src/features/search/presentation/widgets/topic_search_bar.dart`.
- **Rationale:** `TopicDetailView` is currently over 850 lines long. Moving the search bar and its progressive disclosure state to a dedicated widget isolates UI presentation, prevents layout regressions, and enables targeted widget testing.
- **Alternatives Considered:** Inlining the changes directly in `TopicDetailView`. Rejected due to file bloat and poor testability.

### Decision 3: Progressive Disclosure and Filter Summary Chips
- **Choice:** When `_isAdvancedExpanded` is false, inspect active parameters. If any non-default parameter is set (`partition != null`, `field.isNotEmpty`, `filterType != FilterType.contains`, `fastTraceEnabled == true`), render small removable `FilterChip` widgets in the bar.
- **Rationale:** Users need to know when filters are actively constraining results without having to expand the panel to check.
- **Alternatives Considered:** Only showing a dot or badge on the "Advanced" button. Rejected because chips provide immediate transparency into *which* filters are active.

### Decision 4: Parameter Snapshot for Dirty State Tracking
- **Choice:** Store a snapshot of parameters (`_lastAppliedParams`) when consumption starts. When `streamController.messages.isNotEmpty`, compare the active parameters against `_lastAppliedParams`. If different, apply a dirty highlight style to the primary CTA button.
- **Rationale:** Direct parameter snapshot comparison prevents false dirty states if the user edits a value and then changes it back to the original.
- **Alternatives Considered:** Setting a boolean dirty flag on text input changes. Rejected because it cannot reliably handle reverting edits.

## Risks / Trade-offs

- **[Risk: Horizontal overflow on compact screen widths]**
  → **Mitigation:** Use `Wrap` and `LayoutBuilder` in `TopicSearchBar` to stack controls responsively when available width is below 900px.
- **[Risk: Advanced users needing obscure offset combinations]**
  → **Mitigation:** The `Offset / Earliest` preset allows full customization of partition offsets and end offsets.
