# Proposal

## Why

When inspecting duplicate messages in the topic duplicate analysis dialog, clicking "In Nachrichten anzeigen" (Show in Messages) currently navigates to the Messages view while only populating the sample partition and sample offset. The quick filter input remains empty, no filter criteria (search scope, filter type) are applied, and scan mode remains set to latest messages. Consequently, the user is presented with 200 arbitrary messages from that single partition rather than isolated occurrences of the duplicated message across the topic, failing to provide the intended diagnostic insight.

## What Changes

- **Duplicate Navigation Context**: Expand navigation parameters passed from duplicate inspection views (`DuplicateDetailsDialog`, `DuplicateAnalysisView`, `TopicAnalysisView`) to include duplicate key, payload preview, occurrence count, and detection scope.
- **Filter Criteria Pre-population**: When navigating from duplicate analysis to the messages view:
  - Populate the quick filter search term: use `key` when present, or an extracted payload preview term/content when unkeyed.
  - Set the appropriate `SearchScope` (`SearchScope.key` for keyed duplicates, `SearchScope.value` for payload-only duplicates).
  - Set `FilterType.exact` for key matches or `FilterType.contains` for payload substring matches.
- **Topic-Wide Duplicate Scan**:
  - Clear partition restriction so consumption scans across all topic partitions where duplicates may reside, instead of isolating a single sample partition.
  - Set `TopicScanMode.offsetEarliest` and starting strategy `MultiSearchStartStrategy.earliest` (offset 0) to stream and filter messages from the beginning of the topic partitions where the analysis detected duplicates.
  - Ensure the message result limit is sufficient to capture all detected occurrences (e.g. at least the duplicate count or standard batch size).
- **Secondary Sample Coordinate Jump**: Provide clear user options in the duplicate details dialog: filtering all duplicate occurrences across the topic, or jumping directly to the sample partition and offset.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `topic-duplicate-detection`: Update navigation and presentation requirements so that navigating from duplicate analysis to the messages view populates filter criteria, configures topic-wide earliest scanning, and isolates duplicate occurrences.

## Impact

- **Affected Code**:
  - `lib/src/features/topic/presentation/widgets/analysis/duplicate_details_dialog.dart`
  - `lib/src/features/topic/presentation/widgets/analysis/duplicate_analysis_view.dart`
  - `lib/src/features/topic/presentation/widgets/analysis/topic_analysis_view.dart`
  - `lib/src/features/topic/topic_detail_view.dart`
  - `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` for localized button labels and tooltips.
- **APIs & Dependencies**: No breaking changes to Rust backend or bridge APIs; changes are confined to Flutter UI navigation flow and state orchestration.
