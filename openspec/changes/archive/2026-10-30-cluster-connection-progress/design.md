# Design

## Context

In Kafkalyzer, cluster connections are initiated from the Explorer sidebar list, onboarding dashboard cards, or Quick Jump / settings dialogs. When `ActiveConnectionController.connect(profile)` is called, it performs an asynchronous broker validation (`_metadataService.validateConnection`), which involves native rdkafka transport initialization and network I/O. Under adverse network conditions, unreachable brokers, or bad credentials, this validation can block until a timeout occurs (5-10+ seconds).

Currently, `ActiveConnectionController` sets `_isConnecting = true`, but does not assign `_activeProfile = profile` until validation succeeds. In `ExplorerView`, the cluster list item only checks `trailing: isActive && activeController.isConnecting`, where `isActive` requires `activeController.activeProfile?.name == cluster.name`. Consequently:
1. `isActive` is false during the entire validation phase for a newly selected cluster.
2. The trailing `CircularProgressIndicator` never renders while waiting for validation.
3. If the connection fails or times out, the indicator was never rendered at all.
4. Only when validation succeeds does `activeProfile` get assigned, causing the indicator to appear late during the subsequent `fetchTopics()` step.

## Goals / Non-Goals

**Goals:**
- Provide immediate, reliable visual progress feedback on the clicked cluster from the instant `connect()` is triggered until completion.
- Support all cluster selection entry points (Explorer sidebar cluster list and onboarding cards).
- Maintain visual feedback continuously through timeouts and connection errors.
- Prevent duplicate concurrent connection attempts to the same cluster.

**Non-Goals:**
- Modifying underlying rdkafka timeout durations or retry behaviors in Rust.
- Changing the schema fetching or topic caching mechanisms.

## Decisions

### Decision 1: Add `connectingProfile` to `ActiveConnectionController` instead of optimistic `activeProfile` assignment

- **Chosen Approach**: Introduce `ClusterProfile? _connectingProfile` and `ClusterProfile? get connectingProfile` in `ActiveConnectionController`. Set `_connectingProfile = profile` and notify listeners immediately upon `connect()` invocation; clear `_connectingProfile = null` in the `finally` block.
- **Rationale**: Optimistically assigning `_activeProfile = profile` before network validation succeeds would violate application invariants. Components like `TopicController`, `ClusterOverviewView`, and `ConsumerLagView` treat `activeProfile` as an established connection. Rollbacks on timeout would cause jarring UI thrashing. Explicit `connectingProfile` clearly separates the transition state from the active connected state.
- **Alternatives Considered**:
  - *Optimistic `activeProfile` setting with rollback*: Causes views to immediately assume connection, leading to premature topic queries and messy rollback handling if validation times out.
  - *Local UI state in ExplorerView widget*: Misses cross-widget triggers (e.g., Quick Jump or onboarding cards) and gets lost if widget rebuilds.

### Decision 2: Update Sidebar Tile to inspect `connectingProfile`

- **Chosen Approach**: In `_buildClusterListItem`, determine whether the tile represents the connecting cluster:
  ```dart
  final isConnecting = activeController.connectingProfile?.name == cluster.name ||
      (isActive && activeController.isConnecting);
  ```
  Render `CircularProgressIndicator(strokeWidth: 2)` in `trailing` whenever `isConnecting` is true. Disable `onTap` if this cluster is already connecting.
- **Rationale**: Guarantees the indicator appears on the exact cluster being connected to, regardless of whether there was a previous active cluster.

### Decision 3: Update `ExplorerOnboardingView` with Connecting State

- **Chosen Approach**: Pass `connectingProfile` (or `isConnecting`) into `ExplorerOnboardingView`. For cluster cards, when `cluster.name == connectingProfile?.name`, replace the login icon with a compact `CircularProgressIndicator` and disable button taps.
- **Rationale**: Users who click "Connect" on the initial onboarding screen receive immediate visual confirmation that the connection request is in flight.

## Risks / Trade-offs

- **[Risk]** User clicks a second cluster while the first is timing out.
  - **Mitigation**: Disconnecting or switching connection while a connection is in progress cancels or supersedes `_connectingProfile`, ensuring the indicator transitions to the new target.
- **[Risk]** Stale `connectingProfile` if an uncaught exception occurs.
  - **Mitigation**: Guarantee `_connectingProfile = null` and `_isConnecting = false` in a `finally` block within `ActiveConnectionController.connect()`.
