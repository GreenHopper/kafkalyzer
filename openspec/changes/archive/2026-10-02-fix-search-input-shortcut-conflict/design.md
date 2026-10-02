# Design

## Context

In commit `8b53267`, `MessagesView` switched from a subtree-scoped `CallbackShortcuts` widget to a global `HardwareKeyboard.instance.addHandler(_handleInspectorShortcut)` to keep navigation shortcuts (`J`/`K`/`ArrowUp`/`ArrowDown`) and fullscreen toggle (`F`) responsive when focus leaves the message list (e.g., clicking topic list items in `ExplorerView` or search chrome buttons).

However, `_isTextInputFocused()` checked `context.widget is EditableText`. In Flutter, the `FocusNode`'s `BuildContext` points to the internal `Focus` widget inside `_EditableTextState`, meaning `context.widget` is `Focus`, never `EditableText`. As a result, `_isTextInputFocused()` always returned `false`, and typing `j`, `k`, or `f` in any text input field while the inspector was open was intercepted and swallowed by the handler.

See `proposal.md` for problem background and scope.

## Goals / Non-Goals

**Goals:**
- Enable seamless typing of `j`, `k`, `f` (and uppercase `J`, `K`, `F`) in all search and text input fields (topic filter in `ExplorerView`, message search bar, inspector search bar, column filters, etc.) without triggering message navigation or fullscreen toggle.
- Maintain message stepping (`J`/`K`/`ArrowDown`/`ArrowUp`) and fullscreen toggle (`F`) when the message inspector is open and no text input field has focus.
- Preserve message stepping via `ArrowDown`/`ArrowUp` while a single-line search input has focus (to avoid trapping users in search chrome).
- Ensure `Escape` pressed within a text field unfocuses the input, restoring shortcut focus without closing the inspector or exiting Focus Mode on that press.
- Prevent regressions by testing real hardware keyboard events (`tester.sendKeyEvent`).

**Non-Goals:**
- Redesigning the message inspector layout or navigation controls.
- Modifying non-inspector shortcuts (e.g., `Ctrl+B`/`Cmd+B` for sidebar toggle).
- Adding new keyboard shortcuts or changing key bindings.

## Decisions

### Decision 1: Text Field Ancestry Check for `_isTextInputFocused`

**Choice**: Update `_isTextInputFocused()` to check:
```dart
bool _isTextInputFocused() {
  final primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus == null) return false;
  final context = primaryFocus.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}
```

**Rationale**:
- In Flutter's widget architecture, `EditableTextState` builds a subtree containing `Focus(focusNode: widget.focusNode, ...)`. `findAncestorWidgetOfExactType<EditableText>()` walks up the element chain to locate the enclosing `EditableText` widget.
- The depth between the `Focus` node and `EditableText` is only 1-2 hops, so lookup overhead is negligible ($O(1)$).
- Because `TextField`, `TextFormField`, and `CupertinoTextField` all wrap `EditableText`, this single check universally detects all standard Flutter text input widgets across both debug and release builds.

**Alternatives considered**:
- `focusNode.debugLabel == 'EditableText'`: Rejected because `debugLabel` is null in Flutter release builds (`kReleaseMode ? null : 'EditableText'`).
- Manual focus state propagation via callbacks or inherited widgets: Rejected as over-engineered, requiring state passing across independent controllers and views (e.g. `ExplorerView` vs `MessagesView`).
- `context.findAncestorStateOfType<EditableTextState>() != null`: Equivalent in behavior, but checking the widget type directly is standard Flutter practice.

### Decision 2: Codebase Audit for Blocked Key Shortcuts

**Finding**:
- An exhaustive audit of `LogicalKeyboardKey` and shortcut registrations across `lib/src/` confirmed:
  - `MessagesView`: `keyJ`, `keyK`, `keyF`, `escape`, `arrowDown`, `arrowUp`.
  - `ExplorerView`: `keyB` with `control: true` / `meta: true` (scoped via `CallbackShortcuts`).
  - `ScriptManagerView`: `keyB` with `control: true` / `meta: true` (scoped via `CallbackShortcuts`).
  - `MessageInspectorPanel`: `enter`, `shift+enter`, `escape` (scoped via `CallbackShortcuts`).
- Only `J`, `K`, and `F` were configured as un-modified single-letter shortcuts in a global handler. No other letter in the alphabet is intercepted or blocked.

### Decision 3: Testing with `tester.sendKeyEvent`

**Choice**: Enhance tests in `test/src/ui/messages/messages_view_stepper_test.dart` to dispatch hardware keyboard events using `tester.sendKeyEvent(LogicalKeyboardKey.keyJ)`, `keyK`, and `keyF` after focusing `TextField`s.

**Rationale**:
- The previous test relied on `tester.enterText(searchField, 'jkf')`, which directly invoked `TextInputClient.updateEditingValue` and bypassed Flutter's `HardwareKeyboard` pipeline entirely.
- Simulating key events via `tester.sendKeyEvent` faithfully reproduces physical keyboard typing on desktop platforms and guarantees the global handler does not swallow the events.

## Risks / Trade-offs

- **[Risk]** `findAncestorWidgetOfExactType` called on every key event.
  - *Mitigation*: The check only runs when `_shouldHandleInspectorShortcuts()` is true and key is `Down` or `Repeat`. The element tree traversal from `Focus` to `EditableText` is 1-2 levels deep, taking microseconds.
- **[Risk]** Arrow keys (`ArrowUp`/`ArrowDown`) still step messages when typing in text fields.
  - *Mitigation*: This is the intended and documented design from the previous change: single-line search fields do not use vertical caret movement, while horizontal caret movement (`ArrowLeft`/`ArrowRight`) is untouched. If multiline editing is needed in a future dialog, the modal route check already disables inspector shortcuts.
