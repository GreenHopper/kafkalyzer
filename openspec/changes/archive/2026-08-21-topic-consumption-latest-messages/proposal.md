## Why

When message production to a Kafka topic stops or becomes inactive, users are currently unable to inspect the most recently produced messages without manually guessing exact past offsets or timestamps. Selecting "Latest" as a start condition currently defaults start offsets to the partition high watermarks; for bounded reads this immediately yields 0 messages, and for live streams it waits indefinitely for new messages that may never arrive. 

Users need a straightforward way in the UI to request the "latest N messages" (e.g., latest 200 messages) by combining the "Latest" start strategy with the configurable limit. This change enables tail consumption from partition watermarks while preserving and clarifying all existing offset, timestamp, earliest, and live-streaming workflows.

## What Changes

- **Tail Offset Resolution for "Latest" Start Strategy**: When starting from `Latest`, the Rust consumer computes partition start offsets as `max(low_watermark, high_watermark - limit)` for each assigned partition, enabling bounded and live consumption of the most recently produced messages.
- **Enhanced Start and Stop Condition Semantics**:
  - **Start Condition**:
    - `Earliest`: Starts at the beginning of the topic log (`low_watermark`). When paired with a limit of $N$, retrieves the oldest $N$ messages.
    - `Latest`: Starts at the tail of the topic log (`max(low, high - limit)`). When paired with a limit of $N$, retrieves the latest $N$ messages.
    - `Offset`: Starts at a specified partition offset.
    - `Timestamp`: Starts at a specified datetime / epoch timestamp.
  - **Stop Condition**:
    - `End`: Bounded read stopping at the current high watermark (or limit / target bounds).
    - `Stream`: Live continuous streaming that continues listening for newly produced messages after reading past messages.
    - `Offset`: Bounded read stopping at a specified end offset.
    - `Timestamp`: Bounded read stopping at a specified end timestamp.
- **UI & Usability Improvements**:
  - Update `StartConditionConfiguration` and `EndConditionConfiguration` with intuitive localized labels and helpful tooltips explaining how the start strategy, stop condition, and limit interact.
  - Fix missing `endOffset` argument forwarding in `MessageStreamController`.
- **Comprehensive Delta Spec & Verification**: Formulate delta requirements under `topic-consumption` spec and provide automated unit and integration test coverage for tail offset calculation and bounded consumption.

## Capabilities

### Modified Capabilities
- `topic-consumption`: Enhances start offset resolution to support tail message consumption from partition high watermarks bounded by the result limit when using the `Latest` start strategy.

## Impact

- **Rust Backend** (`rust/kafkalyzer-kafka/src/kafka_consumer.rs`, `rust/src/api/kafka_consumer.rs`):
  - Add tail offset calculation logic during `resolve_start_offsets`.
  - Pass start strategy / tail indicator across the Flutter-Rust bridge.
- **Dart Frontend** (`lib/src/features/search/`, `lib/src/features/topic/`):
  - Pass start strategy and limits cleanly from `TopicDetailView` and `MultiSearchController`.
  - Fix `endOffset` forwarding in `MessageStreamController`.
- **Localization** (`lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`):
  - Add descriptive tooltips and clear UI copy for start and stop condition choices.
