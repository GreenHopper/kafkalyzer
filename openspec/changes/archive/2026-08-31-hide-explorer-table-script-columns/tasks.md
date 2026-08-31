## 1. MessagesView column flags

- [x] 1.1 Add `showTopic` and `showStep` parameters to `MessagesView` (default `false`) and forward them to `MessagesTableView` instead of hardcoding `true`; verify explorer table headers omit Step and Topic
- [x] 1.2 Confirm `script_run_details_view.dart` still passes `showTopic: true` and `showStep: true` to `MessagesTableView`; verify script table headers still include Step and Topic

## 2. Tests

- [x] 2.1 Extend `test/src/ui/messages/messages_view_test.dart` (and/or table tests) so the default `MessagesView` table does not show Step/Topic column headers, and verify with `flutter test test/src/ui/messages/ test/src/ui/kafka_message_table_test.dart`
