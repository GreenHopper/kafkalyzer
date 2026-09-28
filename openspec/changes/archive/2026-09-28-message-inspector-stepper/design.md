# Architectural Design: Phase 2 Keyboard Navigation, Streaming Stepper & In-Inspector Search

## 1. Overview & Context

Phase 1 established the non-modal, split-screen inspector shell in `MessagesView` with bottom and side docking, full metadata display, and default tree view.

Phase 2 builds upon this foundation to introduce:
1. **Streaming Message Stepper**: Instant previous/next message switching directly in the inspector header.
2. **Keyboard Ergonomics**: `J`/`K`, `ArrowUp`/`ArrowDown`, `Esc`, `F`, and `Ctrl+F` accelerators.
3. **Maximized Focus Mode**: 100% viewport mode with persistent stepper navigation for laptop displays.
4. **In-Inspector Search**: Payload/Key value search with match counter and next/previous jumping (`jumpToMatch`).

All UI components adhere strictly to `package:material_ui/material_ui.dart` and design token conventions.

---

## 2. Layout & Mode States in `MessagesView`

### 2.1 State Model

In `_MessagesViewState`, we expand the state:
```dart
bool _isInspectorOpen = false;
bool _isMaximized = false;
KafkaMessage? _selectedMessage;
InspectorDockPosition _dockPosition = InspectorDockPosition.bottom;
```

### 2.2 Viewport Resolution

The layout branches into three distinct configurations in `_buildContent()`:
1. **Inspector Closed** (`!_isInspectorOpen || _selectedMessage == null`):
   - The master view (`MessagesTableView`, `MessagesTimelineView`, or `MessagesDiffView`) occupies 100% width and height.
2. **Maximized Focus Mode** (`_isInspectorOpen && _isMaximized`):
   - `MessageInspectorPanel` occupies 100% width and height.
   - Master view is detached from the render tree, giving maximum screen real estate to deep JSON trees on laptop displays.
   - Header retains the Stepper toolbar and shows `Icons.fullscreen_exit` ("Minimize") and `Esc` affordance.
3. **Standard Split Mode** (`_isInspectorOpen && !_isMaximized`):
   - Bottom Dock: `Column` with Master View (flex 3) + Divider + Inspector (flex 2).
   - Side Dock: `Row` with Master View (flex 3) + VerticalDivider + Inspector (flex 2).

---

## 3. Sequential Stepper Architecture

### 3.1 Index Resolution

`MessagesView` already maintains `_cachedSortedMessages`, which is the authoritative list of filtered and sorted messages currently visible to the user:
```dart
int get _selectedIndex {
  if (_selectedMessage == null) return -1;
  return _cachedSortedMessages.indexOf(_selectedMessage!);
}

bool get _hasPrevious => _selectedIndex > 0;
bool get _hasNext => _selectedIndex >= 0 && _selectedIndex < _cachedSortedMessages.length - 1;

void _stepPrevious() {
  if (!_hasPrevious) return;
  _handleMessageTap(_cachedSortedMessages[_selectedIndex - 1]);
}

void _stepNext() {
  if (!_hasNext) return;
  _handleMessageTap(_cachedSortedMessages[_selectedIndex + 1]);
}
```

### 3.2 Stepper Parameters in `MessageInspectorPanel`

`MessageInspectorPanel` receives positional context:
```dart
final int? messageIndex; // 0-based
final int? totalMessages;
final VoidCallback? onPreviousMessage;
final VoidCallback? onNextMessage;
final bool isMaximized;
final VoidCallback? onToggleMaximize;
```

In `_buildHeader()`, a compact stepper widget is rendered:
```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(
      icon: const Icon(Icons.chevron_left, size: 18),
      tooltip: l10n.previousMessageTooltip, // "Previous message (K)"
      onPressed: widget.onPreviousMessage,
      visualDensity: VisualDensity.compact,
    ),
    Text(
      '${(widget.messageIndex ?? 0) + 1} / ${widget.totalMessages ?? 0}',
      style: AppFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold),
    ),
    IconButton(
      icon: const Icon(Icons.chevron_right, size: 18),
      tooltip: l10n.nextMessageTooltip, // "Next message (J)"
      onPressed: widget.onNextMessage,
      visualDensity: VisualDensity.compact,
    ),
  ],
)
```

---

## 4. Keyboard Shortcuts Architecture

### 4.1 Shortcut Definitions

Shortcuts are handled via `CallbackShortcuts` and a root `FocusScope`:
- `LogicalKeyboardKey.keyJ` / `LogicalKeyboardKey.arrowDown`: Step next.
- `LogicalKeyboardKey.keyK` / `LogicalKeyboardKey.arrowUp`: Step previous.
- `LogicalKeyboardKey.escape`: If maximized, exit maximize. Else if open, close inspector.
- `LogicalKeyboardKey.keyF`: Toggle maximize (Focus Mode).
- `LogicalKeyboardKey.keyF` (with `Control` or `Meta`): Open & focus in-inspector search.

### 4.2 Focus & Text-Input Isolation

To prevent single-key shortcuts (`J`, `K`, `F`) from interfering with text entry when a user types in the stream search bar or in-inspector search bar:
- A helper check `_isTextInputFocused()` inspects `FocusManager.instance.primaryFocus?.context?.widget`.
- If an `EditableText` or `TextField` is focused, single-key shortcuts are ignored and delegated to text entry.
- `Escape` in a text field unfocuses the text field first before closing the inspector.

---

## 5. In-Inspector Value Search & Match Jumping

### 5.1 Search Bar Component

Inside `MessageInspectorPanel`:
- An in-inspector search state: `bool _isSearchOpen = false`, `String _inspectorSearchQuery = ''`.
- An inline search bar expandable from the header via `IconButton(icon: Icon(Icons.search))` or `Ctrl+F`:
  - `TextField` with `hintText: l10n.searchInMessage`.
  - Match count indicator: `${_currentMatchIndex + 1} / $_totalMatches`.
  - Next match button (`Icons.keyboard_arrow_down`) & `Enter`.
  - Previous match button (`Icons.keyboard_arrow_up`) & `Shift+Enter`.
  - Close search button (`Icons.close`).

### 5.2 Connecting to `JsonOrStringViewer`

`JsonOrStringViewer` already supports `jumpToMatch(int index)` and `onMatchCountChanged(int count)`.
- We assign a `GlobalKey<JsonOrStringViewerState>` to the payload viewer in Tab 1.
- `onMatchCountChanged` updates `_totalMatches` in `MessageInspectorPanel`.
- Navigating next/previous calls `_viewerKey.currentState?.jumpToMatch(_currentMatchIndex)`.

---

## 6. Alternatives Considered

1. **Modal Dialog for Focus Mode**:
   - *Why rejected*: Modals prevent stream updates, block keyboard event propagation, and require full rebuilds. Using an in-tree maximized state inside `MessagesView` keeps full state and animation continuity.
2. **Global Stream Search vs. In-Inspector Search**:
   - *Why both are needed*: The global search filters *which messages* are in the list. The in-inspector search navigates *inside the active message's payload* (e.g. locating a specific UUID within a 5,000-line JSON document).

---

## 7. Verification Strategy

1. **Unit & Widget Tests**:
   - Stepper state: stepping previous/next updates `_selectedMessage` and highlights the corresponding row in `MessagesTableView`.
   - Boundary tests: previous disabled at index 0; next disabled at last index.
   - Maximize test: clicking fullscreen button expands inspector to 100%; Esc exits maximize.
   - Shortcut tests: pressing `J` and `K` simulates message stepping; pressing `J` inside a `TextField` does not step.
   - In-inspector search: typing in search highlights matches; jumping forward and backward cycles matches correctly.
2. **Analysis**:
   - `dart analyze` passes with 0 issues.
