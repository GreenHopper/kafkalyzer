# Tasks

## 1. Focus Detection & Shortcut Handling

- [x] 1.1 Update `_isTextInputFocused()` in `lib/src/ui/messages/messages_view.dart` to check `context.widget is EditableText || context.findAncestorWidgetOfExactType<EditableText>() != null` and verify with `dart analyze lib/src/ui/messages/messages_view.dart`.
- [x] 1.2 Verify that `_handleInspectorShortcut` permits `LogicalKeyboardKey.keyJ`, `LogicalKeyboardKey.keyK`, and `LogicalKeyboardKey.keyF` to bypass the shortcut handler when `_isTextInputFocused()` returns true.
- [x] 1.3 Verify that `LogicalKeyboardKey.escape` unfocuses the active text input when focused, and only minimizes or closes the inspector when no text input has focus.

## 2. Stepper & Search Field Tests

- [x] 2.1 Update `test/src/ui/messages/messages_view_stepper_test.dart` to dispatch real hardware key events (`tester.sendKeyEvent` for `keyJ`, `keyK`, `keyF`) while `MessageSearchBar` is focused, asserting that message selection does not change and Focus Mode does not toggle.
- [x] 2.2 Add a widget test in `test/src/ui/messages/messages_view_stepper_test.dart` with an external `TextField` (simulating the sidebar topic filter in `ExplorerView`) with the inspector open, verifying that pressing `J`, `K`, or `F` does not trigger navigation or fullscreen toggle.
- [x] 2.3 Verify that `ArrowDown` and `ArrowUp` still step messages when a search field is focused, and that `Escape` unfocuses the search field without dismissing the inspector.
- [x] 2.4 Run `flutter test test/src/ui/messages/messages_view_stepper_test.dart` and confirm all stepper and shortcut tests pass.
