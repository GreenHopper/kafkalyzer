## Context

See `proposal.md` for motivation. Currently, in `SmartVirtualJsonTree`:
- Maps can be detected by `EntityFormatterRegistry.tryFormat(Map<String, dynamic>)` when collapsed and rendered as a `JsonNodeType.compositeBadge` using `SmartCompositeBadge`.
- Lists are always handled as `JsonNodeType.array` in `JsonTreeFlattener.traverse()`. Single-item lists (`currentNodeValue.length == 1`) are auto-expanded by default unless manually collapsed. When expanded, they display a child row `[0]: "VALUE"`. When collapsed, they display `[ 1 item ]` without any content badge.
- `SmartCompositeBadge` currently expects `data` to be `Map<String, dynamic>`. Its popover renders key-value rows using `widget.data.entries`.

## Goals / Non-Goals

**Goals:**
- Detect lists containing 1 to 3 simple primitive elements (strings, numbers, booleans) and format them into compact single-line badges (e.g. `["ENTLADESTELLE"]` or `["A", "B"]`) with an accent badge color and collection icon.
- When collapsed, render these compact lists as `SmartCompositeBadge` chips so users see their values inline without taking multiple lines or expanding the tree.
- When a user interacts with the badge (hover or click-to-pin), display the list values indexed cleanly (e.g., `[0]: ENTLADESTELLE`) with copy support.
- Prioritize compact list badge display when eligible, even if `autoExpandSingleItemCollections` is enabled (compact primitive lists stay neatly collapsed as badges until user clicks chevron or key to expand).
- Allow users to manually expand the list to inspect traditional child nodes `[0]`, `[1]`, etc., if desired.

**Non-Goals:**
- Compacting lists with nested complex structures (e.g. lists of objects or lists of lists).
- Compacting large lists (> 3 items) or lists whose formatted string representation exceeds the compact badge limit (80 characters).
- Changing context windowing or array search segmentation behavior for large arrays.

## Decisions

### 1. Extensible List Evaluator in `EntityFormatterRegistry`
- **Decision**: Add `static FormattedBadgeData? tryFormatList(List<dynamic> list)` to `EntityFormatterRegistry`.
  - Criteria for compact badge:
    - `list.isNotEmpty && list.length <= 3`
    - All elements are primitive types (`String`, `num`, `bool`)
    - None of the elements are empty or purely whitespace strings
    - Individual strings are capped (e.g., length <= 50)
    - Total label representation `[ "...", "..." ]` is <= 80 characters
  - Produces `FormattedBadgeData(icon: Icons.list_alt, label: '[ ... ]', color: Colors.indigoAccent)` or similar harmonious color token.
- **Rationale**: Keeps entity formatting logic centralized, isolated, and unit-testable alongside existing map entity heuristics.
- **Alternatives considered**: Inline formatting in `JsonTreeFlattener`. Rejected to maintain separation of concerns and keep heuristic rules in `EntityFormatterRegistry`.

### 2. Interaction with `autoExpandSingleItemCollections`
- **Decision**: In `JsonTreeFlattener`, before auto-expanding a 1-item list, check if `tryFormatList()` matches. If matched and not explicitly expanded, keep it collapsed so it renders as a compact badge on a single row rather than auto-expanding into two rows.
- **Rationale**: The user problem is specifically that 1-item lists like `aktionsKategorien: ["ENTLADESTELLE"]` either show `[ 1 item ]` (collapsed) or take two lines `[0]: "ENTLADESTELLE"` (expanded). Showing the compact badge directly inline solves both readability and compactness. If the user clicks the expand chevron, it expands into child nodes.

### 3. Rendering in `SmartCompositeBadge`
- **Decision**: Generalize `SmartCompositeBadge` data parameter to accept `dynamic data` (supporting both `Map<String, dynamic>` and `List<dynamic>`). In the popover:
  - If `data` is `List`, render rows as `[0]`, `[1]`, `[2]` with their respective values.
  - In `_copyFullObject`, handle `List` with `JsonEncoder.withIndent(' ').convert(widget.data)`.
- **Rationale**: Reuses the tested overlay portal, hover timer, click-to-pin, and styling logic without duplicating widget code.

## Risks / Trade-offs

- **[Search Visibility]** A search query might match an item in a collapsed compact list.
  - *Mitigation*: In `JsonTreeFlattener`, check if `badge.label.toLowerCase().contains(query)`. If so, mark the node as `isNodeMatch = true` so search indexing, count, and stepper navigation include it. Ancestor auto-expansion handles keeping the node visible.
- **[Long strings in 1-item lists]** A single-item list with a 200-character string would overflow a badge chip.
  - *Mitigation*: Check character length limits (individual item <= 50 chars, formatted total <= 80 chars). If it exceeds limits, fallback to standard array rendering.
