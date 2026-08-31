## Context

See proposal.md for motivation. `MessagesView` already sorts filtered messages by timestamp with per-view ascending/descending prefs (`message_sort_order_<view>`). The results toolbar has an order toggle next to the view-mode switcher. `MessagesTableView` still has independent local column sorting that does not write back to those prefs.

## Goals / Non-Goals

**Goals:**
- Let users pick sort field: timestamp, partition, offset, key, value (payload).
- Persist field per view type alongside direction.
- Keep timestamp + descending as defaults when prefs are missing.
- Place all sorting controls (field + direction) in the results toolbar **before** the view-mode switcher.

**Non-Goals:**
- Multi-column / secondary sort keys.
- Syncing toolbar field selection with table header column-sort state.
- Sorting by topic or step (script-only columns outside this request).
- Changing Kafka fetch/seek order on the consumer.

## Decisions

### 1. Extend `MessagesView` sort pipeline
**Choice:** Store active field per view in `_MessagesViewState`, apply a field-aware comparator in `_updateFilters()`, and pass the sorted list to child views as today.

**Rationale:** Direction and list ownership already live here; adding field keeps one source of truth for timeline/diff/table base order.

**Alternatives considered:**
- Only expose field selection in table headers → does not help timeline/diff.
- Global single field for all views → inconsistent with existing per-view direction prefs.

### 2. Preference keys per view for field
**Choice:** Persist with SharedPreferences keys `message_sort_field_<view>` where `<view>` is `timeline` | `table` | `diff` | `schema`. Values: `timestamp` | `partition` | `offset` | `key` | `value`. Missing/invalid ⇒ `timestamp`.

**Rationale:** Mirrors `message_sort_order_<view>`; independent keys avoid encoding field+direction in one string.

**Alternatives considered:**
- Single JSON blob per view → harder to inspect; unnecessary for two scalars.
- Reuse order key with composite values → breaks existing `asc`/`desc` readers.

### 3. Toolbar field control and placement
**Choice:** Add a compact dropdown or popup menu (Material via `material_ui`) next to the direction `IconButton`, showing the current field label. Localized labels for all five fields. Keep the existing direction toggle; update tooltips so they are not timestamp-only when another field is active (e.g. generic ascending/descending, or field-aware copy).

**Toolbar order (left-to-right among these controls):** sort field selector → ascending/descending toggle → view-mode switcher (`ViewModeSwitcher`) → search → export. Move the existing direction toggle from after the view switcher to before it as part of this change.

**Rationale:** Sorting is about the message list itself; view mode is a presentation concern. Grouping sort controls first keeps related actions together and matches the requested layout.

**Alternatives considered:**
- Combined “sort by …” dialog → slower for frequent switches.
- Cycle button through fields → poor discoverability with five options.
- Keep sort controls after view mode → rejected; user requested sort controls first.

### 4. Comparison rules
**Choice:**
- `timestamp`, `partition`, `offset`: numeric compare on the message fields.
- `key`, `value`: case-sensitive string compare on `key` / `payload`; treat `null` as `""`.
- Apply ascending/descending by flipping the comparison result (same pattern as today).

**Rationale:** Predictable, matches how users read Kafka metadata and payloads in the UI.

### 5. Table column sort interaction
**Choice:** Toolbar field+direction defines the list passed into `MessagesTableView`. Existing per-column table sort remains a local override and does not update `message_sort_field_*` prefs.

**Rationale:** Preserves current table UX; avoids fighting two sources of persisted truth in this change.

## Risks / Trade-offs

- **[Risk] Large payloads make string compares expensive** → Mitigation: compare existing in-memory strings only; no new decoding. Acceptable for typical result limits (e.g. hundreds of messages).
- **[Risk] Asc/desc tooltips still say oldest/newest** → Mitigation: generalize localization strings as part of this change.
- **[Trade-off] Table header sort can diverge from toolbar field** → Same trade-off as direction-only sorting; document toolbar as the shared base order.

## Migration Plan

- New keys only; existing `message_sort_order_*` unchanged.
- Missing field key ⇒ timestamp.
- Rollback: remove field control and always compare timestamp.

## Open Questions

None — field set and persistence model follow the request and existing per-view pattern.
