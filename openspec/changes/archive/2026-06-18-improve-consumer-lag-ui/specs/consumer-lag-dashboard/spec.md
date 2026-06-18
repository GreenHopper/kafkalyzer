## ADDED Requirements

### Requirement: Dashboard Layout with Summary KPI Cards
When a cluster is active, the Consumer Lag view MUST transition into a dashboard-style layout featuring a row of four summary metric cards at the top of the page. These cards SHALL display:
1. Total Groups: The total count of consumer groups in the active cluster.
2. Active / Stable: The count of groups currently in the 'Stable' or active states.
3. Total Lag: The aggregate sum of all lags across all consumer groups.
4. Active Queries: The count of background queries running to fetch lag data, accompanied by a progress indicator if there are queries in the queue.

#### Scenario: Displaying summary cards for active cluster
- **WHEN** the user selects an active cluster with consumer groups
- **THEN** the system SHALL display the KPI cards with the calculated metrics at the top of the page

### Requirement: Unified Toolbar Controls
The filters and action controls for consumer groups MUST be consolidated into a single unified card-like toolbar below the summary cards. The toolbar SHALL align the cluster selection dropdown and the group search input field on the left, and group the state filter dropdown, sorting criteria dropdown, and refresh interval dropdown on the right. The cluster selection dropdown MUST use the shared reusable `ClusterDropdown` component to ensure visual consistency across all features in the application.

#### Scenario: Aligning and filtering using unified toolbar
- **WHEN** the user views the Consumer Lag dashboard
- **THEN** the system SHALL display an aligned toolbar containing the shared reusable `ClusterDropdown`, search field, state filter, sorting, and refresh interval dropdowns


### Requirement: Polished Group Details and Partition Table
Each consumer group card and expanded topic-partition table MUST feature a refined layout with fixed/proportional column widths matching the header columns. Group list cards and partition detail tables SHALL include modern pill-style badges for group states, subtle hover states, and distinct colors matching the state severity (e.g., green for Stable, grey for Empty, red for Dead/Error).

#### Scenario: Visual styling of group state pills and table alignments
- **WHEN** the user expands a consumer group card
- **THEN** the system SHALL render the details list and topic-partition table with fixed columns and colored pill badges matching the group and partition state

### Requirement: Onboarding and Query Queue States
When no cluster is selected, the system SHALL display a polished onboarding view. When lag queries are queued or running in the background, a progress bar or spinner MUST represent the query queue status inside the Active Queries KPI card.

#### Scenario: Onboarding screen display
- **WHEN** the user navigates to the Consumer Lag view without an active cluster connection
- **THEN** the system SHALL show an onboarding panel with a descriptive icon and instructions to select a cluster

### Requirement: Cluster Connection Loading Feedback
When a cluster connection is being established, the Consumer Lag view MUST display a loading indicator with clear feedback that the system is connecting to the cluster.

#### Scenario: Displaying connection loading feedback
- **WHEN** the user selects a cluster and the connection is currently being established
- **THEN** the system SHALL display a visual indicator showing that the connection setup is in progress

