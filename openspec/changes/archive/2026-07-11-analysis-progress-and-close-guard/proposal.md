# Proposal: Analysis Progress & Close Guard

## Why

When running a topic analysis scan, the user has no visual progress indicator in the tab bar (unlike search/streaming which already shows one), and no remaining time estimate in the analysis view (unlike the tab-level search progress which shows an ETA). Additionally, closing a tab with an active search or analysis silently discards the running operation with no warning to the user, making it easy to accidentally lose a long-running scan.

## What Changes

- **Tab bar progress indicator for analysis**: The Explorer tab bar SHALL display the same progress bar + ETA indicator when a topic analysis is running, matching the existing behavior for active search streaming.
- **Remaining time estimate in analysis view**: The analysis progress banner SHALL display a remaining time estimate (e.g. "~3 m" or "~45 s") alongside the existing messages/sec and percentage display, computed from elapsed time and total messages to scan.
- **Tab close confirmation dialog**: When the user attempts to close a tab that has an active search stream or an active analysis scan, the system SHALL present an alert dialog asking for confirmation. The tab is closed only if the user confirms; otherwise the operation continues running.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `topic-search-tabs`: The tab bar SHALL show a progress indicator and ETA when a topic analysis is running (previously only shown for active search streaming). The tab close action SHALL present a confirmation dialog when either a search stream or analysis scan is still running in that tab.
- `topic-content-analysis`: The analysis progress banner SHALL include a remaining time estimate in addition to the existing scanned/total message count, percentage, and messages/sec display.

## Impact

- **Flutter/Dart UI**: `explorer_view.dart` (tab bar progress logic), `topic_analysis_view.dart` (progress banner ETA), `active_connection_controller.dart` (close guard or return running-state so UI can confirm), `topic_detail_view.dart` (close button handler).
- **Localization**: New strings needed in `.arb` files for the confirmation dialog message and the ETA label (if not already present).
- **No Rust/backend changes**: All progress data (`isAnalyzing`, `progressRatio`, `messagesPerSecond`, `startTime`, `scannedMessages`, `totalMessagesToScan`) is already exposed through `TopicAnalysisController`. The streaming progress data is already exposed through `MessageStreamController`.
- **No breaking changes**: Existing behavior for completed searches/analyses and non-running tabs is unchanged.
