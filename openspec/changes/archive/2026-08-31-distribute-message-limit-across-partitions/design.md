## Context

See proposal.md for motivation. Bounded reads live in `rust/kafkalyzer-kafka/src/kafka_consumer.rs`. Today:

- `should_stop_for_limit` stops when the **global** matched count reaches `max_results`.
- Polling typically drains lower partition IDs first, so one partition can consume the entire limit.
- `tail_offset_from_watermarks` seeks each partition back by the **full** global limit, which overshoots the intended per-partition window once fairness is required.

Existing empty-topic fast path, consolidated watermark lookup, and EOF termination must stay intact.

## Goals / Non-Goals

**Goals:**

- Enforce even per-partition match quotas when `max_results` is set and multiple partitions are assigned.
- Redistribute unused quota when partitions are empty or exhausted for the selected range.
- Align Latest/tail seeking with each partition's share of the limit.
- Keep unit-testable pure helpers for quota allocation and redistribution.

**Non-Goals:**

- Changing Flutter UI, limit controls, or bridge/FFI types.
- Guaranteeing strict timestamp interleaving / global time order across partitions in the stream (sorting remains a separate concern).
- Changing unlimited (`max_results = None`) or single-partition-selected behavior beyond applying the full limit to that one partition.
- Perfect statistical sampling of historical volume; fairness is about the limited result set, not full-topic sampling.

## Decisions

### 1. Per-partition match quotas with pause when filled

**Choice:** Track matched counts per partition. Give each assigned partition an initial quota of $\lfloor N / P \rfloor$, then distribute the $N \bmod P$ remainder one each to the first partitions (stable, deterministic). When a partition reaches its current quota, **pause** it via the consumer so other partitions can still fill theirs. When a partition is exhausted (EOF / end offset / empty range) with unused quota, add that leftover to a redistribution pool and increase quotas on still-active partitions (round-robin), **resume**ing paused partitions that receive extra quota.

**Why:** Pausing prevents one busy partition from advancing past interesting offsets while others are starved. Match-based quotas (not scan counts) match user-visible "limit" semantics with filters applied.

**Alternatives considered:**

- *Round-robin emit only without pause:* Still consumes ahead on hot partitions; wasted work and skewed Latest windows.
- *Independent sequential per-partition fetches:* Simpler mentally but slower (serializes I/O) and complicates progress/EOF.
- *Post-collect trim after over-fetch:* Needs reading more than $N$ then discarding; worse latency and contradicts early stop.

### 2. Latest tail seek uses per-partition share

**Choice:** Change `tail_offset_from_watermarks` (or its caller) to take `share_p` instead of the global $N$. `share_p` equals the initial even split for that partition. After redistribution, do **not** reseek; redistribution only expands how many matches may be taken from partitions already in range.

**Why:** Seeking each partition by full $N$ reads far more history than needed for a fair $N$-message result and fights pause-based fairness.

**Alternatives considered:**

- *Keep seek-by-$N$ and only fair-stop in the poll loop:* Correct stop composition but overscans each partition's history.
- *Seek by $\lceil N / P \rceil$ plus a fixed filter headroom:* Unbounded guesswork; filters already handled by redistribution within the scanned window. Accept that sparse filters may return fewer than $N$ if the tail window is too small—same class of limitation as today, just with a smaller per-partition window. Document as known trade-off; optional later headroom is out of scope.

### 3. Pure helpers for allocation logic

**Choice:** Extract pure functions (e.g. `initial_partition_quotas`, `redistribute_unused_quota`) tested without Kafka. Keep poll-loop integration thin.

**Why:** Matches existing test style for watermark/limit helpers and keeps fairness logic reviewable.

### 4. Scope of fairness

**Choice:** Apply fair quotas whenever `max_results` is `Some` and `assigned_partitions.len() > 1`. Single explicit partition and unlimited reads skip quota machinery. For `run_forever = true`, apply fair quotas only to the initial bounded tail window until high watermarks are caught up; live new messages after that are not artificially quota-capped per partition (global limit still stops emission if configured—confirm against current Stream + limit UX: today limit still stops; keep global stop, but do not pause partitions forever after catch-up).

**Clarification for Stream mode:** After all partitions reach their high watermark for the initial tail, clear or ignore per-partition pause quotas for newly produced messages until the global matched limit is hit. This avoids stalling live partitions that briefly outpace others.

## Risks / Trade-offs

- **[Sparse filters + smaller Latest window]** → Fewer than $N$ matches may be found vs today's oversized per-partition seek. Mitigation: document; redistribution still helps across partitions that do have matches in-window. Revisit headroom only if users report regressions.
- **[Pause/resume complexity]** → Incorrect resume could stall the scan. Mitigation: unit-test redistribution; integration tests with multi-partition fixtures; always resume before EOF exit.
- **[Slightly more scan time]** → Fairness may wait on slower/empty partitions before filling from hot ones. Mitigation: empty-range detection already fast-paths exhausted partitions; keep EOF checks responsive.
- **[Non-uniform remainder assignment]** → First partitions get $+1$ in the initial split. Acceptable deterministic bias of at most one message.

## Migration Plan

- No user settings migration; behavior of limited multi-partition searches changes in place.
- Roll forward with consumer unit tests; rollback is reverting the Rust consumer change.
- No schema or preference format changes.

## Open Questions

None that block implementation. Filter headroom for Latest seeks is deferred unless product feedback requires it.
