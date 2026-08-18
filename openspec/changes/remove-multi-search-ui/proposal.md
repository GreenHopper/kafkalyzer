# Proposal: Remove Multi-Search from the UI

## Why

The standalone "Multi-Search" view in the main navigation rail duplicates functionality that is now already implemented in the Explorer view (topic-based message search with the same start/end-condition configuration widgets and the same search engine underneath). Maintaining two UIs for one capability creates redundancy, inconsistent UX, and extra code to keep in sync. Removing the standalone view simplifies the app surface.

## What Changes

- Remove the "Multi-Search" destination from the main `NavigationRail` in `lib/src/ui/main_layout.dart`; remaining destinations (Consumer Lag, Scripts, Settings) shift one index lower.
- Delete the standalone Multi-Search presentation code that is only reachable from that view:
  - `lib/src/features/search/multi_search_view.dart`
  - `lib/src/features/search/presentation/widgets/active_streams_list.dart`
  - `lib/src/features/search/presentation/widgets/search_results_view.dart`
  - `lib/src/features/search/presentation/widgets/search_stream_form.dart`
  - `lib/src/features/search/presentation/widgets/search_discovery_sidebar.dart` (currently unreferenced dead code)
- Keep all shared search infrastructure that the Explorer view and the scripting feature depend on:
  - `MultiSearchController` (`lib/src/features/search/presentation/controllers/multi_search_controller.dart`) — used by `ScriptRunner`, `TopicDetailView`, and `SettingsView`
  - `search_json_serializer.dart` — used by `ScriptRunner`
  - Shared configuration widgets `search_stream_configuration.dart`, `start_condition_configuration.dart`, `end_condition_configuration.dart`, `topic_selection_dialog.dart` — used by the Topic Explorer and the scripting step editor
- Clean up l10n keys that become unused as a result (e.g. the `multiSearch` navigation label), keeping keys still used by the Explorer/scripting UIs.
- Update `test/src/ui/main_layout_test.dart` to match the new rail layout.
- No changes to the Rust backend, the bridge API, or the search/streaming engine.

## Capabilities

### New Capabilities

- `main-navigation`: Specifies the app's top-level navigation surface — which views are exposed in the main rail (Explorer, Consumer Lag, Scripts, Settings) and that cross-topic search functionality is provided through the Explorer view rather than a dedicated Multi-Search destination.

### Modified Capabilities
<!-- None: no existing spec-level requirements change. The search engine behavior used by the Explorer and scripting remains unchanged. -->

## Impact

- **Affected code**: `lib/src/ui/main_layout.dart`, the five deleted files under `lib/src/features/search/` listed above, `lib/l10n/*.arb` (removal of now-unused keys), `test/src/ui/main_layout_test.dart`.
- **Unaffected**: `MultiSearchController`, `search_json_serializer.dart`, the four shared configuration widgets, `ScriptRunner`, `TopicDetailView`, `SettingsView`, the Rust backend, and all existing tests of the scripting/topic features (they do not reference the deleted widgets).
- **Users**: The "Multi-Search" rail entry disappears; all of its capabilities remain available via the Explorer view. Scripts and Explorer searches continue to work exactly as before.
- **Breaking changes**: None — this is a UI consolidation, not a loss of functionality.

## Assumptions

- "Remove from the UI" means removing the standalone navigation destination and its dedicated view widgets only. The underlying `MultiSearchController` search engine stays because `ScriptRunner` (scripting) and the Topic Explorer depend on it; removing it would break those features.
- l10n keys are removed only when they are referenced exclusively by the deleted widgets.
