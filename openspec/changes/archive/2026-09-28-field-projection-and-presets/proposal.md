# Proposal: Field Projection & "Add to Columns" (Phase 5)

## Why

In Kafka stream inspection, messages often contain deeply nested, extensive JSON payloads (e.g. logistics orders with nested milestone arrays, vehicle codes, and sub-orders). In the Master Table view (`MessagesTableView`), the `Content` column truncates the raw JSON string to 300 characters, forcing users to click each row and open the Inspector to cross-compare specific attributes across messages.

According to **Phase 5 of the UI Optimization Concept** (`design/kafka_message_ui_optimierungskonzept.md`), users should be able to:
1. Extract any field from JSON payloads into dedicated, dynamic table columns ("Field Projection").
2. Pin any JSON node path directly from the `SmartVirtualJsonTree` into the table with a single action ("Pin as Column" / "Als Spalte anheften").
3. Automatically persist and recall custom column configurations ("Presets") per topic in `SharedPreferences`, so returning to a topic retains the user's projected columns.

This transforms the Master Table from a generic raw payload view into a tailored domain grid while maintaining 60 FPS performance and avoiding unneeded modal round-trips.

## What Changes

1. **Dynamic Field Projection in Table View (`MessagesTableView`)**:
   - Support dynamic column definitions alongside standard columns (Timestamp, Partition, Offset, Key, Content, etc.).
   - Extract projected values efficiently using a robust JSON path evaluator (`JsonPathExtractor` supporting dot-notation and array indices like `leistungen[0].transportId` or `customer.name`).
   - Cache extracted cell values in `_TableRowData` to avoid repeated JSON decoding or string parsing on every viewport frame.
   - Render projected columns with sortable headers, filter dialogs, and a clear affordance to remove the projected column.
   - Format composite objects or badges within table cells if the extracted value is a Map matching `EntityFormatterRegistry`.

2. **One-Click "Pin to Table Column" in `SmartVirtualJsonTree`**:
   - Provide an action button or context menu option on node rows in `SmartVirtualJsonTree` to "Pin as Column" / "Als Spalte anheften".
   - Convert the node's internal hierarchy path into a normalized JSON path (stripping tree root prefixes and formatting compound segments).
   - Bubble the path up via `onPinToColumn` callback through `MessageInspectorPanel` and `MessagesView` to the table configuration.

3. **Per-Topic Column Presets Persistence (`SharedPreferences`)**:
   - Persist the list of active projected column paths per topic in `SharedPreferences` (e.g. `topic_columns_preset_<topicName>`).
   - Automatically restore saved column projections when opening or switching to a topic.
   - Provide a reset or clear option in the table header bar to revert to the default table layout.

4. **Localization & UI Polish**:
   - Add localized strings for "Pin as table column", "Column pinned", "Remove column", "Manage columns", and "Reset to default columns" in English (`app_en.arb`) and German (`app_de.arb`).

## Capabilities

### New Capabilities
<!-- No new standalone capabilities needed; extending existing table columns and smart tree capabilities. -->

### Modified Capabilities
- `message-table-columns`: Extends the table column system with support for user-defined dynamic field projections extracted from JSON payloads and per-topic preset persistence in `SharedPreferences`.
- `smart-virtual-json-tree`: Adds node-level pin action ("Pin to Table Column") that calculates the normalized JSON path and triggers dynamic column projection in the master table view.

## Impact

- **UI Components**:
  - `lib/src/ui/messages/views/messages_table_view.dart`: Extended with dynamic column spans, header cells with remove action, sorting, filtering, and projected value caching.
  - `lib/src/ui/smart_tree/smart_virtual_json_tree.dart`: Added `onPinToColumn` callback and pin-to-column action button/affordance on tree nodes.
  - `lib/src/ui/messages/widgets/message_inspector_panel.dart`: Plumbed `onPinToColumn` from tree to parent.
  - `lib/src/ui/messages/messages_view.dart`: Maintains active projected columns state, orchestrates presets loading/saving, and passes projected columns to `MessagesTableView`.
- **Domain & Utilities**:
  - `lib/src/utils/json_path_extractor.dart`: High-performance utility for extracting values by JSON path (supporting maps, dot notation, and list indices).
- **Localization**:
  - `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`: New localization keys.
- **Tests**:
  - New unit tests for `JsonPathExtractor`.
  - Widget tests for `MessagesTableView` with dynamic projected columns.
  - Widget tests for "Pin as Column" in `SmartVirtualJsonTree` and integration with `MessagesView`.
