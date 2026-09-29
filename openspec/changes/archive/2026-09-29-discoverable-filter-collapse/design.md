## Context

See proposal.md for motivation. In `TopicDetailView._buildSettings`, the Search Configuration block is an `ExpansionTile` with `initiallyExpanded: true` and a custom `trailing: Icon(Icons.tune)`. Providing a custom trailing widget suppresses Material's default expand/collapse chevron, so the only header cue looks like a settings control. Collapse already works when the title row is tapped; discoverability is the gap.

Filter fields, start/stop conditions, and streaming controls are unchanged. No Rust or bridge involvement.

## Goals / Non-Goals

**Goals:**
- Make expand/collapse of the Search Configuration panel visually obvious in both states.
- Keep the entire header row as the toggle target.
- Localize the panel title and toggle tooltips.
- Cover collapse/expand behavior with a widget test.

**Non-Goals:**
- Changing filter fields, search strategies, or streaming behavior.
- Persisting expand/collapse preference across sessions (current behavior is `initiallyExpanded: true` per view mount).
- Redesigning the filter form layout or splitting settings into a separate dialog/drawer.
- Adding keyboard shortcuts beyond what `ExpansionTile` already provides.

## Decisions

### 1. Keep `ExpansionTile`; fix the trailing affordance

**Choice:** Continue using `ExpansionTile` for the Search Configuration panel. Replace the static `Icons.tune`-only trailing with a trailing row that always includes a stateful expand/collapse chevron (`Icons.expand_more` / `Icons.expand_less`, or the default `ExpansionTile` chevron via `ExpansionTileController` / controlled `trailing` that mirrors `isExpanded`).

**Rationale:** Collapse behavior already exists and fits Material patterns. The bug is the overridden trailing icon, not the widget choice. Restoring a chevron is the smallest change that matches user expectations.

**Alternatives considered:**
- Remove custom trailing entirely and rely on the default chevron: simplest; loses the “settings/filter section” visual cue.
- Move filters into a modal/drawer opened by `Icons.tune`: larger UX change; users lose in-place editing while viewing results.
- Add a separate labeled “Hide filters” / “Show filters” text button below the header: clearer copy, but adds clutter and duplicates the ExpansionTile header.

### 2. Optional filter cue without replacing the chevron

**Choice:** If a settings/filter cue is still desired, place a small leading or title-adjacent `Icons.tune` / `Icons.filter_alt` icon, and keep the chevron as the trailing disclosure control. Prefer chevron-only trailing if space is tight.

**Rationale:** Separates “what this section is” (filter config) from “what this control does” (expand/collapse).

**Alternatives considered:**
- Chevron + tune both in trailing: acceptable if compact (`Row` with both icons); ensure the row still toggles via the tile, not a nested `IconButton` that eats taps incorrectly.

### 3. Controlled expansion for tooltip and icon state

**Choice:** Track expansion with local state (`bool _isSearchConfigExpanded`, default `true`) via `onExpansionChanged`, and build trailing/tooltip from that flag. Use `ExpansionTile`’s `onExpansionChanged` rather than introducing a new controller unless needed for tests.

**Rationale:** Tooltips and chevron direction need the current state; `initiallyExpanded` alone does not expose it to the build method after toggles.

### 4. Localization keys

**Choice:** Add ARB keys such as `searchConfigurationTitle`, `collapseSearchConfiguration`, and `expandSearchConfiguration` (EN + DE), then wire them through `AppLocalizations`.

**Rationale:** Project rule: no hardcoded user-facing strings. The current title `"Search Configuration"` already violates this and should be fixed as part of this change.

## Risks / Trade-offs

- [Users relied on tune icon as a mental “settings” marker] → Mitigate by optionally keeping a small leading tune/filter icon while restoring the chevron as the primary disclosure control.
- [Nested IconButtons in trailing steal ExpansionTile taps] → Prefer non-button `Icon` widgets in trailing so the tile’s InkWell handles the toggle; wrap the header with `Tooltip` rather than a separate button.
- [Widget tests need stable finders] → Key the ExpansionTile or find by localized title + chevron icons.

## Migration Plan

- Pure UI change; no data migration.
- Default remains expanded on first open (preserves current first-run behavior).
- Rollback: revert trailing/header changes in `topic_detail_view.dart` and related l10n/test files.

## Open Questions

- None that block implementation; whether to keep a decorative tune icon beside the title can be decided during apply based on visual density in the live header.
