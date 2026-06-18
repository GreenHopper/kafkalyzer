## Context

The `ConsumerLagView` fetches detailed partition offset lags for multiple consumer groups asynchronously. To manage system resources, a queue mechanism exists. However, searching or filtering currently bypasses the concurrency check because of an explicit search-matching check (`!matchesSearch`). This allows all matched search results to query the backend concurrently, leading to spikes exceeding 20 concurrent queries and degrading app responsiveness.

## Goals / Non-Goals

**Goals:**
- Guarantee that background queries for group lag details strictly respect the concurrent queries limit under all conditions (including active searches).
- Increase the default concurrency limit from 3 to 5.
- Make the maximum concurrency limit configurable in the Settings screen and persist the value.

**Non-Goals:**
- Implement generic queue management library; the current simple list-based queue in `_ConsumerLagViewState` is sufficient.

## Decisions

### 1. Remove Search Concurrency Bypass
Remove the `!matchesSearch` check from the concurrency limit guard in `_loadGroupLag`. This ensures search-matching consumer groups are correctly enqueued when the concurrency limit is reached.

### 2. Make limit configurable via SharedPreferences
Change `_maxConcurrentLagQueries` from a static constant to an instance variable in `_ConsumerLagViewState`. Load this variable from `SharedPreferences` (key: `consumer_max_concurrent_queries`) on initialization and on data fetch.

### 3. Add Concurrency UI Input in SettingsView
Add an input row in the General Settings section of `SettingsView` to modify this limit. It will read from and persist to `SharedPreferences` under `consumer_max_concurrent_queries`.

## Risks / Trade-offs

- **Risk**: User configuring a very high concurrency limit.
- **Mitigation**: Add a warning/guidance helper text below the setting in the UI indicating that higher values might impact app performance.
