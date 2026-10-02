# Proposal

## Why

In commit `8b53267`, a global keyboard shortcut handler was introduced via `HardwareKeyboard.instance.addHandler` to ensure message navigation (`J`/`K`/`ArrowUp`/`ArrowDown`) and fullscreen toggle (`F`) remained functional when focus shifted outside the messages subtree (such as to explorer topic tiles or toolbar icon buttons). However, its text-field detection helper (`_isTextInputFocused()`) only checks `context.widget is EditableText`.

In Flutter, a focused `FocusNode`'s context points to the internal `Focus` widget descendant inside `EditableTextState`, meaning `context.widget` is an instance of `Focus`, never `EditableText`. As a consequence, `_isTextInputFocused()` consistently returns `false` whenever any text field is focused. When the message inspector is open, typing the letters `j`, `k`, or `f` into any search or filter input—such as the sidebar topic filter, stream search bar, inspector search bar, or table column filters—is intercepted and swallowed by the global handler, erroneously triggering message stepping or toggling fullscreen Focus Mode.

Now that users cannot enter topic names or search terms containing the characters `j`, `k`, or `f`, this regression must be corrected immediately without compromising keyboard navigation or fullscreen controls.

## What Changes

- **Correct Text Field Focus Detection**: Update `_isTextInputFocused()` to check for `EditableText` ancestor hierarchy (`context.widget is EditableText || context.findAncestorWidgetOfExactType<EditableText>() != null`) so any focused text input (such as `TextField`, `TextFormField`, or raw `EditableText`) is reliably recognized.
- **Audit Application Letter Shortcuts**: Confirm that no other single-letter shortcuts exist across the codebase that could be blocked. (Only `J`, `K`, and `F` are registered as single-key shortcuts; `Ctrl+B`/`Cmd+B` uses modifiers and is unaffected).
- **Maintain Message Navigation & Fullscreen Toggle**: Ensure that when focus is NOT within a text field (e.g. clicking messages, table rows, timeline cards, or non-text controls), `J`, `K`, `ArrowUp`, `ArrowDown`, and `F` continue to step messages and toggle fullscreen mode.
- **Retain Escape Behavior**: Pressing `Escape` while focused in a text field unfocuses the text field and returns focus to shortcut handling; pressing `Escape` when not in a text field exits fullscreen mode or closes the inspector.
- **Comprehensive Widget & Stepper Tests**: Add and update widget tests using hardware key events (`tester.sendKeyEvent`) to verify that typing `j`, `k`, `f` into search fields works without triggering navigation or fullscreen toggle, and that navigation still works when focus is outside text inputs.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `message-inspector-shell`: Strengthen the `Text field isolation` scenario under `Global Keyboard Shortcuts for Stream Inspection` to require that text input fields (including topic filter inputs, message search bars, inspector search bars, and column filter inputs) reliably receive `J`, `K`, and `F` key events without being intercepted by global stream inspection shortcuts.

## Impact

- **Affected Code**: `lib/src/ui/messages/messages_view.dart` (`_isTextInputFocused()`).
- **Tests**: `test/src/ui/messages/messages_view_stepper_test.dart` (strengthening tests with real `KeyDownEvent` / `sendKeyEvent` rather than solely `enterText`).
- **APIs & Dependencies**: No API changes or new dependencies required. Backwards compatibility preserved.
