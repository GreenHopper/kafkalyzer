# Technical Design: Field Projection & "Add to Columns" (Phase 5)

## Context

See `proposal.md` for motivation and background.

In the current Kafkalyzer architecture:
- `MessagesView` manages master stream presentations (`MessagesTableView`, `MessagesTimelineView`, `MessagesDiffView`) and the side/bottom inspector panel (`MessageInspectorPanel`).
- `MessagesTableView` utilizes `package:two_dimensional_scrollables` (`TableView.builder`) with fixed row heights and `TableSpan` column specifications. It currently features a hardcoded set of 5 to 7 columns (`Timestamp`, `Step`, `Topic`, `Partition`, `Offset`, `Key`, `Content`).
- `SmartVirtualJsonTree` inside `MessageInspectorPanel` renders a flattened linear list of nodes (`VirtualJsonNode`) with known hierarchical paths (`root.key.nested`).
- User settings, view modes, and dock positions are persisted in `SharedPreferences`.

## Goals / Non-Goals

**Goals:**
- Provide dynamic, user-defined column projections in `MessagesTableView` extracted from JSON payloads.
- Implement high-performance path extraction (`JsonPathExtractor`) supporting dot-notation (`customer.name`) and list bracket indices (`items[0].id`).
- Pre-extract and cache projected cell values in `_TableRowData` to ensure smooth 60 FPS scrolling without repeated JSON parsing in `cellBuilder`.
- Support full table capabilities on projected columns: sort ascending/descending, filter dialogs with text matching, and one-click removal.
- Add an intuitive "Pin as Table Column" affordance on node rows in `SmartVirtualJsonTree`, bubbling the normalized JSON path up to `MessagesView`.
- Persist and restore projected column configurations per topic in `SharedPreferences`.
- Provide a clear/reset action in the table to easily return to default columns.

**Non-Goals:**
- Supporting complex filter predicates (e.g. `$.items[?(@.type == 'A')]`) — simple structural dot and array index paths (`a.b[0].c`) satisfy field projection requirements.
- Modifying payload data on Kafka brokers (read-only projection).
- Altering the non-table master views (Timeline/Diff) to render multi-column grids.

## Decisions

### 1. High-Performance Path Extraction & Row Caching

**Decision:** Create a dedicated `JsonPathExtractor` utility and cache extracted values inside `_TableRowData`.
- `JsonPathExtractor.extractFromPayload(String? payload, String path)`: Parses JSON (handling null, strings, maps, and lists) and traverses tokens.
  - Supports tokens split by `.` and array index brackets `[index]`. For example: `customer.address.city` and `leistungen[0].transportId`.
- In `_filterAndSortMessages` of `MessagesTableView`:
  - Each `_TableRowData` includes `Map<String, String> projectedValues`.
  - Values are extracted once when messages or projected columns change.
  - Cell builders simply perform an $O(1)$ lookup `data.projectedValues[columnPath]`.
- **Alternatives considered:**
  - *Dynamic extraction in `cellBuilder`*: Rejected because decoding JSON or re-traversing maps on every frame during fast scrolling would cause frame drops.
  - *Full isolate pre-processing*: Excessive complexity for extracting 1 to 5 primitive string/number values from already fetched messages.

### 2. Projected Column Configuration Model

**Decision:** Model projected columns with a lightweight immutable class:
```dart
class ProjectedColumn {
  final String path;
  final String label;

  const ProjectedColumn({required this.path, required this.label});

  Map<String, dynamic> toJson() => {'path': path, 'label': label};
  factory ProjectedColumn.fromJson(Map<String, dynamic> json) =>
      ProjectedColumn(path: json['path'] as String, label: json['label'] as String);
}
```
- By default, `label` is the leaf property name (e.g. `customer.id` -> `id` or `customer.id`), with the full path displayed in header tooltips.

### 3. Table Column Layout & Visual Ordering

**Decision:** Place dynamic projected columns after `Key` and before `Content` (or at the end of the table).
- Visual column order:
  `[Timestamp] [Step?] [Topic?] [Partition] [Offset] [Key] ... [Projected Columns] ... [Content]`
- Each projected column header displays:
  - Column title (field name).
  - Sort direction indicator when active.
  - Filter icon button with active filter badge.
  - Close (`x`) icon button to remove the projected column.
- Fixed extent for projected columns: default width of 140–180 px.

### 4. "Pin to Table Column" Workflow in Virtual Tree

**Decision:** Add a pin action button to `VirtualJsonNode` rows in `SmartVirtualJsonTree`.
- Next to the existing "Copy value" icon button, add a "Pin to Table Column" (`Icons.view_column_outlined` or `Icons.push_pin_outlined`) button.
- When clicked:
  1. The node's path is normalized: `root.` prefix is removed (e.g. `root.leistungen[0].transportId` -> `leistungen[0].transportId`).
  2. `widget.onPinToColumn?.call(normalizedPath)` is invoked.
  3. The callback is forwarded through `MessageInspectorPanel` to `MessagesView`.
  4. `MessagesView` updates its `List<ProjectedColumn>`, persists the update to `SharedPreferences`, and shows a SnackBar (`"Column '<path>' pinned to table"`).

### 5. Preset Persistence per Topic in SharedPreferences

**Decision:** Key storage by topic name: `topic_columns_preset_<topicName>`.
- Format: JSON-encoded list of `ProjectedColumn` objects (or simple list of path strings).
- When a topic is loaded or changed in `MessagesView`, `SharedPreferences` is queried. If a preset exists, it is restored into the active state.
- In `MessagesView`, a "Reset columns" option allows clearing custom columns and removing the preset.

## Risks / Trade-offs

- **[Risk] High memory footprint with many projected columns across large message lists**
  → *Mitigation*: Projected values are stored as lightweight strings; users typically project 1 to 5 fields. If memory pressure arises, rows only cache paths present in the active configuration.
- **[Risk] Path extraction failures on heterogenous payloads**
  → *Mitigation*: `JsonPathExtractor` is resilient against nulls, missing keys, array index out of bounds, and invalid JSON; returning an empty string or `"-"` gracefully without throwing exceptions.
- **[Risk] Column width overflow with many projected columns**
  → *Mitigation*: `TableView.builder` natively supports horizontal scrolling (`DiagonalDragBehavior.free`), ensuring any number of projected columns can be smoothly scrolled.
