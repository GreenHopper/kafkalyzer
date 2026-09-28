# Proposal: Keyboard Navigation, Streaming Stepper & In-Inspector Search (Phase 2)

## Why

With Phase 1 (`message-inspector-shell`), Kafkalyzer gained an embedded split-screen inspector that eliminated the jarring modal dialogs. However, power users reviewing high-throughput Kafka streams or debugging specific incidents face three ergonomic limitations:

1. **Mouse-Bound Navigation**: Stepping through messages sequentially still requires repeated mouse clicks on small table rows or timeline cards. There is no rapid keyboard traversal.
2. **Compact Screen Friction (13"–15" Laptops)**: On laptop screens with standard OS scaling (125%–150%), even a bottom-split leaves limited vertical space for deeply nested JSON trees. Users need a **Focus Mode** that maximizes the inspector to 100% of the viewport while preserving the ability to step through messages without having to leave the view.
3. **In-Message Search & Match Navigation**: When analyzing payloads containing hundreds of lines or nested arrays, users need to quickly find specific strings or IDs within the active payload, count occurrences, and jump between matches using `Enter` / `Shift+Enter` (like standard code editors and browsers).

## What

This change implements Phase 2 of the Kafka Message UI Optimization concept:

1. **Streaming Message Stepper Toolbar**:
   - Integrates sequential navigation controls into the inspector header:
     - `[◄ (K)]` previous message
     - Position badge: `14 of 42` (with current offset/key context)
     - `[► (J)]` next message
   - Operates over the active sorted and filtered messages list in `MessagesView`.

2. **Global Keyboard Navigation**:
   - `J` / `ArrowDown`: Step to next message.
   - `K` / `ArrowUp`: Step to previous message.
   - `Esc`: Close inspector or exit maximized mode.
   - `Ctrl+F` (or `Cmd+F` on macOS): Focus the in-inspector search bar.
   - `F`: Toggle Focus Mode (maximize/minimize inspector).

3. **Maximized Focus Mode**:
   - Adds an `Icons.fullscreen` / `Icons.fullscreen_exit` toggle to the inspector header.
   - When maximized, the inspector takes 100% of the `MessagesView` area, giving deeply nested JSON structures maximum screen real estate while retaining the stepper toolbar.

4. **In-Inspector Search Bar with Match Jumping**:
   - Dedicated search bar inside `MessageInspectorPanel` (toggleable or inline in the toolbar).
   - Match count indicator (`x of y matches`).
   - Up/down stepper buttons and `Enter` / `Shift+Enter` shortcuts wired to `jumpToMatch` on `JsonOrStringViewer`.

## How

- **State Management & Selection Tracking in `MessagesView`**:
  - Track `int _selectedIndex` derived from `_cachedSortedMessages.indexOf(_selectedMessage)`.
  - Provide `_stepPrevious()` and `_stepNext()` methods that update `_selectedMessage` and keep the master list scrolled to the active row.
  - Introduce `bool _isMaximized = false` in `_MessagesViewState` to switch the layout to 100% inspector when maximized.
- **Shortcuts & Actions**:
  - Wrap `MessagesView` content in a `CallbackShortcuts` / `Focus` widget capturing `LogicalKeyboardKey.keyJ`, `LogicalKeyboardKey.keyK`, `LogicalKeyboardKey.arrowDown`, `LogicalKeyboardKey.arrowUp`, `LogicalKeyboardKey.escape`, and `LogicalKeyboardKey.keyF`.
  - Ensure typing into search input fields (in the stream search or inspector search) does not accidentally trigger navigation shortcuts.
- **MessageInspectorPanel Header Enhancements**:
  - Add stepper controls: `IconButton(icon: Icons.chevron_left)`, `${index + 1} / ${total}`, `IconButton(icon: Icons.chevron_right)`.
  - Add maximize/minimize button (`Icons.fullscreen` / `Icons.fullscreen_exit`).
  - Add search button (`Icons.search`) that opens/focuses an inline search bar with match stepper (`jumpToNextMatch` / `jumpToPreviousMatch`).
- **Localization**:
  - Add translation keys for stepper tooltips (`previousMessage`, `nextMessage`, `messagePosition`), focus mode (`focusMode`, `exitFocusMode`), and in-inspector search (`searchInMessage`, `nextMatch`, `previousMatch`, `noMatchesFound`) in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.

## Impact on Existing Capabilities

- **`message-inspector-shell`**: Extends the existing inspector shell with stepper toolbar, maximized mode, keyboard shortcuts, and in-inspector search.
- **`MessagesTableView` / `MessagesTimelineView`**: Remains unchanged in public contract; automatically updates highlighting when the stepper changes `_selectedMessage`.
- **Performance**: Zero overhead during streaming; stepper simply indexes into the already-sorted `_cachedSortedMessages`.
