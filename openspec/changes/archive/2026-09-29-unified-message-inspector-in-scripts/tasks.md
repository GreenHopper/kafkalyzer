## 1. MessagesView Scripting Extensibility

- [x] 1.1 Add `schemaViewBuilder` parameter (`Widget Function(BuildContext context, String searchPhrase)? schemaViewBuilder`) to `MessagesView`, update `_showSchemaView` to evaluate to true when `schemaViewBuilder != null`, and render the custom schema view in `_buildMasterView()` when `_activeView == 'schema'`. Verify with a widget test ensuring a custom schema view is rendered when the schema tab is active.
- [x] 1.2 Support optional `sortComparator` parameter (`int Function(KafkaMessage a, KafkaMessage b)? sortComparator`) in `MessagesView` and update search filtering to include `ScriptResultMessage.stepName` when matching search phrases. Verify with a widget test ensuring step names match search queries and custom comparator ordering is preserved.

## 2. Script Run Details & Header Refactoring

- [x] 2.1 Refactor `ScriptRunHeader` to remove duplicate `ViewModeSwitcher` and `MessageSearchBar`, keeping the header focused on back navigation, run title, timestamp, and timeline grouping mode (`byTopic`, `chronological`, `groupedByStep`). Verify with a widget test that `ScriptRunHeader` renders run context without duplicate search or view mode switchers.
- [x] 2.2 Refactor `ScriptRunDetailsView` to render message results using `MessagesView` with `showTopic: true`, `showStep: true`, `stepExtractions: stepExtractions`, `schemaViewBuilder`, and the active sort comparator, eliminating all manual `showDialog(MessageDetailsDialog)` calls. Verify that tapping a message opens `MessageInspectorPanel` embedded within the script run results.

## 3. Retirement and Removal of MessageDetailsDialog

- [x] 3.1 Update `lib/src/features/consumer/presentation/topic_partition_table.dart` to render `MessageInspectorPanel` inside a dialog when inspecting a lagging message, removing dependency on `MessageDetailsDialog`.
- [x] 3.2 Remove legacy fallback `_showMessageDetails` and import of `MessageDetailsDialog` in `lib/src/ui/messages/views/messages_table_view.dart`.
- [x] 3.3 Delete `lib/src/ui/message_details_dialog.dart` and its test file `test/src/ui/message_details_dialog_test.dart`.
- [x] 3.4 Update consumer lag test (`topic_partition_table_test.dart`) and table test (`kafka_message_table_test.dart`) to verify `MessageInspectorPanel` usage and ensure no leftover imports or references exist.

## 4. Verification & Regression Testing

- [x] 4.1 Create widget tests in `test/src/features/scripting/presentation/widgets/script_run_details_view_test.dart` verifying that tapping a message in script execution results opens the dockable `MessageInspectorPanel` (side or bottom dock) without opening `MessageDetailsDialog`, and that sequential keyboard stepping (`J`/`K`) moves between script messages.
- [x] 4.2 Run `flutter test` and `dart analyze` across the entire project to ensure clean analysis with zero errors and that all tests pass.
