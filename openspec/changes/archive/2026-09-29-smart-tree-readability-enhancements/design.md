## Context

`SmartVirtualJsonTree` virtualizes JSON objects and maps into a flattened list of visible rows with single-row composite badges for recognized semantic entities. However, inspecting real-world Kafka messages (such as transport plans, logistics events, or SAP messages) reveals several friction points:
1. Messages contain dozens of null schema fields, creating overwhelming vertical whitespace.
2. ISO-8601 timestamps are displayed as raw strings without localized formatting or timezone context.
3. Single-item lists require manual user clicks to expand.
4. Composite badge heuristics reject maps having >4 total keys even when 3 or more of those keys are null, causing them to fall back to multi-line trees.
5. Rich domain patterns (nested time periods, route pairs, timestamp-with-metadata objects) are not yet recognized as badges.

## Goals / Non-Goals

**Goals:**
- Provide a persistent toolbar toggle and flattener parameter to hide null-valued fields in the virtual JSON tree.
- Automatically format recognized ISO-8601 strings and epoch timestamps in the tree into localized, human-readable date-time strings with tooltips for raw values.
- Automatically expand single-item arrays (and single-item maps) by default to eliminate unnecessary interaction clicks.
- Enhance `EntityFormatterRegistry` to filter out nulls and empty collections before evaluating badge eligibility, enabling sparse multi-field maps to display as badges.
- Expand badge heuristics for nested time periods (`von`/`bis`), standalone timestamp objects with metadata, and transport leg pairs (`von...`/`nach...`).
- Clean up timeline card previews by filtering nulls from truncated JSON summaries.

**Non-Goals:**
- Mutating underlying message data or serializing modified payloads back to Kafka.
- Permanent structural mutation of JSON: hiding nulls is strictly a presentation-layer filter.
- Deep schema registry inference or external schema downloading.

## Decisions

### Decision 1: Null Filtering in `JsonTreeFlattener` vs Virtual Tree Widget
- **Choice**: Implement `hideNullFields` directly in `JsonTreeFlattener.flatten()` during the linear traversal phase.
- **Rationale**: Filtering at the flattener stage eliminates `VirtualJsonNode` generation entirely for null rows, preserving virtual scroll index integrity, search match indexing, and avoiding ghost rows.
- **Alternatives considered**:
  - *Widget-level height zeroing / `SizedBox.shrink()`*: Breaks `ScrollablePositionedList` item counting and search match jump alignment.
  - *Deep cloning and pruning JSON prior to flattener*: Incurs unnecessary $O(N)$ memory allocations on large Kafka payloads.

### Decision 2: Null-Aware Badge Heuristic Evaluation
- **Choice**: In `EntityFormatterRegistry.tryFormat()`, create an active non-null, non-empty subset of entries before testing key counts and primitive types.
- **Rationale**: An object with 5 keys where 3 are `null` (e.g. `art: "Eintritt"`, `id: "0244..."`, `kundenauftragsId: null`, `trailerKennzeichen: null`, `meilensteine: []`) carries only 2 meaningful attributes. Evaluating non-null entries unlocks badges like `Eintritt • 0244...` while retaining all 5 properties in the pinned popover.
- **Alternatives considered**:
  - *Hardcoding specific domain keys*: Fragile and does not scale across disparate Kafka topics.
  - *Requiring users to manually tag badge fields*: High friction; automatic progressive disclosure is much faster.

### Decision 3: Auto-Expansion Strategy for Single-Item Collections
- **Choice**: Automatically populate single-item list and map paths into `activeExpanded` during flattening, while tracking a set of explicitly user-collapsed paths (`_manuallyCollapsedPaths`) to respect explicit collapse actions.
- **Rationale**: Single-item arrays like `kundenauftragsIds: [ 1 item ]` almost always hide a primitive ID or key that the engineer wants to see immediately. Auto-expanding eliminates 80% of routine clicks when scanning payloads.
- **Alternatives considered**:
  - *Indentation-flattening array-to-primitive (inlining)*: While clean, inlining can complicate JSON path extraction for table column pinning (`onPinToColumn`). Auto-expanding preserves full path integrity for pinning (`kundenauftragsIds[0]`).

### Decision 4: Localized Smart Timestamp Presentation
- **Choice**: Detect datetime patterns lazily in `_buildPrimitiveText` using pre-compiled regexes (`^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?)?$`) and keys containing `timestamp`, `zeit`, `date`, `time`, `datum`. Render formatted date-time using `DateFormatUtils.formatFullTimestamp()` or localized format, paired with a subtle schedule icon and a tooltip showing raw ISO, local, and UTC timestamps.
- **Rationale**: Eliminates mental arithmetic for timezones and epoch timestamps while ensuring the raw timestamp can still be copied with one click.
- **Alternatives considered**:
  - *Replacing the raw string everywhere*: Disrupts developers who need exact ISO-8601 strings for API testing or database queries. Tooltips + copy affordances guarantee both needs are met.

### Decision 5: Extended Heuristic Models in `EntityFormatterRegistry`
- **Choice**: Add specialized evaluators for:
  1. *Nested / German Time-Windows*: Match keys like `planTimestampVon`/`planTimestampBis`, `von`/`bis`, `start`/`ende`, resolving both direct strings and nested timestamp objects `{ timestamp: "..." }`.
  2. *Timestamp with Metadata*: Match maps containing a primary timestamp key (`timestamp`, `zeit`) and metadata (`zeitQuelle`, `source`), producing `🕒 29.09.2026 19:00:00 (SYSTEM)`.
  3. *Route / Transport Leg*: Match keys with `von...`/`nach...` or `origin`/`destination` to render `🚚 $from → $to`.
- **Rationale**: Directly maps to the high-frequency patterns observed in logistics, transport, and event messaging shown in the screenshots.

## Risks / Trade-offs

- **[Risk] User misses fields because they are hidden by the null filter**
  → **Mitigation**: Display an explicit visual indicator on the toolbar toggle (e.g. active badge / counter `Hide empty (N hidden)`) and show a small note at the bottom or header of the tree so the user is always aware when filtering is active.
- **[Risk] High-throughput regex parsing on large payloads impacting 60 FPS scrolling**
  → **Mitigation**: Regex checks are performed only on leaf string nodes during widget building in the virtual viewport, never eagerly across thousands of unexpanded offscreen nodes.
- **[Risk] Over-eager timestamp detection on non-timestamp strings (e.g. serial numbers)**
  → **Mitigation**: Require strict ISO-8601 structure with year-month-day separators and optional timezone offsets, plus contextual key name hints.

## Migration Plan

- All settings (`hideNullFields`, auto-expansion) default to enabled or opt-in with persistence via `SharedPreferences`.
- Pure frontend presentation change; no data migration, schema evolution, or backend changes required.
