# Design

## Context

`ConsumerLagView` currently displays consumer groups with metrics including active members, topics, total lag, a sparkline trend (`LagTrend`), and a discrete change delta (`GroupDeltaBadge`) representing the difference between the current lag snapshot and the immediate previous snapshot.

While `_groupDeltas` captures the numerical difference between query snapshots, it lacks timestamp context, meaning the actual processing throughput (messages/sec) and backlog resolution timeframe (estimated time to completion / ETA) cannot be determined by the user.

## Goals / Non-Goals

**Goals:**
- Provide clear processing throughput rates (messages per second) and estimated completion times (ETA to zero lag) for consumer groups in `ConsumerLagView`.
- Robustly handle all lifecycle states: active backlog drain, backlog accumulation/growth, stalled/idle consumption with pending lag, zero lag (caught up), and single-reading cold-start.
- Smooth out instantaneous poll fluctuations by supporting windowed rate computation across recent timestamped readings.
- Maintain seamless integration with existing table columns, sorting, localized strings (EN/DE), and Material UI theming.

**Non-Goals:**
- Modifying the Rust backend or flutter_rust_bridge layer: All required offset and lag data are already fetched via `fetch_consumer_lags` and `fetch_consumer_group_lag`.
- Machine learning or predictive arrival curve modeling: The estimate will rely on deterministic rate calculation from observed lag deltas and elapsed query time.

## Decisions

### Decision 1: Timestamped Lag History & Moving Average Rate Calculation
- **Choice**: Extend the retained history structure to record `DateTime` timestamps alongside lag values (e.g. `(DateTime timestamp, int lag)`), maintaining the existing `_lagHistoryLength = 20` bounds.
- **Computation**:
  - Calculate instantaneous rate between consecutive queries:
    $$\Delta t = t_{\text{current}} - t_{\text{prev}}, \quad \Delta L = L_{\text{current}} - L_{\text{prev}}, \quad \text{Rate} = -\frac{\Delta L}{\Delta t}$$
  - For groups with multiple retained samples in the session, calculate a smoothed rate over the recent window (last 3 to 5 readings) to eliminate noise caused by Kafka batch commits or query timing jitter.
  - When $\text{Rate} > 0$ (net lag decreasing):
    $$\text{ETA} = \frac{\text{Current Lag}}{\text{Rate}}$$
- **Alternatives Considered**:
  - *Committed offset difference instead of lag delta*: Tracking offset delta $(\text{offset}_2 - \text{offset}_1)$ shows consumer fetch rate, but ignores concurrent producer ingest rate. If a consumer processes 100 msg/s while producers publish 150 msg/s, the backlog is growing by 50 msg/s. Reporting an ETA based on 100 msg/s would be completely inaccurate. Net lag drain rate reflects the true time to reach zero lag.

### Decision 2: State Model for Processing Estimates (`ConsumerLagEstimate`)
- **Choice**: Encapsulate calculation and presentation state in a dedicated immutable model `ConsumerLagEstimate` with explicit status states:
  - `caughtUp`: Total lag is 0.
  - `draining`: Total lag > 0 and net drain rate > 0. Carries `estimatedDuration` and `ratePerSecond`.
  - `accumulating`: Total lag > 0 and net lag is increasing ($\Delta L > 0$).
  - `stalled`: Total lag > 0 and net change is 0 over elapsed time.
  - `pending`: Fewer than two timestamped samples available.
- **Alternatives Considered**:
  - *Storing loose nullable doubles and strings in `_ConsumerLagViewState`*: Scattering status flags and formatters directly across view state increases complexity and makes unit testing difficult. A dedicated domain object with pure calculation functions allows thorough unit testing without widget plumbing.

### Decision 3: UI Integration in the "Abarbeitung" / "Processed" Column
- **Choice**:
  - Enhance the existing Column 6 ("Abarbeitung" / "Processed") and `GroupDeltaBadge` component to display the processing estimate prominently (e.g., `~2m 30s` or `-120/s`) with supporting status colors (green for draining, orange for accumulating, grey for stalled/pending).
  - Provide a rich, localized tooltip on hover showing the exact calculated metrics:
    - Current Processing Rate (e.g., `42 msg/s`)
    - Net Backlog Delta (e.g., `-250 msgs`)
    - Elapsed Sample Interval (e.g., `10.2s`)
    - Status / ETA description
  - In `GroupDetailsView` and `TopicPartitionTable`, surface corresponding partition and topic processing rates.
- **Alternatives Considered**:
  - *Adding an 8th column to the table*: Screen real estate on desktop is already apportioned across 7 columns (Group ID, State, Protocol, Consumers, Topics, Total Lag, Processed). Adding an additional column causes overflow or crowds Group ID. Combining the rate/ETA into the Processed column preserves the responsive 7-column layout.

### Decision 4: Human-Readable Duration Formatting
- **Choice**: Format estimated completion times into intuitive, compact strings:
  - $< 60\text{s}$: `< 1m` (or `~45s`)
  - $1\text{m} - 59\text{m}$: `~Xm Ys`
  - $1\text{h} - 24\text{h}$: `~Xh Ym`
  - $> 24\text{h}$: `> 24h`
- **Alternatives Considered**:
  - *Raw seconds or HH:MM:SS*: Too technical and hard to read at a glance. Approximate humanized durations match modern operational dashboard standards.

## Risks / Trade-offs

- **[Risk] High jitter during manual or rapid consecutive refreshes**:
  $\rightarrow$ *Mitigation*: Enforce a minimum interval threshold (e.g. at least 1 second elapsed) before updating rate estimates to prevent division-by-zero or extreme spikes.

- **[Risk] Bursty producer traffic causing flickering between "draining" and "accumulating"**:
  $\rightarrow$ *Mitigation*: Use a rolling average over the recent 3–5 samples when available, smoothing out temporary producer spikes.

- **[Risk] Rebalances or partition assignment changes during query intervals**:
  $\rightarrow$ *Mitigation*: If the partition count changes between snapshots, invalidate previous partition-level baselines for that transition.
