# Design

## Context

Kafkalyzer's message exploration architecture already includes:
1. `MessagesView` with `ViewModeSwitcher` which supports `'table'`, `'timeline'`, `'diff'`, and `'schema'`. The `'schema'` segment is conditionally rendered if `schemaViewBuilder` is provided.
2. `MessageInspectorPanel`, an embedded split-screen panel (dockable at the bottom or right) that currently renders 3 tabs: `Payload` (using `SmartVirtualJsonTree`), `Key & Headers`, and `Raw JSON`.
3. `SchemaController` (accessible via `getIt<SchemaController>()`) and `SchemaRegistryService`, which fetch subject lists and schema content for `<topic>-key` and `<topic>-value` from Confluent-compatible Schema Registries.
4. `SchemaViewerDialog`, which was historically invoked via `showDialog` from the `TopicDetailView` header, rendering a 90% viewport modal that obscures all topic search, filtering, and stream operations.

This design introduces a first-class, non-blocking schema inspection experience integrated across both the topic explorer view modes and the message inspector panel.

## Goals / Non-Goals

**Goals:**
- Extract schema display and search logic into a reusable widget `TopicSchemaInspectorView`.
- Provide `schemaViewBuilder` in `TopicDetailView` so `MessagesView` displays the `Schema` view mode tab directly in the main view area.
- Route the `TopicDetailView` header `[Schema]` button to switch to the embedded `Schema` view mode instead of displaying a blocking modal dialog.
- Embed a 4th `Schema` tab in `MessageInspectorPanel` allowing side-by-side inspection of live message payloads and schema definitions.
- Provide direct field actions in the schema tree:
  - `📌 Pin as Table Column`: Adds the clean field path directly to projected table columns.
  - `🔍 Filter by this Field`: Fills the topic search bar's `Field (Opt.)` input with the normalized field path.
- Implement robust field path normalization that strips Avro type annotations (e.g. `field : Type` -> `field`) for reliable table column projection and search filtering.
- Provide clear, actionable empty and error states for unconfigured registries or topics without schemas.
- Ensure 100% German and English localization without hardcoded strings.

**Non-Goals:**
- Modifying Rust backend crates or FRB bridge signatures (the existing `SchemaRegistryService` and `SchemaController` provide all needed data).
- Modifying or registering schemas in Schema Registry (read-only inspection).
- Handling non-Avro schema formats like Protobuf or JSON Schema in this phase.

## Decisions

### Decision 1: Reusable Component `TopicSchemaInspectorView`
Instead of duplicating schema viewer logic or keeping it confined to `SchemaViewerDialog`, extract it into:
`lib/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart`.

**Props**:
- `ClusterProfile profile`: The active cluster connection profile.
- `String topicName`: The topic whose schemas to fetch.
- `String? searchPhrase`: Initial search filter query (e.g. from toolbar search).
- `ValueChanged<String>? onPinToColumn`: Callback to pin a field path as a projected table column.
- `ValueChanged<String>? onFilterByField`: Callback to populate the search bar with the field name.
- `bool isEmbedded`: Controls visual padding and header styling depending on whether it is rendered in full view or inside the compact inspector panel.

**Internal Architecture**:
- Loads `<topic>-key` and `<topic>-value` asynchronously using `SchemaController`.
- Simplifies Avro JSON using `_simplifySchema` into structured maps suitable for `JsonOrStringViewer` / `SmartVirtualJsonTree`.
- Embeds search bar with match count badge (`current/total`) and previous/next match stepper navigation.
- Passes `onPinToColumn` and `onFilterByField` to the tree view rows.

### Decision 2: Topic Explorer `MessagesView` Integration
In `TopicDetailView`:
- Provide `schemaViewBuilder: (context, searchPhrase) => TopicSchemaInspectorView(...)` to `MessagesView`.
- Connect `onPinToColumn` to `MessagesView`'s `addProjectedColumn`.
- Connect `onFilterByField` to `_filterFieldController.text = fieldPath`.
- In `_buildSchemaButton`, instead of `showDialog(SchemaViewerDialog)`, notify `MessagesView` to activate the `'schema'` view mode (e.g. via `GlobalKey<MessagesViewState>` or by exposing an `activeView` controller).
- Keep `SchemaViewerDialog` for backward compatibility, internally wrapping `TopicSchemaInspectorView`.

### Decision 3: 4th Tab in `MessageInspectorPanel`
In `MessageInspectorPanel`:
- Increase `DefaultTabController.length` from 3 to 4.
- Add tab 4: `Schema` (`Icons.schema_outlined` / `Icons.data_object`).
- Retrieve `ClusterProfile` from `ActiveConnectionController` or pass down from `MessagesView`.
- Render `TopicSchemaInspectorView` with `isEmbedded: true` and the active message's `topic`.
- Wire `onPinToColumn: widget.onPinToColumn` so users can pin columns directly while inspecting a single message.

### Decision 4: Robust Field Path Normalization
In `SmartVirtualJsonTree` / `TopicSchemaInspectorView`:
- In Avro simplified representation, complex fields are keyed as `"$fieldName : $typeLabel"`.
- Provide a path normalization utility:
  ```dart
  String normalizeSchemaFieldPath(String rawPath) {
    return rawPath
        .split('.')
        .map((segment) {
          final idx = segment.indexOf(':');
          return idx != -1 ? segment.substring(0, idx).trim() : segment.trim();
        })
        .where((s) => s.isNotEmpty && s != 'root')
        .join('.');
  }
  ```
- This ensures projected columns (`order.customer.id`) match standard JSON payload keys exactly.

### Decision 5: Material UI and Localization
- All UI elements use `package:material_ui/material_ui.dart`.
- Strings added to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`:
  - `schemaAction`, `viewModeSchema`, `viewModeSchemaTooltip`
  - `schemaFilterByField`, `schemaFilterByFieldTooltip`, `schemaFilterApplied`
  - `schemaNoRegistryConfigured`, `schemaConfigureRegistryAction`
  - `noAvroSchemaFound`, `keySchemaTitle`, `valueSchemaTitle`

## Risks / Trade-offs

- **Risk**: Topics without schemas or clusters without Schema Registry might show an unhelpful blank view.
  - *Mitigation*: Render clear empty state cards explaining whether Schema Registry is unconfigured (with a button to open cluster settings) or whether no subject exists for this topic, along with an action to switch back to Table or Timeline view.
- **Risk**: Search query conflicts between toolbar search and schema search.
  - *Mitigation*: `TopicSchemaInspectorView` manages its own dedicated search state, optionally seeding from toolbar `searchPhrase` on initial load.
