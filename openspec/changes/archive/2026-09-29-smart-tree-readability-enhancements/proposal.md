## Why

Kafka message payloads frequently contain sparse business schemas with dozens of null fields, raw ISO-8601 timestamps, collapsed single-element arrays, and multi-field objects where most properties are null. Currently, this fills the screen with visual noise, hides key business information behind multiple manual expansion clicks, and fails badge heuristics—drastically slowing down message inspection and root-cause analysis.

## What Changes

- **Filter / Hide Empty (Null) Fields**: Provide an interactive toolbar toggle and flattener option in `SmartVirtualJsonTree` / `JsonOrStringViewer` to filter out `null` fields (and optionally empty collections) from the tree view, significantly reducing visual clutter on sparse payloads.
- **Human-Readable Timestamp Formatting**: Automatically detect ISO-8601 datetime strings and epoch timestamps (matching common datetime key patterns or formats) and render them with clean localized date-time formatting (e.g., `29.09.2026 19:00:00 (+01:00)`) and clock/calendar icons, with a tooltip showing raw values and timezone details.
- **Auto-Expansion of Single-Entry Lists**: Automatically expand single-item arrays (and optionally single-entry maps) by default during tree flattening, eliminating redundant clicks to reveal lone child elements like `kundenauftragsIds[0]`.
- **Null-Aware Badge Eligibility**: Update `EntityFormatterRegistry` to evaluate non-null/non-empty fields rather than raw key counts, allowing objects with 5 fields where 3 are null (such as `aktionen[0]`) to qualify as compact badges instead of rendering as expanded multi-line blocks.
- **Extended Composite Badge Heuristics**: Expand heuristic recognizers in `EntityFormatterRegistry` to support:
  - Nested time intervals / period objects (e.g., `planTime` with `planTimestampVon` and `planTimestampBis`, or `von`/`bis`).
  - Standalone timestamp objects with metadata (e.g., `{ timestamp: "...", zeitQuelle: "..." }`).
  - Route / transport segment entities (`von`/`nach`, `source`/`target`, `origin`/`destination`).
  - Single non-null identifying field compact badges.
- **Timeline Card Preview Readability**: Enhance timeline message card previews to filter null values or highlight key entity badges rather than displaying raw truncated JSON strings with braces and nulls.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `smart-virtual-json-tree`: Add requirements for empty/null field filtering, smart timestamp detection and formatting, automatic single-entry array expansion, null-aware badge qualification, and extended composite badge heuristics.

## Impact

- **Frontend UI**:
  - `lib/src/ui/smart_tree/json_tree_flattener.dart`: Add `hideNullFields` option and auto-expand logic for single-item collections.
  - `lib/src/ui/smart_tree/smart_virtual_json_tree.dart`: Add timestamp formatting renderer, toolbar toggle for hiding empty fields, and pass-through configuration.
  - `lib/src/ui/smart_tree/entity_formatter_registry.dart`: Clean/filter nulls before heuristic evaluation, add heuristics for nested time-ranges, timestamp metadata objects, and route pairs.
  - `lib/src/ui/json_or_string_viewer.dart`: Add "Hide empty fields" toolbar toggle button with persisted user preference.
  - `lib/src/ui/messages/widgets/timeline_message_card.dart`: Improve payload preview formatting for JSON messages.
  - Localization files (`app_en.arb`, `app_de.arb`): Add tooltips and labels for empty field filtering and timestamp display.
- **Dependencies**: No external dependency changes required; utilizes existing Flutter `material_ui` and `intl`/`DateFormatUtils`.
- **Breaking Changes**: None. Backwards compatible with existing message views and tree configurations.
