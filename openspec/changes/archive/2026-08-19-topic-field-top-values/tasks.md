<!-- markdownlint-disable MD041 -->
## 1. Rust Backend & Value Aggregation

- [x] 1.1 Update `AnalyzerAccumulator` in `rust/kafkalyzer-kafka/src/kafka_analyzer.rs` to track values for all scalar fields with bounded per-field capacity
- [x] 1.2 Update `to_report()` in `rust/kafkalyzer-kafka/src/kafka_analyzer.rs` to extract and rank the Top 10 values for every field
- [x] 1.3 Add unit tests in Rust for Top 10 field values extraction across various scalar types (strings, numbers, booleans)

## 2. Flutter UI & Field Value Explorer

- [x] 2.1 Build `FieldValueExplorer` widget in `lib/src/features/topic/presentation/widgets/analysis/field_value_explorer.dart` featuring field search, field selection, and a ranked Top 10 values card with frequency distribution bars
- [x] 2.2 Update `KeyAndFieldDistributionView` in `lib/src/features/topic/presentation/widgets/analysis/key_and_field_distribution_view.dart` to embed the interactive `FieldValueExplorer`
- [x] 2.3 Add widget tests for `FieldValueExplorer`

## 3. Localization & Verification

- [x] 3.1 Add localized strings for Top 10 field values explorer in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`
- [x] 3.2 Run `flutter gen-l10n` to update localization delegates
- [x] 3.3 Verify with `dart format`, `dart analyze`, `cargo fmt`, `cargo test`, and `flutter test`
