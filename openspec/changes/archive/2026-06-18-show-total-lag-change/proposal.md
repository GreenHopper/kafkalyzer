## Why

When viewing the Consumer Lag screen, the top dashboard displays metric cards for Total Groups, Active / Stable groups, Total Lag, and Active Queries. While individual consumer groups display their respective processing delta ("Abarbeitung"), the dashboard does not show the overall aggregate lag change rate. Displaying the total lag change in the "Gesamtes Lag" / "Total Lag" KPI card gives users immediate high-level feedback on whether the overall lag is accumulating or resolving across all groups.

## What Changes

- **Total Lag Delta Calculation**: Compute the aggregate lag change (sum of all group deltas) dynamically in the consumer lag view controller.
- **KPI Card Subtitle Enhancement**: Update the "Gesamtes Lag" / "Total Lag" KPI card to display the aggregate lag change rate as a formatted subtitle (e.g., "Änderung: -199" or "Change: -199"), matching the locale of the application.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `consumer-lag-dashboard`: Display overall aggregate lag change (processing rate/delta) in the Total Lag KPI card.

## Impact

- `ConsumerLagView`: Compute aggregate lag change and pass it as a subtitle to the "Gesamtes Lag" KPI card.
- `KpiCard`: Ensure proper rendering of subtitles for the lag metric card.
