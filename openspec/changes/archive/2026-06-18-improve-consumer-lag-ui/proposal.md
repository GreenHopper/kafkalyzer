## Why

The current Consumer Lag view lacks visual hierarchy and feels disconnected from the rest of the application. The filter controls are wrapped in a simple layout without clean alignment, there is no high-level overview of cluster lag health (such as summary metrics), and the empty/onboarding states look plain. Enhancing the UI/UX with a modern dashboard-style layout, KPI summary cards, and polished controls will make it feel premium, intuitive, and consistent with the rest of kafkalyzer.

## What Changes

- **Active Dashboard Layout**: Transition the Consumer Lag screen into a modern dashboard structure.
- **KPI Summary Cards**: Introduce a row of four summary cards at the top of the page when a cluster is selected:
  - *Total Groups*: Total number of consumer groups in the cluster.
  - *Active / Stable*: Count of groups currently in `Stable` or active states.
  - *Total Lag*: Sum of all lags across all consumer groups.
  - *Active Queries*: Status of background lag fetch queries (with progress indicator).
- **Unified Toolbar**: Redesign the filter/control bar into a cohesive layout. Align the search field on the left and group the state filter, sorting, and refresh interval dropdowns on the right in a unified, card-like toolbar.
- **Rich Empty/Onboarding States**: Replace the basic empty/error states with polished, user-friendly layouts featuring descriptive text, icons, and clear call-to-actions.
- **Connection Feedback State**: Display a loading spinner and message when a cluster is currently connecting (e.g. `activeController.isConnecting` is true) to prevent defaulting to the onboarding screen during connection setup.
- **Refined Group Cards & Partition Tables**: Polish the list view cards and expanded topic-partition tables with better typography, consistent column widths, hover effects, and modern pill-style badges.


## Capabilities

### New Capabilities
- `consumer-lag-dashboard`: Introduces the dashboard-style layout for the consumer lag feature, including KPI summary cards, a redesigned toolbar, and polished group detail cards.

### Modified Capabilities
<!-- None -->

## Impact

- **Affected Code**: 
  - `lib/src/features/consumer/presentation/consumer_lag_view.dart`: Update layout composition.
  - `lib/src/features/consumer/presentation/widgets/consumer_group_controls.dart`: Redesign the toolbar layout.
  - New widget components for KPI cards, empty states, and status badges under `lib/src/features/consumer/presentation/widgets/`.
- **Dependencies**: No new external dependencies. Fits within existing packages (Material 3).
