## Context

See proposal.md for motivation. `MessagesTableView` already supports `showTopic` and `showStep` (both default `false`) and adjusts column layout accordingly. Script run details already pass `showTopic: true` and `showStep: true`. Topic explorer hosts messages via `MessagesView`, which currently hardcodes both flags to `true` when building the table (`// Configurable?` comments mark this as unfinished).

## Goals / Non-Goals

**Goals:**
- Stop showing Step/Topic in the explorer table path.
- Keep Step/Topic visible for scripting tables.
- Prefer wiring existing flags over new UI or preference settings.

**Non-Goals:**
- User-configurable column chooser or persistence of column visibility.
- Changing timeline/diff layouts or metadata cards.
- Hiding topic name elsewhere in the explorer chrome (header, sidebar).

## Decisions

### 1. Configure columns via `MessagesView` parameters
**Choice:** Add `showTopic` / `showStep` to `MessagesView` (default `false`, matching `MessagesTableView`) and forward them into `MessagesTableView`. Leave `topic_detail_view` on the defaults (hidden). Leave script run details on its direct `MessagesTableView` call with both `true`.

**Rationale:** Flags already exist and are tested; explorer is the only `MessagesView` caller today, so defaults alone fix the bug without forcing every call site to opt out.

**Alternatives considered:**
- Hardcode `false` only inside `MessagesView` without parameters → less flexible if another host later needs the columns through `MessagesView`.
- Detect “script feature” via route/DI → couples presentation to navigation and is brittle.

### 2. Scope limited to table view
**Choice:** Only change table column visibility. Timeline/diff keep current presentation.

**Rationale:** The reported issue is specifically about table columns; other views do not surface Step/Topic as columns.

## Risks / Trade-offs

- **[Risk] Another future `MessagesView` host expects Step/Topic by default** → Mitigation: Document that callers must pass `showTopic` / `showStep` when those columns are needed; defaults match the table widget.
- **[Trade-off] Explorer cannot optionally show Topic for multi-topic result sets** → Acceptable for now; explorer search is topic-scoped. Revisit if multi-topic explorer results appear.

## Migration Plan

- No data migration.
- Rollback: restore `MessagesView` table flags to `true`.

## Open Questions

None.
