# Tasks: Analysis Progress & Close Guard

## 1. Localization

- [x] 1.1 Add new localization strings to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` for the close confirmation dialog: title ("Operation in Progress" / "Operation in Fortschritt"), message ("A search or analysis is still running on this tab. Close the tab and cancel the operation?" / German equivalent), and button labels ("Close" / "Schließen", "Cancel" / "Abbrechen"). Also localize the existing "Scanning..." label in the tab progress indicator.
- [x] 1.2 Run `flutter gen-l10n` to regenerate the `AppLocalizations` classes and verify the new keys compile.

## 2. Tab Bar Progress for Analysis

- [x] 2.1 In `explorer_view.dart` `_buildTabItem`, obtain the `TopicAnalysisController` via `activeController.getAnalysisController(record.id)` and merge it with the stream controller in the `ListenableBuilder` using `Listenable.merge([streamCtrl, analysisCtrl])`.
- [x] 2.2 In `_buildTabItemContent`, extend the condition from `streamCtrl.isStreaming` to also check `analysisCtrl.isAnalyzing`. When analysis is active, show the progress indicator using `analysisCtrl.progressRatio` and `analysisCtrl.startTime` (reuse the existing `_buildTabProgressIndicator` or generalize it to accept a `double progress`, `DateTime? startTime`, and a `bool showIndeterminate` parameter).
- [x] 2.3 Generalize `_buildTabProgressIndicator` to compute ETA from `startTime` + `progress` (existing logic for search) and verify it works when fed analysis controller values.
- [x] 2.4 Run `flutter analyze` and verify no compilation errors in `explorer_view.dart`.

## 3. ETA in Analysis Progress Banner

- [x] 3.1 In `topic_analysis_view.dart` `_buildProgressBanner`, add a remaining time estimate calculation: if `totalMessagesToScan > 0` and `messagesPerSecond > 0`, compute `remaining = (totalMessagesToScan - scannedMessages) / messagesPerSecond`; otherwise fall back to elapsed-time-based estimate using `startTime` and `progressRatio`.
- [x] 3.2 Display the ETA text (e.g. "~45 s", "~3 m") in the progress banner row alongside the existing messages/sec display. When `totalMessagesToScan == 0`, show only messages/sec without a specific time estimate.
- [x] 3.3 Run `flutter analyze` and verify no compilation errors in `topic_analysis_view.dart`.

## 4. Close Confirmation Dialog

- [x] 4.1 Extract a shared helper (e.g. `_confirmCloseTab` or a small utility method) that takes a `BuildContext`, the stream controller, the analysis controller, and a close callback. It checks `streamCtrl.isStreaming || analysisCtrl.isAnalyzing`; if true, shows a `Dialog` with the localized title, message, and "Close"/"Cancel" buttons. On "Close" it invokes the close callback; on "Cancel" it dismisses the dialog. If neither is running, it calls the close callback directly.
- [x] 4.2 Wire the tab bar close button in `explorer_view.dart` `_buildTabItemContent` to use the new confirmation helper instead of calling `activeController.closeTopicTab(record.id)` directly.
- [x] 4.3 Wire the header close button in `topic_detail_view.dart` `_buildHeader` to use the new confirmation helper instead of calling `activeController.closeTopicTab(widget.tabId!)` directly.
- [x] 4.4 Run `flutter analyze` and verify no compilation errors.

## 5. Tests

- [x] 5.1 Update or add widget tests for the tab bar in `explorer_view_test.dart` to verify the progress indicator appears when `TopicAnalysisController.isAnalyzing` is true.
- [x] 5.2 Update or add widget tests for the analysis view to verify the ETA text is displayed when `totalMessagesToScan > 0` and `messagesPerSecond > 0`, and is hidden when `totalMessagesToScan == 0`.
- [x] 5.3 Add a widget test for the close confirmation dialog: tapping close on a tab with active streaming shows the dialog, confirming closes the tab, and canceling keeps it open.
- [x] 5.4 Run `flutter test` and verify all tests pass.
