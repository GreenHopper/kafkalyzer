# Tasks

## 1. Rust Backend & Bridge Layer (Schema Compatibility & Associated Topics)

- [x] 1.1 Implement `check_schema_compatibility` in `rust/kafkalyzer-kafka/src/schema_registry.rs` calling Confluent Schema Registry `/compatibility` endpoint and verify unit tests pass with `cargo test -p kafkalyzer-kafka`
- [x] 1.2 Implement subject-to-topic association resolver in `rust/kafkalyzer-kafka/src/schema_registry.rs` and verify unit tests pass with `cargo test -p kafkalyzer-kafka`
- [x] 1.3 Expose schema compatibility and subject association types and methods in `rust_lib_kafkalyzer` bridge crate and verify bridge compilation

## 2. Dart Services & Schema Evolution Workflows (C5)

- [x] 2.1 Add `checkSchemaCompatibility` and topic discovery to `SchemaRegistryService` and `SchemaController` and verify service tests pass
- [x] 2.2 Add localization strings for schema compatibility, version diffs, and topic associations to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, and verify `flutter gen-l10n` succeeds
- [x] 2.3 Implement schema compatibility check UI and two-version visual diff viewer in `lib/src/features/schema/presentation/widgets/schema_diff_dialog.dart`, integrate into `TopicSchemaInspectorView`, and verify widget tests pass

## 3. Dead-Letter Queue & Retry Topic Detection (C6)

- [x] 3.1 Implement `DlqTopicDetector` utility for topic pattern categorization (`-retry`, `-dlq`, etc.) and failure header extraction (`x-exception-message`, `x-original-topic`, etc.) with unit tests
- [x] 3.2 Add localization strings for DLQ badges, failure diagnostics cards, and kcat command generation to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, and verify `flutter gen-l10n` succeeds
- [x] 3.3 Add DLQ/retry badges and child topic grouping to `TopicListItem` and Explorer sidebar and verify widget tests pass
- [x] 3.4 Implement `DlqFailureDiagnosticsCard` in `MessageInspectorPanel` with one-click navigation to original topic/offset and kcat CLI command copy, and verify widget tests pass

## 4. Shareable Message References & Quick Jump (C7)

- [x] 4.1 Implement `MessageReference` model and URI parser/serializer (`kafkalyzer://open?...`) with comprehensive unit tests
- [x] 4.2 Add "Copy Shareable Link" action to `MessageInspectorPanel` header and message table context menu, and verify widget tests pass
- [x] 4.3 Implement `QuickJumpDialog` (with global keyboard shortcut `Ctrl+G` / `Cmd+G`) to resolve reference links, activate cluster, open topic tab, and seek to message, and verify widget tests pass

## 5. End-to-End Verification & Quality Gates

- [x] 5.1 Run `scripts/check_read_only.sh` to ensure no read-only invariants are violated
- [x] 5.2 Run `flutter analyze` and `flutter test` across all affected test suites and verify 100% pass rate

## Workflow follow-up

- Archive the change after implementation and verification are complete.
- Verify the archived result with `openspec validate --specs`.
