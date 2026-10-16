# Proposal

## Why

In Kafka topic exploration, users frequently encounter cognitive friction with the current `Suchkonfiguration` (search configuration) interface. The panel exposes over 12 configuration inputs simultaneously by default (`Field`, `Values`, `Type`, `Scope`, `Limit`, `Partition`, `Fast Trace`, `Start Condition` with 4 options + inputs, `End Condition` with 4 options + inputs).

Furthermore, the mental model of combining separate 2x4 start and end condition matrices creates confusion—especially combinations such as `Start: Latest` + `End: Latest` or `End: Live`. Users also experience a disconnect between configuring their search in the panel and having to click a separate `Stream` action button far away in the top header, which misleadingly labels finite batch fetching operations as "Stream".

Streamlining this into an intuitive 1-row search bar with 4 standard scan-mode presets, progressive disclosure for advanced filters, context-sensitive action buttons, and visual dirty-state indicators will drastically reduce cognitive load and onboarding friction.

## What Changes

- **Scan Mode Presets:** Replace the complex combination of independent start and stop condition widgets with four clear, purpose-driven presets:
  1. **Latest N Messages** (`⚡ Letzte N Nachrichten`): Default bounded fetch reading the latest $N$ messages up to the high watermark (`start: latest`, `stop: latest`).
  2. **Live Tail Stream** (`📡 Live-Stream`): Continuous streaming of incoming messages starting from the tail (`start: latest`, `stop: live`).
  3. **Time Range** (`🕒 Zeitraum`): Bounded scan between two timestamps using a date/time picker (`start: customTimestamp`, `stop: customTimestamp`).
  4. **Offset / Earliest** (`🎯 Ab Offset / Anfang`): Granular offset or earliest message consumption (`start: earliest` or `customOffset`).
- **Compact 1-Row Search Bar Layout:** Display a compact control bar by default containing the scan mode preset selector, a quick filter text field (`Filter on fetch (key or value)...`), result limit dropdown, advanced settings toggle (`⚙️ Erweitert`), and an integrated primary action button.
- **Progressive Disclosure (`⚙️ Erweitert`):** Collapse advanced filter options (`Field`, `Filter Type: Contains | Regex | Exact`, `Search Scope: Key | Value | Both`, `Partition`, `Fast Trace (Hash Key)`) into an expandable drawer/panel that remains collapsed by default.
- **Active Filter Summary Chips:** When the advanced section is collapsed, render compact visual chips for any non-default active filters (e.g. `Partition: 3`, `Exact`, `Field: id`) in the search bar.
- **Context-Sensitive Action Button & Visual Dirty State:**
  - Move the primary action button directly into the search bar.
  - Dynamically update the button label based on mode and limit: e.g. `[ ► 200 Nachrichten abrufen ]` / `[ ► Fetch 200 Messages ]` for finite modes, vs `[ 📡 Live-Stream starten ]` / `[ 📡 Start Live Stream ]` for live tail.
  - Highlight the button with a visual "dirty state" (accent styling/subtle pulse) when search parameters change after messages have already been loaded, making it obvious to the user that new server-side scanning is needed.
- **Localization:** Provide English and German localized strings for all presets, tooltips, chips, and button labels.

## Capabilities

### New Capabilities
*(None - this change enhances the topic consumption and search UI experience)*

### Modified Capabilities
- `topic-consumption`: Add requirements for preset-based scan mode selection, progressive disclosure of advanced filter parameters, and context-sensitive action button behavior with visual dirty-state indication.

## Impact

- **UI / Frontend Code:**
  - `lib/src/features/topic/topic_detail_view.dart`: Refactor `_buildSettings`, header action controls, and dirty-state tracking.
  - `lib/src/features/search/presentation/widgets/`: Add scan mode preset mapping and compact bar components; keep low-level condition widgets for advanced / custom offset modes.
  - `lib/l10n/app_en.arb` & `lib/l10n/app_de.arb`: Add localization strings for presets, labels, chips, and buttons.
- **APIs & State:**
  - No breaking changes to `MessageStreamController` or `rust_lib_kafkalyzer` bridge APIs. Presets cleanly map to existing `MultiSearchStartStrategy` and `MultiSearchEndStrategy` enum values.
