# Design: Analysis Progress & Close Guard

## Context

See proposal.md for motivation. The current state of the codebase:

- **Tab bar** (`explorer_view.dart`): `_buildTabItemContent` checks `streamCtrl.isStreaming` to decide whether to show the progress indicator (`_buildTabProgressIndicator`) or the message count badge. There is no awareness of `TopicAnalysisController` state.
- **Analysis view** (`topic_analysis_view.dart`): `_buildProgressBanner` shows scanned/total count, percentage, and messages/sec — but no remaining time estimate.
- **Tab close** (`active_connection_controller.dart`): `closeTopicTab` disposes stream and analysis controllers immediately with no guard. The close buttons exist in two places: the tab bar close icon and the header close button in `topic_detail_view.dart`.

All required progress data is already available:

- `TopicAnalysisController`: `isAnalyzing`, `progressRatio`, `scannedMessages`, `totalMessagesToScan`, `messagesPerSecond`, `startTime`
- `MessageStreamController`: `isStreaming`, `progress`, `totalConsumed`, `totalToScan`, `startTime`

## Goals / Non-Goals

**Goals:**

- Show a consistent progress bar + ETA in the tab bar for both search streaming and analysis (same visual component).
- Add a remaining-time estimate to the analysis progress banner.
- Guard tab close with a confirmation dialog when any operation is running.
- Keep the close guard at the UI layer (widget level) to avoid changing the controller's synchronous `closeTopicTab` signature.

**Non-Goals:**

- No changes to Rust backend or the flutter_rust_bridge generated API.
- No new controllers or state management — reuse existing `ChangeNotifier` instances.
- No changes to the analysis scan algorithm or streaming logic.
- No "close all tabs" feature (out of scope).

## Decisions

### 1. Tab bar progress: extend the existing `ListenableBuilder` to also listen on the analysis controller

**Choice:** In `_buildTabItemContent`, read both `streamCtrl.isStreaming` and the corresponding `TopicAnalysisController.isAnalyzing`. If either is active, show the progress indicator. The `ListenableBuilder` will use `Listenable.merge([streamCtrl, analysisCtrl])` so the tab bar re-renders on either controller's change.

**Rationale:** This is the minimal change — we already have the `_buildTabProgressIndicator` widget that accepts progress and start time. We just need to feed it the right controller's values. Using `Listenable.merge` avoids creating a new composite notifier or a new reactive mechanism.

**Alternative considered:** Creating a unified "tab activity" model in `ActiveConnectionController` that tracks both stream and analysis state. Rejected — adds a new abstraction layer for a simple "which controller is running?" check.

### 2. ETA computation: reuse the same formula as the search progress

**Choice:** For analysis, compute `remaining = (totalMessagesToScan - scannedMessages) / messagesPerSecond` when `messagesPerSecond > 0`. Fall back to the elapsed-time-based estimate (`elapsed / progress`) if `messagesPerSecond` is 0. This mirrors the existing tab-bar search ETA logic.

**Rationale:** The `messagesPerSecond` value from `TopicAnalysisProgress` is already a smoothed rate from the Rust side and is more accurate than a simple elapsed/progress ratio. Using it first with a fallback covers the edge case where throughput is still ramping up.

**Alternative considered:** A purely elapsed-based estimate. Rejected — the throughput rate is already available and is more accurate for analysis (which scans messages at a steady rate).

### 3. Close guard: UI-layer confirmation dialog, not a controller-level guard

**Choice:** The close button handlers (in `explorer_view.dart` tab bar and `topic_detail_view.dart` header) will check whether the stream controller is streaming or the analysis controller is analyzing. If either is active, show a `Dialog` with a message and two buttons ("Close" / "Cancel"). Only on "Close" do we call the existing `closeTopicTab` / `closeTopic`.

**Rationale:** `closeTopicTab` is synchronous and called from multiple places. Adding an async confirmation inside the controller would break its contract and complicate `clearOpenTopics` / `disconnect`. The UI is the right layer for user interaction.

**Alternative considered:** Making `closeTopicTab` return a `Future` and adding a callback for confirmation. Rejected — couples the controller to UI concerns and breaks the existing `closeTopic` / `clearOpenTopics` / `disconnect` call sites that must not prompt.

### 4. Which operations count as "running" for the guard

**Choice:** The guard triggers when `streamController.isStreaming == true` OR `analysisController.isAnalyzing == true`. Both controllers are accessible via `ActiveConnectionController.getStreamController(tabId)` and `getAnalysisController(tabId)`.

**Rationale:** These are the only two long-running operations a tab can have. Checking them directly is simpler than a generic "has active work" flag.

### 5. Localization: add new strings to `.arb` files

**Choice:** Add localized strings for:

- Confirmation dialog title (e.g. "Operation in Progress")
- Confirmation dialog message (e.g. "A search or analysis is still running on this tab. Close the tab and cancel the operation?")
- "Close" and "Cancel" button labels (reuse existing if present)
- ETA label if not already localized (the existing tab-bar search ETA uses a raw string "Scanning..." which should also be localized as a drive-by)

**Rationale:** Project guideline requires all user-facing strings to be localized via `AppLocalizations`.

## Risks / Trade-offs

- **`Listenable.merge` in tab bar for many tabs:** Each tab already creates a `ListenableBuilder`. Merging two listeners per tab doubles the listener count. For typical usage (single-digit tabs), this is negligible. If tab counts grow, the `IndexedStack` already keeps all tab views alive, so the listener overhead is proportional to what already exists.
- **ETA accuracy:** The `messagesPerSecond` value is a moving average from the Rust side. Early in a scan it may be unreliable. Mitigated by the indeterminate-progress fallback when `messagesPerSecond == 0` or when the total is unknown.
- **Close dialog blocking `clearOpenTopics`:** `clearOpenTopics` (e.g. on disconnect) must close all tabs without prompting. Since the guard lives at the individual close button handler, `clearOpenTopics` / `disconnect` / `closeTopic` are unaffected — they continue to close immediately.

## Migration Plan

No migration needed. This is purely additive UI behavior. Existing tabs without running operations close instantly as before. No data format changes, no API changes.
