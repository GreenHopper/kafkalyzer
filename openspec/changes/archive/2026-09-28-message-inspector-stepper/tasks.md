## 1. Localization

- [x] 1.1 Add translation keys to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`:
  - Stepper: `previousMessageTooltip` ("Previous message (K)"), `nextMessageTooltip` ("Next message (J)"), `messagePosition` ("{current} of {total}")
  - Focus Mode: `focusMode` ("Maximize (Focus Mode)"), `exitFocusMode` ("Minimize (Esc)")
  - In-Inspector Search: `searchInMessage` ("Search in message..."), `nextMatchTooltip` ("Next match (Enter)"), `previousMatchTooltip` ("Previous match (Shift+Enter)"), `matchesCount` ("{current} of {total}"), `noMatches` ("No matches")
- [x] 1.2 Run `flutter gen-l10n` and verify generated getters in `AppLocalizations`.

## 2. MessagesView State & Maximize Logic

- [x] 2.1 Add `bool _isMaximized = false` to `_MessagesViewState` in `lib/src/ui/messages/messages_view.dart`.
- [x] 2.2 Implement index lookup and stepping methods:
  - `int get _selectedIndex`: index of `_selectedMessage` in `_cachedSortedMessages`.
  - `void _stepPrevious()`: select message at `_selectedIndex - 1` if `_selectedIndex > 0`.
  - `void _stepNext()`: select message at `_selectedIndex + 1` if `_selectedIndex < _cachedSortedMessages.length - 1`.
  - `void _toggleMaximize()`: toggle `_isMaximized = !_isMaximized`.
- [x] 2.3 Update `_buildContent()` in `MessagesView`:
  - When `_isInspectorOpen && _isMaximized`: render `MessageInspectorPanel` taking 100% of the available space.
  - When `_isInspectorOpen && !_isMaximized`: render the existing bottom (`Column`) or side (`Row`) split.
  - Pass stepper callbacks and positional parameters (`messageIndex`, `totalMessages`, `onPreviousMessage`, `onNextMessage`, `isMaximized`, `onToggleMaximize`) to `MessageInspectorPanel`.

## 3. Keyboard Shortcuts

- [x] 3.1 Wrap `MessagesView` content in a `CallbackShortcuts` and `Focus` widget.
- [x] 3.2 Wire single-key and modifier actions:
  - `LogicalKeyboardKey.keyJ` and `LogicalKeyboardKey.arrowDown`: trigger `_stepNext()`.
  - `LogicalKeyboardKey.keyK` and `LogicalKeyboardKey.arrowUp`: trigger `_stepPrevious()`.
  - `LogicalKeyboardKey.escape`: if `_isMaximized`, exit maximize; else close inspector.
  - `LogicalKeyboardKey.keyF`: toggle maximize.
- [x] 3.3 Implement text-entry guard (`_isTextInputFocused()`):
  - Ensure single-key shortcuts (`J`, `K`, `F`) are suppressed when an `EditableText` or `TextField` is focused.

## 4. MessageInspectorPanel Stepper & Header Controls

- [x] 4.1 Update `MessageInspectorPanel` constructor in `lib/src/ui/messages/widgets/message_inspector_panel.dart` to accept:
  - `final int? messageIndex;`
  - `final int? totalMessages;`
  - `final VoidCallback? onPreviousMessage;`
  - `final VoidCallback? onNextMessage;`
  - `final bool isMaximized;`
  - `final VoidCallback? onToggleMaximize;`
- [x] 4.2 In `_buildHeader()`, add the Stepper controls:
  - Previous message button (`Icons.chevron_left`) with tooltip and disabled state when `messageIndex == 0`.
  - Counter text `${messageIndex + 1} / ${totalMessages}`.
  - Next message button (`Icons.chevron_right`) with tooltip and disabled state when `messageIndex == totalMessages - 1`.
- [x] 4.3 In `_buildHeader()`, add the Maximize / Minimize button:
  - `isMaximized ? Icons.fullscreen_exit : Icons.fullscreen` with appropriate tooltips.

## 5. In-Inspector Value Search

- [x] 5.1 Add in-inspector search state to `_MessageInspectorPanelState`:
  - `bool _isSearchOpen = false;`
  - `final TextEditingController _searchController = TextEditingController();`
  - `int _totalMatches = 0;`
  - `int _currentMatchIndex = 0;`
  - `final GlobalKey<JsonOrStringViewerState> _payloadViewerKey = GlobalKey();`
- [x] 5.2 Add search toggle button (`Icons.search`) to `_buildHeader()` and support `Ctrl+F` shortcut.
- [x] 5.3 Render an inline expandable search bar:
  - `TextField` with search icon, clear button, and hint text.
  - Match count indicator `${_currentMatchIndex + 1} / $_totalMatches`.
  - Up/Down navigation buttons calling `_payloadViewerKey.currentState?.jumpToMatch(...)`.
  - Support `Enter` (next match) and `Shift+Enter` (previous match).
- [x] 5.4 Wire `JsonOrStringViewer` in Tab 1 with `key: _payloadViewerKey` and `onMatchCountChanged`.

## 6. Verification and Automated Tests

- [x] 6.1 Add widget tests in `test/src/ui/messages/messages_view_stepper_test.dart`:
  - Verify stepper buttons switch selected message and update table row highlight.
  - Verify boundary disablement for first and last messages.
  - Verify keyboard shortcuts `J` and `K` step to next and previous messages.
  - Verify `Escape` exits maximized mode and closes inspector.
  - Verify text field typing does not trigger `J`/`K` navigation.
- [x] 6.2 Add widget tests in `test/src/ui/messages/widgets/message_inspector_panel_search_test.dart`:
  - Verify in-inspector search highlights matches and updates counter.
  - Verify next/previous match navigation jumps through matches.
- [x] 6.3 Run `dart analyze` to ensure 0 lint or static analysis issues.
- [x] 6.4 Run `flutter test test/src/ui/messages/` to ensure 100% test passage.
