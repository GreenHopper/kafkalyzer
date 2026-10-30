# Tasks

## 1. Core Domain Types & Hashing Logic (`kafkalyzer-core`)

- [x] 1.1 Define `DuplicateDetectionScope`, `TopDuplicateOccurrence`, and `DuplicateAnalysisResult` structs in `rust/kafkalyzer-core/src/kafka_types.rs` and verify with `cargo test -p kafkalyzer-core`
- [x] 1.2 Implement message fingerprint hashing helpers (128-bit Sha256 truncation for payload-only and key+payload) in `rust/kafkalyzer-core` with unit tests covering matching, non-matching, and tombstone records, and verify with `cargo test -p kafkalyzer-core`

## 2. Duplicate Detection Engine (`kafkalyzer-kafka`)

- [x] 2.1 Extend `TopicAnalysisOptions` and `AnalyzerAccumulator` in `rust/kafkalyzer-kafka/src/kafka_analyzer.rs` with duplicate scope and bounded accumulator structures (`seen_hashes`, `duplicate_samples`), and verify with `cargo check -p kafkalyzer-kafka`
- [x] 2.2 Implement duplicate checking and sample recording in `record_message_with_filter` and accumulator merge in `merge`, verifying with new unit tests in `kafka_analyzer.rs` using `cargo test -p kafkalyzer-kafka`
- [x] 2.3 Populate `duplicate_analysis_result` with total, unique, duplicate count, rate %, and ranked top 20 duplicate occurrences when finalizing `TopicAnalysisReport`, and verify with `cargo test -p kafkalyzer-kafka`

## 3. Bridge Boundary & Code Generation

- [x] 3.1 Mirror the new types (`DuplicateDetectionScope`, `TopDuplicateOccurrence`, `DuplicateAnalysisResult`) in `rust/src/api/kafka_types.rs` and update mappings in `rust/src/api/kafka_analyzer.rs`
- [x] 3.2 Run `flutter_rust_bridge_codegen generate` (or project bridge build command) and verify bridge compilation with `cargo check` and `flutter analyze`

## 4. Dart Domain & Report File Persistence

- [x] 4.1 Update `lib/src/features/topic/data/topic_analysis_report_file.dart` to serialize and deserialize `duplicateAnalysisResult` with backwards compatibility for older format versions without duplicate metrics
- [x] 4.2 Write unit tests in `test/src/features/topic/data/topic_analysis_report_file_test.dart` verifying serialization, deserialization, and loading of older report versions, and run `flutter test test/src/features/topic/data/topic_analysis_report_file_test.dart`

## 5. Topic Analysis Controller & Pre-Scan Configuration

- [x] 5.1 Update `TopicAnalysisController` to hold and toggle the selected `DuplicateDetectionScope` (defaulting to `PayloadOnly`) and pass it in `TopicAnalysisOptions` to the scan API
- [x] 5.2 Add duplicate scope selector controls to the topic analysis scan options panel and verify controller state updates with unit tests in `test/src/features/topic/presentation/controllers/topic_analysis_controller_test.dart`

## 6. UI Presentation: Summary Cards & Top Duplicates Explorer

- [x] 6.1 Add a "Duplicate Messages" KPI card to `TopicAnalysisSummaryCards` showing duplicate count and rate percentage, and write widget tests in `test/src/features/topic/presentation/widgets/analysis/topic_analysis_summary_cards_test.dart`
- [x] 6.2 Create `DuplicateAnalysisView` widget displaying top 20 duplicated messages with payload preview, key, occurrence count, share %, sample coordinates (partition, offset, timestamp), and quick copy actions
- [x] 6.3 Integrate `DuplicateAnalysisView` into `TopicAnalysisView` and verify rendering with widget tests in `test/src/features/topic/presentation/widgets/analysis/`

## 7. Localization & End-to-End Verification

- [x] 7.1 Add English and German localization strings for all duplicate detection labels, cards, options, and placeholders to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, and run `flutter gen-l10n`
- [x] 7.2 Run code formatting checks (`cargo fmt --check`, `dart format --output=none --set-exit-if-changed .`) and full test suites (`cargo test`, `flutter analyze`, `flutter test`) to verify all checks pass
