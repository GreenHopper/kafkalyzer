# Tasks

No Rust or ARB changes. Run `flutter pub get` after editing `pubspec.yaml`.

## 1. Pin today's theme

- [x] 1.1 Add `test/src/theme_test.dart` per D2. Read the expected values from the current (bridge) `AppTheme` and confirm they match the spike values in design.md D2. Run it: it passes **before** the upgrade

## 2. Upgrade and delete the bridge

- [x] 2.1 `pubspec.yaml`: `flex_color_scheme: ^9.0.0`, then run `flutter pub get` (lock: fcs 9.0.0, flex_seed_scheme 5.x)
- [x] 2.2 `lib/src/theme.dart` per D1: return `FlexThemeData.light/dark(...)` directly, with no `legacy` import, no bridge import and no #310 comment. Keep the arguments unchanged
- [x] 2.3 Delete `lib/src/flex_theme_bridge.dart`, `scripts/gen_flex_theme_bridge.py`, `test/src/flex_theme_bridge_test.dart`
- [x] 2.4 `flutter analyze` is clean. `test/src/theme_test.dart` still passes unchanged. `rg "package:flutter/(material|cupertino)\.dart" lib test` finds only generated files

## 3. Guard

- [x] 3.1 `scripts/quality_gates.sh`: add `*.mocks.dart` to `is_generated`, add `check_legacy_material_imports` per D3, add the `legacy-material-guard` entry point, and run the guard in the full gate after the shared-module guard
- [x] 3.2 `scripts/test_quality_gates.sh`: add the D4 fixtures (7 cases) and update the header comment
- [x] 3.3 Run `bash scripts/test_quality_gates.sh`: all fixtures, old and new, pass. `bash scripts/quality_gates.sh legacy-material-guard` passes on the real repo

## 4. Rules, backlog, verification

- [x] 4.1 `openspec/config.yaml`: remove `lib/src/flex_theme_bridge.dart` / `scripts/gen_flex_theme_bridge.py` from the generator-owned list. Styling & Theming: `flex_color_scheme` (≥ 9, builds material_ui themes). UI & UX "Material UI Elements": never import `package:flutter/material.dart` or `package:flutter/cupertino.dart`; the legacy-material guard enforces this. Verification step 6: add the guard
- [x] 4.2 `design/code-quality-refactoring-backlog.md`: mark Q-10 implemented (upstream migrated in fcs 9.0.0; bridge + generator deleted; guard added; CI pin dropped with the reason), and set its §8 status to implemented. Update the §-list of generated files (line ~250) to drop the bridge
- [x] 4.3 Manual check (needs a human): run the app (`flutter run -d linux`), switch light/dark, open a dialog and a text field with focus and with an error. Colours and shapes match the previous build
- [x] 4.4 Full verification, every step exits 0: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, `scripts/check_read_only.sh`, `KAFKALYZER_BASE_REF=origin/main bash scripts/quality_gates.sh`, `bash scripts/test_quality_gates.sh`
