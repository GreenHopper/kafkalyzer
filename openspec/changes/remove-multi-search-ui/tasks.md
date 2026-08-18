# Tasks: Remove Multi-Search from the UI

## 1. Remove the rail destination

- [ ] 1.1 In `lib/src/ui/main_layout.dart`, remove the "Multi-Search" `NavigationRailDestination` (icon `Icons.search_outlined`, label `l10n.multiSearch`) and the `1 => const MultiSearchView()` branch
- [ ] 1.2 Re-index the remaining `switch` branches so Consumer Lag → 1, Scripts → 2, Settings → 3
- [ ] 1.3 Remove the now-unused `import` of `multi_search_view.dart` from `main_layout.dart`
- [ ] 1.4 Run `dart analyze` on `lib/src/ui/` to confirm no unresolved references

## 2. Delete view-exclusive UI files

- [ ] 2.1 Verify with `grep -rln` that each of the following is referenced only by already-deleted or about-to-be-deleted files, then delete it: `lib/src/features/search/multi_search_view.dart`
- [ ] 2.2 Delete `lib/src/features/search/presentation/widgets/active_streams_list.dart` (verify only `multi_search_view.dart` referenced it)
- [ ] 2.3 Delete `lib/src/features/search/presentation/widgets/search_results_view.dart` (verify only `multi_search_view.dart` referenced it)
- [ ] 2.4 Delete `lib/src/features/search/presentation/widgets/search_stream_form.dart` (verify only `multi_search_view.dart` referenced it)
- [ ] 2.5 Delete `lib/src/features/search/presentation/widgets/search_discovery_sidebar.dart` (verify it is unreferenced)
- [ ] 2.6 Confirm the kept files are untouched: `search_stream_configuration.dart`, `start_condition_configuration.dart`, `end_condition_configuration.dart`, `topic_selection_dialog.dart`, `multi_search_controller.dart`, `search_json_serializer.dart`
- [ ] 2.7 Run `dart analyze` on the whole `lib/` to confirm no dangling imports

## 3. Localization cleanup

- [ ] 3.1 Identify l10n keys whose only `l10n.<key>` usages were in the deleted files (e.g. `multiSearch`, `multiStreamConfig`)
- [ ] 3.2 Remove those orphaned keys from `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, keeping every key still used by the Explorer/scripting/settings UIs
- [ ] 3.3 Regenerate localizations (`flutter gen-l10n`) so the `app_localizations*.dart` files are consistent
- [ ] 3.4 Run `dart analyze` to confirm no remaining reference to a removed l10n key

## 4. Update tests

- [ ] 4.1 In `test/src/ui/main_layout_test.dart`, update the stale comment about the Settings destination index (now 3) and add an assertion that the Multi-Search destination/label is absent
- [ ] 4.2 Run `flutter test test/src/ui/main_layout_test.dart` and confirm it passes

## 5. Final verification

- [ ] 5.1 Run `flutter analyze` (or `dart analyze`) on the project and resolve any new issues
- [ ] 5.2 Run the full `flutter test` suite and confirm all existing tests pass (Explorer, scripting, consumer-lag, settings)
- [ ] 5.3 Confirm no references to the deleted files remain anywhere in `lib/` or `test/`
- [ ] 5.4 Verify `openspec validate --change remove-multi-search-ui` passes
