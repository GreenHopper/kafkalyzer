## Context

The current Consumer Lag view in Kafkalyzer has several usability issues:
- There is no high-level summary/overview of the lag health for the selected cluster (e.g., total number of groups, total lag).
- The filters are wrapped in a generic layout without clear alignment.
- When no cluster is selected, the onboarding view looks plain and basic.
- Expansion tiles and table headers lack alignment and consistent column spacing.

## Goals / Non-Goals

**Goals:**
- Transition the Consumer Lag view into a dashboard layout with summary KPI cards at the top.
- Redesign the controls toolbar for a modern, clean, card-like look.
- Style expansion tiles and tables with consistent margins, padding, column alignments, hover effects, and color-coded status badges.
- Improve onboarding state layout with clear instructions and a premium visual aesthetic.

**Non-Goals:**
- Changing the underlying Rust bridge layer or Kafka data fetching logic.
- Adding complex chart visualizers (e.g., line charts) in this phase.

## Decisions

### 1. Introduce Metric Aggregation on the Frontend
- **Option A**: Implement aggregation logic inside the Rust backend and expose a new bridge method.
- **Option B (Selected)**: Compute high-level metrics directly in Dart using the existing `_lags` array.
- **Rationale**: Since the UI already fetches all consumer groups and their partition lags, we can derive total lag, total groups, and active states entirely on the client side. This keeps backend API footprint minimal and ensures faster reactivity.

### 2. Layout Structure using a Scrollable Dashboard View
- **Selected approach**: Place the KPI metric cards at the top in a horizontally scrollable row or a responsive flex grid. Place the toolbar in a card layout below the metrics, and show the group list below the toolbar.
- **Rationale**: Provides clear top-down visual hierarchy where the user gets an overview first, filters the list, and then scrolls through the detailed groups.

### 3. State-based Color Badges for Consumer Group Health
- **Selected approach**: Define clear visual signals:
  - `Stable` / `Active` states: Soft green background with dark green text.
  - `Empty` state: Soft grey background with dark grey text.
  - `Dead` / `Error` states: Soft red background with dark red text.
  - Other states (e.g., Rebalancing): Soft orange/amber background with dark orange text.

### 4. Visual Feedback During Cluster Connection Setup
- **Selected approach**: Check the `activeController.isConnecting` state. If it is true, render a circular progress indicator with loading text (e.g., "Connecting to cluster...") in place of the main dashboard/onboarding content.
- **Rationale**: Since the active profile is only assigned after a connection validation succeeds, querying `activeController.isConnecting` allows us to intercept the onboarding state during the connection attempt and provide immediate feedback.

### 5. Reusable Cluster Selection Component
- **Selected approach**: Replace the raw `DropdownButton` in `ConsumerGroupControls` with the global `ClusterDropdown` widget (`lib/src/features/cluster/presentation/widgets/cluster_dropdown.dart`).
- **Rationale**: Using the pre-existing `ClusterDropdown` enforces visual and architectural uniformity across the app (currently used in Multi-Suche and now in Consumer-Lag), and leverages unified logic for styling, cluster lists, and cached topic status checks.



## Risks / Trade-offs

- *[Risk]*: Concurrent query calculations might block the main UI thread if there are thousands of partitions.
  - *Mitigation*: The current code already limits concurrent queries to 3 (`_maxConcurrentLagQueries = 3`). Aggregating lag numbers is a quick O(N) traversal in memory.
