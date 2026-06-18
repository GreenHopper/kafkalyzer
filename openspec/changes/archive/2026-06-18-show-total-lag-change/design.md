## Context

The `ConsumerLagView` currently displays a dashboard featuring four `KpiCard` widgets showing group count, active/stable group count, total lag, and active queries. Although individual consumer groups display their offset change rate (delta/Abarbeitung), there is no high-level display of the aggregate lag change across the entire active cluster.

## Goals / Non-Goals

**Goals:**
- Dynamically calculate the sum of all individual group lag deltas (aggregate change rate).
- Display this aggregate rate as a formatted subtitle in the "Gesamtes Lag" / "Total Lag" KPI card.
- Format the rate with locale-specific separators and sign prefix (e.g. "+1,250" or "-450").

**Non-Goals:**
- Storing historical total lag trends in this view.
- Modifying database schemas or native Rust components.

## Decisions

### 1. Calculate Aggregate Delta from `_groupDeltas`
The `_groupDeltas` map stores calculated deltas for each group. We can sum these values inside `_buildKpiCards` when compiling metrics for the dashboard cards.
```dart
final totalDelta = _groupDeltas.values.fold(0, (sum, value) => sum + value);
```

### 2. Add Subtitle to the Total Lag KPI Card
Pass the formatted delta as a `subtitle` to the third `KpiCard` inside `_buildKpiCards`.
```dart
subtitle: _groupDeltas.isNotEmpty 
    ? (isGerman ? 'Änderung: $formattedDelta' : 'Change: $formattedDelta')
    : null,
```

## Risks / Trade-offs

- **Risk**: Aggregate delta might show `0` on initial load before any lag is fetched.
- **Mitigation**: Only show the subtitle if `_groupDeltas` is not empty.
