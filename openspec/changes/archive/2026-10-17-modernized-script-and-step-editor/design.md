# Design

## Context

`ScriptEditor` and `ScriptStepEditor` are core desktop UI components for defining multi-step Kafka workflows with cross-step variable extractions and parameter substitution. While single-topic search (`TopicSearchBar`) was recently modernized with concise scan mode presets (`TopicScanMode`) and progressive disclosure, the scripting widgets accumulated UX friction:

1. `ScriptStepEditor` hides the entire topic selector and all configured topic chips behind a `Center(child: CircularProgressIndicator())` whenever `TopicController.isLoading` is true.
2. The search parameter matrix in `ScriptStepEditor` exposes 12 un-grouped fields simultaneously, making the step modal tall and cluttered.
3. Extraction row layout places the extraction source dropdown in an `Expanded(flex: 1)` container beside wider elements, truncating `KEY` to `KE...`.
4. `ScriptEditor` steps can be permanently deleted with a single misclick on `Icons.delete` without confirmation, and top-level settings stretch across huge horizontal viewports.

## Goals / Non-Goals

**Goals:**
- Guarantee configured topic chips remain visible and removable immediately when `ScriptStepEditor` opens, even while metadata is loading or if the cluster is offline.
- Provide inline loading indicators in the topic input field without replacing the widget tree.
- Enable manual topic addition when cluster connection is delayed or offline.
- Adopt `TopicScanMode` presets (*Latest N*, *Live Tail*, *Time Range*, *Offset / Earliest*) and progressive disclosure for advanced query filters in `ScriptStepEditor`.
- Ensure extraction source (`KEY`, `VALUE`, `HEADER`) displays in full without truncation across desktop dialog widths.
- Prevent accidental loss of configured steps in `ScriptEditor` via a confirmation dialog.
- Unify script name and concurrency limit into a compact, responsive header layout.

**Non-Goals:**
- Altering the `Script` or `ScriptStep` persistence schema or domain models.
- Changing execution runtime logic (`ScriptRunner`) or Kafka communication protocol.
- Redesigning the entire variable substitution syntax (e.g. `{{var}}` interpolation remains unchanged).

## Decisions

### 1. Non-Blocking Topic Display and Inline Loading Feedback
- **Approach**: In `ScriptStepEditor._buildTopicSelection`, remove the conditional guard that replaces the entire widget with a spinner. Instead, always render the topic input and `_selectedTopics` chip wrap.
- **Inline Loading**: In `_buildTopicField`, inspect `topicController.isLoading(_selectedCluster)`. If true, set `suffixIcon` to a small `Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))` and show an informative hint (e.g., "Loading topics..."), while allowing the user to view and delete existing chips.
- **Manual Input**: If the cluster is unreachable or offline, allow users to type a topic name manually (e.g. via a dialog or text field prompt) and append it to `_selectedTopics`.

### 2. Scan Mode Presets and Progressive Disclosure in Step Configuration
- **Approach**: Leverage existing `TopicScanMode` (`src/features/search/models/topic_scan_mode.dart`) inside `ScriptStepEditor`.
- **State Initialization**: When initializing or updating state from `ScriptStep`, determine the matching preset using `TopicScanMode.fromStrategies(startStrategy: _startStrategy, endStrategy: _endStrategy)`.
- **Mode Switching**: When the user switches scan modes via a preset button bar (`GroupButton` or `SegmentedButton`):
  - `latestN`: Set start strategy to `latest`, end strategy to `latest`, enable `limitResults` (default 200).
  - `liveTail`: Set start strategy to `latest`, end strategy to `live`, disable `limitResults`.
  - `timeRange`: Set start and end strategy to `customTimestamp`.
  - `offsetEarliest`: Set start strategy to `earliest`, end strategy to `latest`.
- **Progressive Disclosure**: Group expert parameters (`FilterType`, `SearchScope`, `startPartition`, and `fastTraceEnabled`) inside an expandable section (`Advanced Filters` toggle), keeping the initial dialog view compact and clean.

### 3. Dedicated Layout Constraint for Value Extraction Source
- **Approach**: In `_buildExtractionHeader`, replace `Expanded(flex: 1, child: ...)` for the `Source` dropdown with a fixed or min-width constrained box (`SizedBox(width: 110)` or `ConstrainedBox(constraints: BoxConstraints(minWidth: 105, maxWidth: 130))`).
- **Flex Distribution**: When multiple topics are present, allocate flex widths proportionally (e.g., `Topic` flex 3, `Variable` flex 2, `Path` flex 3) alongside the fixed-width `Source` dropdown, ensuring the text "KEY", "VALUE", or "HEADER" is fully legible.

### 4. Step Deletion Safeguard & Compact Header in `ScriptEditor`
- **Confirmation Dialog**: When the user clicks the delete button on a script step:
  - Open a Material 3 confirmation dialog via `showDialog`.
  - Display localized title and message asking to confirm step removal.
  - Execute `setState(() => _steps.removeAt(index)); _save();` only when the user confirms.
- **Unified Header**: Replace separate `_buildPropertiesCard` and `_buildSettingsCard` with a unified card containing:
  - Responsive row with `Script Name` (`Expanded`) and `Concurrency Limit` (`SizedBox(width: 160)`).
  - Max-width constraint to prevent excessive horizontal stretching on ultrawide monitors.

## Risks / Trade-offs

- **Risk**: Step search configurations saved under previous versions may have customized combinations of start/end strategies.
  - *Mitigation*: `TopicScanMode.fromStrategies` maps existing combinations to the closest matching preset, while the underlying raw fields (`startStrategy`, `endStrategy`, timestamps, offsets) remain fully preserved in `ScriptStep`.
- **Risk**: Existing widget tests that expect the old 12-field layout or immediate step deletion without dialogs will fail.
  - *Mitigation*: Update existing tests in `script_editor_test.dart` and `script_step_editor_test.dart` to account for the confirmation dialog and preset buttons, and add new test cases covering non-blocking topic loading and extraction source rendering.
