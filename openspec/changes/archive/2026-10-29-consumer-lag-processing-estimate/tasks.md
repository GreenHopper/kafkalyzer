# Tasks

## 1. Domain Model and Rate Estimation Logic

- [x] 1.1 Create `ConsumerLagEstimate` data model and calculation engine in `lib/src/features/consumer/domain/consumer_lag_estimate.dart` to evaluate throughput rate, backlog ETA, and status (`caughtUp`, `draining`, `accumulating`, `stalled`, `pending`); verify with unit tests in `test/src/features/consumer/domain/consumer_lag_estimate_test.dart`.
- [x] 1.2 Implement localized duration and throughput formatting helpers for human-readable outputs (`< 1m`, `~Xm Ys`, `~Xh Ym`, `> 24h`, `msg/s`); verify with unit tests covering edge durations and zero/negative intervals.

## 2. Localization Strings

- [x] 2.1 Add localized strings for processing rates, ETA descriptions, and recovery status to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`; verify code generation via `flutter gen-l10n`.

## 3. Consumer Lag View State Integration

- [x] 3.1 Update `ConsumerLagView` in `lib/src/features/consumer/presentation/consumer_lag_view.dart` to record query completion timestamps, calculate moving-average drain rates, and map consumer groups to their computed `ConsumerLagEstimate`; verify with widget tests in `test/src/features/consumer/presentation/consumer_lag_view_test.dart`.
- [x] 3.2 Update `GroupDeltaBadge` (or integrate a dedicated estimate badge) in the "Abarbeitung" / "Processed" column to present completion ETA or rate with status-aware color coding and a detailed diagnostic tooltip; verify with widget tests checking badge text, colors, and tooltips across draining, growing, stalled, and caught-up states.
- 3.3 Propagate topic and partition level timestamps or rates down to `GroupDetailsView` and `TopicPartitionTable` to display partition-level throughput and estimates; verify with widget tests in `test/src/features/consumer/presentation/topic_partition_table_test.dart`.

## 4. Verification and Quality Checks

- [x] 4.1 Run the consumer lag widget and unit test suite (`flutter test test/src/features/consumer/`) to ensure all scenarios pass without regressions.
- [x] 4.2 Run `dart analyze` and `dart format --output=none --set-exit-if-changed .` to verify zero lint warnings and standard formatting conformance.
