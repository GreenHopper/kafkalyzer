# Proposal

## Why

In Kafka workflows, inspecting message structures and comparing live payloads against schema definitions is a daily developer task. In Kafkalyzer, however, the Avro schema viewer was implemented as a blocking, 90%-viewport modal dialog (`SchemaViewerDialog`) triggered by an action button in the topic header:
1. **Context Obscuration & Disruption**: The 90% modal dialog completely obscures the topic search configuration, filters, and message stream/table. Developers cannot consult schema field names and types while typing search criteria or comparing live payloads.
2. **Space Inefficiency**: For typical Avro schemas (5–15 fields), the 90% full-screen modal consists of over 80% empty whitespace.
3. **Disjointed Column Projection & Filtering**: To pin table columns or filter by specific nested fields, developers must either wait for a message to arrive and parse it in the inspector tree or manually retype path names into the search configuration, missing an immediate click-to-action directly from the registered schema.
4. **Lack of In-Inspector Schema Access**: When analyzing an individual message in `MessageInspectorPanel` (docked bottom or right), there is no schema tab, forcing users to close their inspection context or trigger a modal dialog to verify schema definitions.

Embedding the schema viewer directly into the non-blocking views—both as a dedicated "Schema" view mode tab in `MessagesView` / `TopicDetailView` and as a 4th tab in `MessageInspectorPanel`—with direct field actions ("Click-to-Filter" and "Pin-as-Column") resolves these ergonomic bottlenecks and provides a seamless, unified exploration workflow.

## What Changes

- **Dedicated Schema View Mode in Topic Explorer**:
  - Supply a `schemaViewBuilder` to `MessagesView` in `TopicDetailView`, enabling the `Schema` view mode in `ViewModeSwitcher` (`Table | Timeline | Diff | Schema`).
  - Clicking the header `[Schema]` button switches the active view mode to `Schema` without opening a blocking modal dialog.
  - Retain `SchemaViewerDialog` as a non-breaking fallback or for standalone contexts, refactored to share the underlying schema inspector widget.
- **Embedded Schema Tab in Message Inspector**:
  - Add a 4th tab (`Schema`) to `MessageInspectorPanel` alongside `Payload`, `Key & Headers`, and `Raw JSON`.
  - When inspecting a message, developers can inspect the Key and Value Avro schema for that message's topic side-by-side with live message fields.
- **Interactive Schema Field Actions**:
  - Each field in the schema tree hierarchy provides two one-click actions:
    1. `📌 Pin as Table Column` (`Als Tabellenspalte anheften`): Adds the clean, normalized schema field path directly to projected table columns in `MessagesTableView`, even before any messages have been consumed.
    2. `🔍 Filter by this Field` (`Nach diesem Feld filtern`): Populates the topic search bar's `Field (Opt.)` input with the normalized field path for instant search targeting.
- **Clean Field Path Resolution**:
  - Provide a schema path normalizer that strips type annotation suffixes (e.g. `fieldName : String` -> `fieldName`) and formats compound nested paths (e.g. `customer.address.city`) for both table projection and search filtering.
- **Informative Empty and Error States**:
  - Clear, user-friendly empty states for when no Schema Registry is configured on the cluster or when no Avro schema is registered for the topic (`<topic>-key` / `<topic>-value`).
  - Actionable feedback and retry affordances upon registry connection errors.
- **Complete Internationalization (i18n)**:
  - Add localized German (`app_de.arb`) and English (`app_en.arb`) translations for all newly introduced tabs, buttons, empty states, tooltips, and feedback messages.

## Capabilities

### New Capabilities
- `integrated-schema-inspector`: Dedicated non-blocking schema inspection in `TopicDetailView` and `MessagesView` with in-tree search, Key and Value schema sections, and interactive schema field actions (`Pin as Column` and `Filter by Field`).

### Modified Capabilities
- `message-inspector-shell`: Extend `Structured Multi-Tab Inspection` to support an embedded 4th `Schema` tab in `MessageInspectorPanel`, enabling side-by-side inspection of live message payload and topic schema definitions.

## Impact

- **Flutter UI Components**:
  - `lib/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart`: New reusable widget presenting Key and Value schemas, search bar with match count / navigation stepper, field actions, and graceful empty/error states.
  - `lib/src/features/topic/topic_detail_view.dart`: Integrate `schemaViewBuilder` into `MessagesView`, update header schema button to activate the embedded schema view mode, and wire `onFilterByField` to `_filterFieldController`.
  - `lib/src/ui/messages/messages_view.dart`: Expose column pinning callback to `schemaViewBuilder` and propagate schema tab activation.
  - `lib/src/ui/messages/widgets/message_inspector_panel.dart`: Add 4th `Schema` tab rendering `TopicSchemaInspectorView` for the active message's topic.
  - `lib/src/features/schema/presentation/widgets/schema_viewer_dialog.dart`: Refactor to use the shared `TopicSchemaInspectorView` as its content.
- **Localization**:
  - Update `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` with all new schema inspector strings.
- **Rust/Backend**:
  - No changes required. Leverages existing `SchemaController` and `SchemaRegistryService` APIs.
