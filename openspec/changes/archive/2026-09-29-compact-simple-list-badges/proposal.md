## Why

In `SmartVirtualJsonTree`, JSON lists containing a small number of primitive values (e.g. `1` to `3` simple strings, numbers, or booleans such as `aktionsKategorien: ["ENTLADESTELLE"]`) are currently rendered as expandable array containers showing `[ 1 item ]`. Because they expand into child rows (`[0]: "ENTLADESTELLE"`), inspecting messages requires extra vertical space and clicking, or consumes multiple rows when auto-expanded.

This change introduces compact list badge formatting for lists containing 1 to 3 simple primitive elements, displaying them as inline compact badges (e.g. displaying `["ENTLADESTELLE"]` or `[ "A", "B" ]`) when collapsed, with hover/click popover inspection, while retaining the ability to expand into standard index rows if desired or when auto-expansion rules apply.

## What Changes

- **Compact Primitive List Heuristic in `EntityFormatterRegistry`**:
  - Add `tryFormatList(List<dynamic> list)` to evaluate if a list contains 1–3 primitive non-empty items (strings, numbers, booleans) with a total combined formatted length <= 80 characters.
  - Return `FormattedBadgeData` with a list/collection icon (`Icons.view_list_outlined` or `Icons.list_alt`), formatted summary string (e.g., `["ENTLADESTELLE"]` or `["A", "B"]`), and accent styling.
- **Tree Flattener Integration (`JsonTreeFlattener`)**:
  - In `JsonTreeFlattener.traverse()` for `List` nodes, evaluate `EntityFormatterRegistry.tryFormatList()` when the list is collapsed.
  - When matched, emit a `VirtualJsonNode` of type `JsonNodeType.compositeBadge` (or array with `badgeData`) containing the formatted badge data and list value, enabling inline summary badges on one row.
- **Badge & Popover Support for List Data (`SmartCompositeBadge` / `SmartVirtualJsonTree`)**:
  - Ensure `SmartCompositeBadge` gracefully renders and details list items in its hover/click popover when `data` is a `List` (e.g. index-value rows `[0]: ENTLADESTELLE` with copy support).
- **Search Matching**:
  - Ensure search queries match against the formatted badge label of compact lists so matching arrays remain visible and highlighted.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `smart-virtual-json-tree`: Add requirements and scenarios for recognizing and rendering compact primitive lists (1 to 3 simple values) as composite badges in progressive disclosure.

## Impact

- **UI Code**:
  - `lib/src/ui/smart_tree/entity_formatter_registry.dart`
  - `lib/src/ui/smart_tree/json_tree_flattener.dart`
  - `lib/src/ui/smart_tree/smart_composite_badge.dart`
  - `lib/src/ui/smart_tree/smart_virtual_json_tree.dart`
- **Tests**:
  - `test/src/ui/smart_tree/entity_formatter_registry_test.dart`
  - `test/src/ui/smart_tree/json_tree_flattener_test.dart`
  - `test/src/ui/smart_tree/smart_virtual_json_tree_test.dart`
