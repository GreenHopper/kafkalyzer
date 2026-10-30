# Proposal

## Why

When users click on a cluster profile to establish a connection in Kafkalyzer, the UI currently only displays a progress indicator if the cluster is already active (`isActive && isConnecting`). Because `activeProfile` is not updated until after network validation succeeds, any connection attempt that encounters high latency, network unreachable errors, or timeouts never displays a progress indicator. The UI appears frozen or unresponsive to user clicks until the timeout elapses, causing confusion and prompting repeated clicks.

This change introduces explicit tracking of the connecting cluster profile in `ActiveConnectionController` and ensures that an immediate visual progress indicator is always rendered for the targeted cluster in the sidebar list and onboarding dashboard throughout the entire connection lifecycle, including failure and timeout conditions.

## What Changes

- **Active Connection State Tracking**: Update `ActiveConnectionController` to explicitly track `connectingProfile` (or `isConnectingCluster`) from the moment `connect()` is invoked, ensuring listeners are notified immediately before network validation begins and guaranteed to be reset upon success, failure, or timeout.
- **Immediate Sidebar Progress Indicator**: Update `_buildClusterListItem` in `ExplorerView` to evaluate whether the specific cluster is connecting (`activeController.connectingProfile?.name == cluster.name || (isActive && activeController.isConnecting)`), displaying the `CircularProgressIndicator` immediately upon click.
- **Onboarding Card Loading State**: Update `ExplorerOnboardingView` cluster cards to reflect the connecting state, displaying a loading indicator and disabling repeated clicks while connection establishment is in progress.
- **Interaction Protection**: Prevent duplicate connection requests to the same cluster while a connection attempt is actively pending.

## Capabilities

### New Capabilities
- `cluster-connection-progress`: Provides immediate visual progress feedback and robust lifecycle state tracking when connecting to Kafka clusters across all UI entry points, persisting through connection success, failure, and timeout scenarios.

### Modified Capabilities
<!-- None: existing specs do not define requirements for cluster connection progress indicators. -->

## Impact

- **Affected Code**:
  - `lib/src/features/cluster/presentation/controllers/active_connection_controller.dart`: Add `connectingProfile` property and ensure proper lifecycle management in `connect()`.
  - `lib/src/features/explorer/presentation/explorer_view.dart`: Update `_buildClusterListItem` to display trailing progress indicator based on `connectingProfile`.
  - `lib/src/features/explorer/presentation/widgets/explorer_onboarding_view.dart`: Add loading indicator and disable connect button during active connection.
  - Widget and unit tests for `ActiveConnectionController`, `ExplorerView`, and `ExplorerOnboardingView`.
- **APIs & Dependencies**: No external API or dependency changes; uses existing Flutter widgets and Material 3 design tokens.
