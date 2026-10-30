# Tasks

## 1. Decoded Duplicate Payload Resolution (`kafkalyzer-kafka`)

- [x] 1.1 In `rust/kafkalyzer-kafka/src/kafka_analyzer.rs`, update `record_message_with_filter` to prioritize `parsed_payload` (serialized to JSON) and parsed JSON bytes before falling back to raw UTF-8 or `[Binary 0x...]` hex previews
- [x] 1.2 Increase duplicate sample payload storage capacity from 120 up to 4,000 characters in `AnalyzerAccumulator` to capture complete or comprehensive decoded records for top duplicates
- [x] 1.3 Add unit tests in `kafka_analyzer.rs` covering duplicate detection with Schema Registry / Avro decoded `parsed_payload`, JSON payloads, plain text, and binary fallbacks, and verify with `cargo test -p kafkalyzer-kafka --manifest-path rust/Cargo.toml`

## 2. Interactive Duplicate Inspector Dialog & Navigation (`kafkalyzer`)

- [x] 2.1 Create `DuplicateDetailsDialog` in `lib/src/features/topic/presentation/widgets/analysis/duplicate_details_dialog.dart` displaying full decoded payload, formatted JSON syntax view, sample coordinates (partition, offset, timestamp), key, duplicate occurrences, and quick copy actions
- [x] 2.2 In `lib/src/features/topic/presentation/widgets/analysis/duplicate_analysis_view.dart`, make table rows interactive and add an info button to open `DuplicateDetailsDialog` on selection
- [x] 2.3 Wire the "Open in Messages" action in `DuplicateDetailsDialog` to navigate to the topic's messages view positioned at the sample partition and offset when active in session
- [x] 2.4 Add widget tests in `test/src/features/topic/presentation/widgets/analysis/duplicate_details_dialog_test.dart` and update `duplicate_analysis_view_test.dart` to verify dialog opening and copy actions

## 3. Localization & Quality Verification

- [x] 3.1 Add German and English localization keys for duplicate details dialog title, labels, actions, and message navigation to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, and run `flutter gen-l10n`
- [x] 3.2 Run format checks (`cargo fmt --check --manifest-path rust/Cargo.toml`, `dart format --output=none --set-exit-if-changed lib/ test/`) and full test suites (`cargo test --workspace --manifest-path rust/Cargo.toml`, `flutter analyze`, `flutter test`) to verify all checks pass
