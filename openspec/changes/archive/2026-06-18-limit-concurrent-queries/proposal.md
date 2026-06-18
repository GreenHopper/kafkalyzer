## Why

During filtering or searching of consumer groups on the Consumer Lag screen, the number of concurrent query requests for group lag details spikes to over 20, bypassing the intended concurrency queue limits. This issue occurs because searching triggers new background queries for all matched groups simultaneously, without properly checking or restricting currently running and queued queries. This proposal aims to strictly enforce query limit constraints, increase the default concurrency limit to 5, and make it configurable via the general settings.

## What Changes

- **Strict Queue Concurrency Enforcement**: Refactor background queue processing in `ConsumerLagView` to guarantee active concurrent queries never exceed the configured limit.
- **Configurable Concurrency Limit**: Add a new configuration setting in `SettingsView` allowing users to change the maximum number of concurrent queries (defaulting to 5).
- **Settings Persistence**: Persist the configurable limit inside `SharedPreferences` as `consumer_max_concurrent_queries`.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `consumer-lag-monitoring`: Configure and enforce maximum concurrent lag query limit.

## Impact

- `ConsumerLagView`: Updates queue logic to read limits dynamically and prevent queries from overflowing.
- `SettingsView`: UI controls for modifying the concurrency limit.
- `SharedPreferences`: Key `consumer_max_concurrent_queries` used for setting persistence.
