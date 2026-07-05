## Why

Users need a way to quickly identify "poison pill" messages that cause consumer groups to lag. Currently, the application shows the lag (distance between current offset and log end offset) but does not allow users to inspect the content of the messages where the consumer is currently stuck. Providing a direct link to view these messages will significantly reduce the time required to debug consumer processing issues.

## What Changes

- **Message Inspection from Lag View**: Add an action to the consumer group partition table to view messages starting from the current consumer offset.
- **Direct Seeking**: Implement the capability to seek and fetch messages from specific offsets for a consumer group's partitions, even when not actively consuming.
- **Unified Inspector**: Reuse the existing message inspector from the Explorer View to display the content (key, value, headers) of the lagging messages.

## Capabilities

### New Capabilities
- `consumer-lag-messages-view`: Introduces the UI and integration logic to bridge the Consumer Lag dashboard with message inspection.

### Modified Capabilities
- `consumer-lag-monitoring`: Add requirement to support resolving current consumer offsets to a viewable message stream.
- `message-headers-inspection`: Ensure the inspector component is accessible and reusable from views other than the topic explorer.

## Impact

- **Frontend**: New action button in the partition table of the Consumer Lag dashboard. Integration with the existing message details dialog/panel.
- **Rust Bridge**: Update `rust_lib_kafkalyzer` to support fetching a small batch of messages starting at a specific offset for a given topic/partition.
- **Kafka Client**: Enhance `kafkalyzer-kafka` to handle targeted seeking and fetching for ad-hoc inspection.
