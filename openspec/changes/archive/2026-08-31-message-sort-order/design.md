## Context

See proposal.md for motivation. Shared message results are rendered by `MessagesView`, which always sorts filtered messages ascending by timestamp before feeding timeline and diff views. The results toolbar already hosts view-mode switching, result search, and export. View mode is persisted via `SharedPreferences` using an optional per-screen `preferencesKey`. Sort order should be persisted **per view type** (timeline, table, diff, schema) so each mode can keep its own chronological preference.

Table view currently receives the unsorted filtered list and applies its own optional per-column sorting. Diff view also re-sorts ascending internally.

## Goals / Non-Goals

**Goals:**
- Add a clear ascending/descending toggle to the results toolbar.
- Apply chronological sort in `MessagesView` based on the preference for the **active** view type.
- Default each view type to descending and persist choices independently in `SharedPreferences`.
- Restore a view type’s sort order when the user switches back to it.

**Non-Goals:**
- Changing Kafka consumption order, seek strategy, or backend fetch order.
- Persisting table column-sort state (partition/offset/key columns remain local UI state).
- Adding multi-column or custom-field sort criteria beyond timestamp chronology.
- Surfacing the preference in the Settings screen (toolbar + SharedPreferences is enough).

## Decisions

### 1. Own sort state in `MessagesView`
**Choice:** Keep the active sort-order state in `_MessagesViewState`, apply it when building `_cachedSortedMessages`, and pass the sorted list to views that display chronological sequences. When the active view mode changes, load that view type’s stored order and re-sort.

**Rationale:** Sorting already lives in `_updateFilters()`; extending that path avoids duplicating preference logic across timeline/diff/table.

**Alternatives considered:**
- Sort only inside each child view → duplicates preference load/save and UI control ownership.
- Global app-level ChangeNotifier → heavier than needed for per-view boolean preferences.

### 2. Preference keys per view type
**Choice:** Persist with SharedPreferences keys `message_sort_order_<view>` where `<view>` is `timeline` | `table` | `diff` | `schema`. Values are `asc` | `desc`. Missing or invalid values default to `desc`.

**Rationale:** Users may prefer newest-first in timeline but oldest-first in table (or vice versa). Independent keys make switching views restore each mode’s last choice without a JSON map or schema migration.

**Alternatives considered:**
- Single global `message_sort_order` → rejected; does not satisfy per-view-type memory.
- One JSON map under a single key → slightly fewer keys, but harder to inspect/debug and no real benefit.
- Derive key from screen `preferencesKey` → per-screen rather than per-view-type; not what was requested.

### 3. Toolbar control placement and affordance
**Choice:** Place a toggle `IconButton` in the results header row near the view-mode switcher (before the search field). Use distinct icons and a localized tooltip so the current order is visible (e.g. ascending vs descending arrows). Use `material_ui` widgets and `AppLocalizations` for all user-facing strings. The control always reflects the **active** view type’s order.

**Rationale:** Matches existing toolbar density and the user’s request to show current order and switch it in that bar.

**Alternatives considered:**
- Dropdown with labeled options → more space, slower for a binary choice.
- Segmented two-button control → clearer labels but heavier than neighboring icon controls.

### 4. Interaction with table column sorting
**Choice:** Pass chronologically sorted messages into `MessagesTableView` using the **table** view type’s preference as the base order. Existing per-column sort remains a local override and does not write back to `message_sort_order_table`.

**Rationale:** Keeps the table view’s chronological preference separate from exploratory column sorts.

**Alternatives considered:**
- Disable column sort when global order is set → regresses current table UX.
- Sync column timestamp sort with the preference → couples unrelated UI states.

### 5. Remove conflicting re-sorts in child views
**Choice:** Where child views (e.g. `MessagesDiffView`) unconditionally re-sort ascending, stop overriding the order supplied by `MessagesView` (or sort using the same ascending/descending flag if a local copy is required).

**Rationale:** Otherwise the toolbar toggle would appear to work only in timeline mode.

## Risks / Trade-offs

- **[Risk] Default change from ascending → descending surprises existing users** → Mitigation: Explicit toolbar indicator; preference is one click to restore ascending per view; record default change in release notes if applicable.
- **[Risk] Diff view semantics assume chronological ascending for pairwise diffs** → Mitigation: Verify diff pairing still makes sense with newest-first; if pairing depends on adjacent chronological neighbors, keep chronological adjacency by sorting fully before pairing (descending still yields a consistent sequence).
- **[Trade-off] Table column sort can diverge from toolbar indicator** → Acceptable; tooltip/docs describe toolbar as timestamp order; column headers remain the source of truth while a column sort is active.
- **[Trade-off] Four preference keys instead of one** → Acceptable; clear and easy to load/save on view switch.

## Migration Plan

- No data migration beyond reading new SharedPreferences keys per view type.
- Missing key for a view type ⇒ descending (new default).
- Rollback: remove control and always sort ascending; orphaned preference keys are harmless.

## Open Questions

None — default descending, per-view-type persistence, toolbar placement are fixed by the request.
