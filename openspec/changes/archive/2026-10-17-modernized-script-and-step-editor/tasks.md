# Tasks

## 1. Localization Strings

- [x] 1.1 Add localized strings to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` for script step deletion confirmation dialog (title, message, cancel, delete), manual topic entry prompt, and advanced filters toggle.
- [x] 1.2 Run `flutter gen-l10n` to regenerate `AppLocalizations`.

## 2. Topic Display and Offline Resilience in `ScriptStepEditor`

- [x] 2.1 Refactor `_buildTopicSelection` and `_buildTopicField` in `lib/src/features/scripting/presentation/widgets/script_step_editor.dart` so configured topic chips are always immediately visible and removable.
- [x] 2.2 Show inline loading indicator within `suffixIcon` during background fetch rather than replacing the topic field with a centered spinner.
- [x] 2.3 Add support for manual topic addition when the cluster metadata is offline or unreachable.

## 3. Presets and Progressive Disclosure in Step Configuration

- [x] 3.1 Integrate `TopicScanMode` into `ScriptStepEditor` (map step start/end strategies to initial preset and provide preset selector buttons for *Latest N*, *Live Tail*, *Time Range*, *Offset / Earliest*).
- [x] 3.2 Update step configuration parameters when switching presets (synchronizing start/end strategies and default limit).
- [x] 3.3 Add expandable `Advanced Filters` section in `ScriptStepEditor` (or refactored `SearchStreamConfiguration`) housing `FilterType`, `SearchScope`, partition, and `fastTraceEnabled`.

## 4. Extraction Layout and Truncation Fix

- [x] 4.1 Refactor `_buildExtractionHeader` in `ScriptStepEditor` to assign a dedicated minimum width (`SizedBox(width: 110)` or proportional flex distribution) to the extraction `Source` dropdown (`KEY`, `VALUE`, `HEADER`) to prevent ellipsis truncation across dialog widths.
- [x] 4.2 Adjust topic, variable name, and JSON path field widths proportionally for responsive clarity.

## 5. ScriptEditor Header Compaction and Step Deletion Guard

- [x] 5.1 Unify `_buildPropertiesCard` and `_buildSettingsCard` in `ScriptEditor` into a compact, responsive header card with width constraints.
- [x] 5.2 Add confirmation dialog for step deletion in `ScriptEditor` before calling `_steps.removeAt(index)`.

## 6. Widget Tests and Verification

- [x] 6.1 Update existing widget tests in `test/src/features/scripting/presentation/widgets/script_editor_test.dart` to verify step deletion confirmation dialog and compact header.
- [x] 6.2 Update and extend tests in `test/src/features/scripting/presentation/widgets/script_step_editor_test.dart` to verify non-blocking topic loading, offline chip visibility, scan presets, and extraction source rendering without truncation.
- [x] 6.3 Run `flutter test test/src/features/scripting/` to ensure full regression-free test coverage.
