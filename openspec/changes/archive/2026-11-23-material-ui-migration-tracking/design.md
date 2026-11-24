# Design

## Context

See proposal.md (Why) for the motivation and the spike result. Current state:

- `pubspec.yaml`: `flex_color_scheme: ^8.3.1` (locked 8.4.0), `material_ui: ^1.0.0`
  (locked 1.11.1), `cupertino_ui: any`, `flutter_localizations` (sdk).
- `lib/src/theme.dart` (56 L) has `AppTheme.light/dark` =
  `flexThemeToModern(FlexThemeData.light/dark(…, visualDensity:
  legacy.VisualDensity…).copyWith(splashFactory: legacy.NoSplash…))`.
- The only hand-written legacy imports are `lib/src/theme.dart:8`,
  `lib/src/flex_theme_bridge.dart:9` (labelled generated, but hand-edited) and
  `test/src/flex_theme_bridge_test.dart:5`.
- `lib/src/app.dart` already uses material_ui's
  `GlobalMaterialLocalizations.delegates`.
- `scripts/quality_gates.sh`: `is_generated` matches `*.g.dart`,
  `*.freezed.dart`, `lib/src/rust/*`, `lib/l10n/*`. `check_shared_imports` is
  the pattern for an absolute import guard (tooling error on an unreadable
  file). `scripts/test_quality_gates.sh` currently runs fixture Tests 1–31.

## Goals / Non-Goals

**Goals:**
- No hand-written source imports legacy Material or Cupertino. The theme comes
  straight from fcs 9, and the gate keeps it that way.
- The app's theme values stay the same, and a test pins them.

**Non-Goals:** CI Flutter pin, the gen-l10n delegate list, and visual changes
(proposal).

## Decisions

### D1 — Upgrade instead of re-baselining the generator

fcs 9 returns material_ui `ThemeData`, so the bridge has nothing left to do.
Re-baselining would mean teaching the generator to emit about 200 lines of
hand-written helpers, then maintaining a 1 300-line mirror of `ThemeData`
against every SDK. Deleting it removes that maintenance cost.

`theme.dart` after the change is the same `FlexThemeData.light/dark(...)`
call with the same arguments, returned directly. `visualDensity` and
`NoSplash` come from material_ui. The comment block about #310 goes away.

### D2 — Theme regression test pins today's values

`test/src/theme_test.dart` replaces the bridge test. For light and dark it
asserts:
- brightness and `useMaterial3`
- `VisualDensity.adaptivePlatformDensity` (compared by value, not identity)
- `splashFactory` identical to `NoSplash.splashFactory`
- `textTheme.bodyLarge.fontFamily` equals the value `AppTheme` produces today
  under test (`sans-serif`)
- the colours from the spike: light primary `0xff303f9f`, onPrimary
  `0xffffffff`, secondary `0xff512da8`, surface `0xfffafafb`, scaffold
  `0xffeeeff7`; dark primary `0xff7986cb`, onPrimary `0xffffffff`, secondary
  `0xff9575cd`, surface `0xff0b0b0d`, scaffold `0xff131520`
- input decoration border radius `BorderRadius.circular(4)`

The test reads the actual values before and after the upgrade (task 1.1), so
the expected values come from the old bridge output, not from fcs 9.

Alternative: golden images. Rejected: they are platform-font sensitive and
slower, and value assertions catch the drift we care about.

### D3 — `legacy-material-guard`

`check_legacy_material_imports`:
- Scope: tracked or untracked `*.dart` files under `lib/` and `test/` (via
  `git ls-files --cached --others --exclude-standard`), skipping
  `is_generated`.
- `is_generated` gains `*.mocks.dart`. mockito owns those files, and they live
  only under `test/`, which no other guard scans, so this changes no other
  guard's result.
- Match: lines `^(import|export)[[:space:]]+['"]package:flutter/(material|cupertino)\.dart['"]`.
  dart format keeps the URI on the directive line, so prefixes, `show`, and an
  `// ignore:` on the line above are all still caught.
- Output: `legacy material guard: <file> → package:flutter/<lib>.dart`. A
  file that is listed but unreadable is a tooling error (same as the shared
  guard).
- Entry point: `bash scripts/quality_gates.sh legacy-material-guard`. In the
  full gate it runs after the shared-module guard.

Alternative: rely on `flutter analyze` `deprecated_member_use`. Rejected: a
one-line `// ignore:` silences it, which is exactly how the current three
imports got in.

### D4 — Fixtures

Reuse the fixture repo builder. Cases:
- material_ui-only tree passes
- prefixed import with an ignore comment fails and names the file and library
- cupertino export fails
- import under `test/` fails
- legacy import in `lib/l10n/x.dart` passes
- legacy import in `test/foo.mocks.dart` passes
- a listed but unreadable file is a tooling error

## Risks / Trade-offs

- [fcs 9 changes a theme value the spike did not dump] → D2 also pins sub-theme
  radius and scaffold colour. The manual check in task 4.3 covers the rest
  (open the app in light and dark, look at dialogs and inputs).
- [Text-field borders now react to state] → this matches fcs's intent; the old
  bridge dropped it. Visible only on focus or error. Accepted.
- [A dependency later needs `flutter_localizations`/legacy types in hand-written
  code] → the guard fails. Use the material_ui equivalent. There is no
  exception list by design.

## Migration Plan

One commit. Roll back by reverting it and running `flutter pub get`.

## Open Questions

None.
