# Tasks

## 1. Localization & String Assets

- [x] 1.1 Add schema inspector localization keys to `lib/l10n/app_en.arb` (tab labels, action tooltips, empty states, error messages, and feedback toasts).
- [x] 1.2 Add German translations for all schema inspector keys to `lib/l10n/app_de.arb`.
- [x] 1.3 Verify localization generation and ensure all strings compile cleanly.

## 2. Field Path Normalization & Schema Utilities

- [x] 2.1 Implement `normalizeSchemaFieldPath` utility function to clean Avro type annotations and format dot-separated JSON paths for table projection and search filtering.
- [x] 2.2 Add unit tests in `test/` verifying path normalization across primitive fields, complex records with `: Type` annotations, arrays, and unions.

## 3. Reusable `TopicSchemaInspectorView` Component

- [x] 3.1 Create `lib/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart` accepting `profile`, `topicName`, `searchPhrase`, `onPinToColumn`, `onFilterByField`, and `isEmbedded`.
- [x] 3.2 Implement schema loading and error handling for `<topic>-key` and `<topic>-value` using `SchemaController`.
- [x] 3.3 Implement in-schema search with match count indicator (`current/total`) and previous/next navigation stepper.
- [x] 3.4 Implement field action buttons (`📌 Pin as Table Column` and `🔍 Filter by Field`) on tree rows.
- [x] 3.5 Implement informative empty states for unconfigured Schema Registry and missing topic schemas.
- [x] 3.6 Refactor `SchemaViewerDialog` to delegate rendering to `TopicSchemaInspectorView`.

## 4. Topic Explorer (`TopicDetailView` & `MessagesView`) Integration

- [x] 4.1 Provide `schemaViewBuilder` to `MessagesView` in `TopicDetailView` to activate the `Schema` view mode in `ViewModeSwitcher`.
- [x] 4.2 Connect `onFilterByField` to populate `TopicSearchBar`'s `_filterFieldController`.
- [x] 4.3 Connect `onPinToColumn` to `addProjectedColumn` in `MessagesView`.
- [x] 4.4 Update the `TopicDetailView` header `[Schema]` button to switch `MessagesView` to `Schema` view mode without opening a modal dialog.

## 5. `MessageInspectorPanel` Schema Tab Integration

- [x] 5.1 Update `MessageInspectorPanel` to support 4 tabs (`Payload`, `Key & Headers`, `Raw JSON`, `Schema`).
- [x] 5.2 Render embedded `TopicSchemaInspectorView` inside the `Schema` tab for the selected message's topic.
- [x] 5.3 Wire field pinning action in the inspector tab to `widget.onPinToColumn`.

## 6. Verification & Quality Gates

- [x] 6.1 Run unit and widget tests with `flutter test`.
- [x] 6.2 Format Dart code strictly using `dart format`.
- [x] 6.3 Validate the OpenSpec change using `openspec validate --type change integrated-schema-inspector`.
