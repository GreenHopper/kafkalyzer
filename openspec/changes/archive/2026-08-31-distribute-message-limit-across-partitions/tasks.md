## 1. Quota helpers and unit tests

- [x] 1.1 Add pure helpers in `rust/kafkalyzer-kafka/src/kafka_consumer.rs` for even initial per-partition match quotas (`⌊N/P⌋` + remainder) and unused-quota redistribution to active partitions; verify with unit tests for even split (e.g. 200/12), remainder distribution, empty-partition redistribution, and single-partition full limit
- [x] 1.2 Update `tail_offset_from_watermarks` (or its callers) to seek by per-partition share instead of the global limit when $P > 1$; verify existing and new unit tests (including Updated Latest scenarios) pass via `cargo test -p kafkalyzer-kafka`

## 2. Poll-loop fairness

- [x] 2.1 Track per-partition matched counts in `run_poll_loop`, pause partitions that hit their current quota, and resume/raise quotas when exhausted partitions free unused quota; verify multi-partition bounded-limit unit/integration coverage shows per-partition counts differing by at most 1 when all partitions have enough matches
- [x] 2.2 Handle empty/exhausted partitions (no messages in range or EOF before quota filled) by redistributing leftover quota without stranding the global limit; verify a test where some partitions contribute zero still fills up to $N$ from the others
- [x] 2.3 Keep single-partition selection and `max_results = None` on the existing code paths (no per-partition pause machinery); verify existing single-partition / unlimited tests still pass
- [x] 2.4 For Stream mode (`run_forever = true`), apply fair quotas only for the initial tail catch-up, then allow live messages under the global limit only; verify Stream + limit does not permanently pause partitions after catch-up

## 3. Regression and formatting

- [x] 3.1 Update any Latest/tail start-strategy tests that assumed `high - N` per partition so they expect `high - share_p`; verify `cargo test -p kafkalyzer-kafka` passes
- [x] 3.2 Run `cargo fmt` on touched Rust files and confirm `cargo test -p kafkalyzer-kafka` remains green
