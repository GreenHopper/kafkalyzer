## MODIFIED Requirements

### Requirement: Dashboard Layout with Summary KPI Cards
When a cluster is active, the Consumer Lag view MUST transition into a dashboard-style layout featuring a row of four summary metric cards at the top of the page. These cards SHALL display:
1. Total Groups: The total count of consumer groups in the active cluster.
2. Active / Stable: The count of groups currently in the 'Stable' or active states.
3. Total Lag: The aggregate sum of all lags across all consumer groups. It SHALL also display the overall aggregate lag change (processing rate/delta) as a subtitle indicating the rate of lag accumulation or resolution.
4. Active Queries: The count of background queries running to fetch lag data, accompanied by a progress indicator if there are queries in the queue.

#### Scenario: Displaying summary cards for active cluster
- **WHEN** the user selects an active cluster with consumer groups
- **THEN** the system SHALL display the KPI cards with the calculated metrics at the top of the page, including the aggregate lag change rate in the Total Lag card when lag change data is available
