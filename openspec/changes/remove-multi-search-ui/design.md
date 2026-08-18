# Design: Remove Multi-Search from the UI

## Context

The app has two UI surfaces for search: the standalone `MultiSearchView` (rail destination #2) and the search functionality embedded in the Topic Explorer (`topic_detail_view.dart`). Both drive the same engine — `MultiSearchController` in `lib/src/features/search/presentation/controllers/` — and reuse the same configuration widgets (`start_condition_configuration`, `end_condition_configuration`, `topic_selection_dialog`, `search_stream_configuration`). The scripting feature (`ScriptRunner`) also drives `MultiSearchController` directly and reuses `search_stream_configuration` and `topic_selection_dialog` in `script_step_editor.dart`. See proposal.md for motivation.

Constraint: nothing outside `MultiSearchView` may lose a reference — `dart analyze` and the existing test suite must stay green.

## Goals / Non-Goals

**Goals:**

- Remove the dedicated Multi-Search rail destination and all UI code reachable only through it.
- Keep the shared search engine and shared configuration widgets fully intact.
- Keep the app building and all existing tests passing with no behavior change for Explorer searches or scripted searches.

**Non-Goals:**

- No changes to `MultiSearchController`, `search_json_serializer.dart`, or the Rust backend/bridge.
- No changes to the Explorer view's search UI or the scripting feature.
- No new features; this is a pure removal.

## Decisions

### 1. Keep `MultiSearchController` and the shared widgets; delete only view-exclusive UI files

**Rationale:** Dependency analysis shows two clean groups:

| File | Referenced by (outside itself) | Disposition |
| --- | --- | --- |
| `multi_search_view.dart` | `main_layout.dart` only | **Delete** |
| `active_streams_list.dart` | `multi_search_view.dart` only | **Delete** |
| `search_results_view.dart` | `multi_search_view.dart` only | **Delete** |
| `search_stream_form.dart` | `multi_search_view.dart` only | **Delete** |
| `search_discovery_sidebar.dart` | nothing (dead code) | **Delete** |
| `search_stream_configuration.dart` | `script_step_editor.dart` (and deleted form) | **Keep** |
| `start_condition_configuration.dart` | `topic_detail_view.dart` | **Keep** |
| `end_condition_configuration.dart` | `topic_detail_view.dart` | **Keep** |
| `topic_selection_dialog.dart` | `script_step_editor.dart` | **Keep** |
| `multi_search_controller.dart` | `script_runner.dart`, `topic_detail_view.dart`, `settings_view.dart`, DI | **Keep** |
| `search_json_serializer.dart` | `script_runner.dart` | **Keep** |

**Alternative considered:** delete the whole `features/search` tree. Rejected — it would break `ScriptRunner` (core of the scripting feature) and the Explorer's search configuration.

### 2. Re-index the rail instead of leaving a gap

`MainLayout` switches on `_selectedIndex` (0…4). Remove the Multi-Search `NavigationRailDestination` and its `1 => MultiSearchView()` branch, then shift: Consumer Lag → 1, Scripts → 2, Settings → 3.

**Alternative considered:** keep the numeric mapping and skip index 1. Rejected — fragile and confusing; the `switch` expression already makes the shift a two-line edit.

### 3. l10n cleanup limited to keys referenced only by deleted widgets

Remove keys whose only `l10n.<key>` usages are in the deleted files (e.g. the `multiSearch` rail label, `multiStreamConfig`, and any other orphaned keys — to be verified with a usage grep during implementation). Keys still used by the Explorer/scripting UIs stay. Regenerate `flutter gen-l10n` artifacts (`app_localizations*.dart`) after editing the `.arb` files.

**Alternative considered:** leave all keys. Rejected — dead translation strings are exactly the kind of cruft this change exists to remove.

### 4. Test updates

`test/src/ui/main_layout_test.dart` taps the Settings destination **by icon** (`Icons.settings_outlined`), so it keeps working; only the stale comment ("5th destination, index 4") needs updating, plus a new assertion that the Multi-Search destination is absent (per the `main-navigation` spec scenario). No test references the deleted widgets (verified by grep).

## Risks / Trade-offs

- [A shared widget is accidentally deleted] → Mitigation: the keep/delete table above is derived from a full reference grep; re-run `grep -rln <file> lib test` before each deletion, then `dart analyze`.
- [Removing an l10n key still used by a kept widget causes a compile break] → Mitigation: verify each key's usages before removal; `dart analyze` catches any `l10n.<key>` reference; `flutter test` as final gate.
- [Users expect the Multi-Search rail entry] → Trade-off accepted per the change request; all search capabilities remain in the Explorer view.
- [Stale imports in `main_layout.dart` or DI] → `main_layout.dart` imports `multi_search_view.dart` directly — remove that import in the same edit; the `MultiSearchController` DI registration in `dependency_injection.dart` stays (still required by scripting/settings).

## Migration Plan

Single small commit: edit `main_layout.dart`, delete the five files, clean l10n keys, regenerate localizations, update the test, run `dart analyze` + `flutter test`. Rollback: revert the commit — no data or state migration involved.
