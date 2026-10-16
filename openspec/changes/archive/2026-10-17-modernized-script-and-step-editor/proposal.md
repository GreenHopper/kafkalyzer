# Proposal

## Why

In Measure 9 of the UI/UX audit (`design/ui_ux_audit_und_onboarding_konzept.md`), several ergonomic and functional defects were identified in Kafkalyzer's scripting module (`ScriptEditor` and `ScriptStepEditor`):

1. **Critical Topic Loading Bug in `ScriptStepEditor`**: When opening the "Edit Step" modal, `topicController.fetchTopics` is invoked asynchronously. While `topicController.isLoading` evaluates to `true`, `_buildTopicSelection` replaces the entire topic selection interface—including all already configured topic chips—with a small spinner. If the target cluster is slow to respond or currently unreachable, the user cannot see which topics are configured for the step or edit them.
2. **Outdated Search Configuration Matrix**: While the single-topic search view (`TopicSearchBar`) was successfully upgraded to concise scan presets (`latestN`, `liveTail`, `timeRange`, `offsetEarliest`) with progressive disclosure, `ScriptStepEditor` still renders the full 12-field `SearchStreamConfiguration` layout, inflating the modal height and creating cognitive friction.
3. **Extraction Source Dropdown Truncation**: In `_buildExtractionHeader`, the extraction source dropdown was given `flex: 1` alongside a flex-4 topic dropdown and flex-2 variable name field. In typical desktop dialog widths, `KEY` is truncated to `KE...`, hiding critical information.
4. **Unconstrained & Unguarded `ScriptEditor`**: Script name and settings spread across full screen widths without layout constraints, and clicking the step delete icon (`Icons.delete`) immediately removes the step with zero confirmation or undo capability, risking accidental data loss.

Modernizing these components will bring scripting up to the same UX and safety standards established in previous phases.

## What Changes

- **Non-blocking Topic Selection in `ScriptStepEditor`**: Ensure configured `topicNames` chips are rendered immediately upon dialog launch regardless of whether cluster topics are loading in the background or offline. Display an inline loading indicator within the input decoration suffix icon rather than replacing the widget tree. Support manual topic input when a cluster is unreachable or slow.
- **Scan Mode Presets in Step Search Configuration**: Adopt scan presets (`TopicScanMode` presets: *Latest N Messages*, *Time Range*, *Offset / Earliest*, *Live Stream*) and fold expert options (filter type, search scope, partition, fast trace) into an expandable `Advanced Filters` section within `ScriptStepEditor`.
- **Extraction Source Visibility**: Provide adequate layout space (e.g., minimum width constraint or structured 2-row / responsive grid) so `KEY`, `VALUE`, and `HEADER` source choices are never truncated with ellipses.
- **Compact Script Header & Step Deletion Guard**:
  - Combine script name and concurrency limit into a compact, responsive header card.
  - Guard step deletion with a confirmation dialog before removing a step from the script definition.

## Capabilities

### New Capabilities
- `modernized-script-and-step-editor`: Modernized script definition and step editor interface providing non-blocking topic selection, preset scan modes, progressive disclosure for advanced query parameters, un-truncated extraction source selection, and step deletion safeguards.

### Modified Capabilities
<!-- None -->

## Impact

- **Affected Files**:
  - `lib/src/features/scripting/presentation/widgets/script_step_editor.dart`
  - `lib/src/features/scripting/presentation/widgets/script_editor.dart`
  - `lib/src/features/search/presentation/widgets/search_stream_configuration.dart` (or integrated step search controls)
  - `lib/l10n/app_*.arb` for localized dialog prompts and labels.
- **Tests**:
  - Update and add widget tests in `test/src/features/scripting/presentation/widgets/script_step_editor_test.dart` and `test/src/features/scripting/presentation/widgets/script_editor_test.dart`.
- **APIs & State**:
  - No breaking changes to `Script` or `ScriptStep` domain models; internal controller and persistence contracts remain fully backwards compatible.
