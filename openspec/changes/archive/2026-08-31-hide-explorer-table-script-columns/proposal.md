## Why

In the topic explorer table view, Step and Topic columns are always shown even though every row is from the same selected topic and Step only applies to script runs. That wastes horizontal space and adds noise. These columns should appear only in the scripting feature.

## What Changes

- **Hide script-only columns in explorer**: When displaying messages in the topic explorer table view, do not show the Step or Topic columns.
- **Keep columns in scripting**: Script run / script history message tables continue to show Step and Topic, where they carry meaningful context across steps and topics.
- **Wire existing flags**: Use the existing `showTopic` / `showStep` controls on the shared message table so callers opt in only where those columns are relevant.

## Capabilities

### New Capabilities
- `message-table-columns`: Contextual visibility of Step and Topic columns in the shared message table based on the hosting feature (explorer vs scripting).

### Modified Capabilities
<!-- None -->

## Impact

- **Affected code**:
  - `lib/src/ui/messages/messages_view.dart`: Stop unconditionally enabling `showTopic` / `showStep` for the table view; expose or default them appropriately for explorer.
  - `lib/src/features/topic/topic_detail_view.dart`: Ensure explorer does not request Step/Topic columns.
  - `lib/src/features/scripting/presentation/widgets/script_history/script_run_details_view.dart`: Confirm scripting still enables Step/Topic.
  - Widget tests under `test/src/ui/messages/` and related table tests.
- **Dependencies**: None.
- **APIs**: No Rust/bridge changes; presentation-only.
