## 1. UI & State Refinements

- [ ] 1.1 Set the default `_refreshIntervalSeconds` to `30` in `_ConsumerLagViewState`.
- [ ] 1.2 Implement `_previousOffsets` and `_groupDeltas` in `_ConsumerLagViewState`.
- [ ] 1.3 Calculate committed offset deltas upon successful single group lag query completions.
- [ ] 1.4 Clear cached previous offsets and deltas when active profile changes.
- [ ] 1.5 Add the "Processed" / "Abarbeitung" column to the main table header and body.
- [ ] 1.6 Implement sorting on the new "Processed" column.

## 2. Localization & Formatting

- [ ] 2.1 Add localized number formatter helper `formatNum` in `consumer_lag_view.dart`, `group_details_view.dart`, and `topic_partition_table.dart`.
- [ ] 2.2 Localize all group metrics, header titles, search results found badges, and total lag values.
- [ ] 2.3 Localize partition details (log end offsets, committed offsets, and lags).

## 3. Background Processing Control

- [ ] 3.1 Verify timer cancellation in `dispose()`.
- [ ] 3.2 Add `mounted` checks in all queue workers (`_processNextLagQuery` and async returns) to prevent background loop leakage.
- [ ] 3.3 Add connection profile checks on returned async queries to prevent outdated/cross-profile updates.

## 4. Testing & Verification

- [ ] 4.1 Update mock data/profiles in `consumer_lag_view_test.dart` to support new requirements.
- [ ] 4.2 Write tests verifying default refresh interval is 30s.
- [ ] 4.3 Write tests verifying that offset deltas are calculated and displayed correctly.
- [ ] 4.4 Write tests verifying localized number formatting.
- [ ] 4.5 Verify widget unmounting successfully stops the background queue and timer.
