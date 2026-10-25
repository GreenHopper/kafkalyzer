# Tasks

## 1. Static Verification Script & CI Gate

- [x] 1.1 Implement static verification script `scripts/check_read_only.sh` scanning `rust/*/src` and `lib/src` for prohibited Kafka producer/write/commit patterns (`Producer`, `ThreadedProducer`, `BaseProducer`, `FutureProducer`, `FutureRecord`, `.send(`, `commit(`, `commit_message(`, `commit_consumer_state(`, `\.subscribe\(`), and verify it exits 0 on current codebase
- [x] 1.2 Make `scripts/check_read_only.sh` executable and add test cases or verification commands verifying both passing clean codebase and failing on simulated violations
- [x] 1.3 Add `read-only-gate` job or step to `.github/workflows/build.yml` executing `scripts/check_read_only.sh` and verify workflow YAML structure

## 2. Architectural Documentation & Threat Model

- [x] 2.1 Add "Read-Only by Design" section to `README.md` detailing technical invariants (`BaseConsumer`, explicit partition assignment, `enable.auto.commit=false`, zero commit APIs), how to run `scripts/check_read_only.sh`, and least-privilege broker ACL recommendations (`kafka-acls.sh` examples)
- [x] 2.2 Update `design/feature-gap-analysis.md` to reference the completed C1, C2, and C3 specifications and verify Markdown formatting

## 3. Localization & Security UI Guidance Components

- [x] 3.1 Add localization keys for read-only badges, tooltips, dialog title, description, and Kafka ACL command examples to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, and verify `flutter gen-l10n` succeeds
- [x] 3.2 Implement `ReadOnlySecurityBadge` and `ReadOnlyGuidanceDialog` in `lib/src/features/cluster/presentation/widgets/read_only_guidance_dialog.dart` using `package:material_ui/material_ui.dart` and verify unit/widget tests pass

## 4. Integration into Cluster Configuration & Settings Views

- [x] 4.1 Integrate `ReadOnlySecurityBadge` into `ClusterConfigDialog` and verify widget tests in `test/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog_test.dart` pass
- [x] 4.2 Integrate `ReadOnlySecurityBadge` into `SettingsView` and verify widget tests in `test/src/features/settings/presentation/settings_view_test.dart` pass

## 5. End-to-End Verification

- [x] 5.1 Run `scripts/check_read_only.sh` across the entire codebase and verify zero violations
- [x] 5.2 Run `flutter analyze` and `flutter test` across all affected test suites and verify 100% pass rate with zero analyzer warnings

## Workflow follow-up

- Archive the change after implementation and verification are complete.
- Verify the archived result with `openspec validate --specs`.
