# Proposal

## Why

Recent diagnostics features added partition replication health (leader, replicas, ISR) and per-message schema provenance. However, their current UI/UX integration introduces severe layout and readability defects:

1. **Replication Status wastes primary screen space**: In the topic detail view, `TopicPartitionHealthTable` inserts a static, full-width container between the topic header and the search bar/message view. Even when topics are completely healthy (the vast majority of the time), this pushes down the search bar and message timeline by 60–140px, disrupting the visual hierarchy of the message browsing experience.
2. **Schema provenance bloats every message card**: In the message timeline, `MessageMetadataCard` repeats multi-line strings for every message—including negative information (`Schlüssel: kein Registry-Schema`) and verbose subjects (`Wert: delivery-vehicle-positions-value v1 (#9)`). Because 99.9% of messages in a topic share the exact same schema, this duplicates identical text hundreds of times, doubling the card height and adding visual clutter without informative value.

This change streamlines the UI/UX integration of both features so they fit naturally into Kafkalyzer's Material 3 desktop design without cluttering the interface or wasting viewport space.

## What Changes

- **Streamlined Partition Health Access**:
  - Remove the always-expanded, full-width partition table banner above the topic messages search bar.
  - Make partition replication details accessible on demand from the topic header:
    - Make the header's Partitions / RF tags interactive (or add a dedicated compact health chip/button) that opens a polished **Partition Health Dialog / Popover** displaying the partition breakdown (partition #, leader endpoint, replica set, ISR set).
    - If a topic has unhealthy partitions (under-replicated or leaderless), display a clear, clickable warning tag in the header tags that immediately opens the partition health breakdown with problematic rows highlighted.
  - Embed the full partition health table as a native section inside the **Topic-Analyse** (Topic Analysis) tab alongside the Partition Balance view, placing deep diagnostic metadata right where diagnostic tooling belongs.
- **Compact & Clean Schema Provenance in Message Cards**:
  - Remove verbose multi-line schema text and negative "no schema" strings (`Schlüssel: kein Registry-Schema`) from `MessageMetadataCard`.
  - In `MessageMetadataCard`, represent schema provenance compactly: if a schema exists, display a subtle inline pill/indicator (e.g. `#9` or `v1 (#9)`) alongside the technical details row (`P: 0 | O: 119999`) or as a compact chip, only when a schema is actually present.
  - Maintain full schema provenance, subject names, versions, IDs, and click-to-open schema inspector navigation inside the `MessageInspectorPanel` when a message is selected.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `partition-health-visibility`: Modify presentation requirements so partition replication status is accessible on-demand from the header (modal/popover) and in the Topic Analysis view, rather than occupying a permanent, fixed inline table above the message search bar.
- `message-schema-provenance`: Refine message card representation so individual timeline message cards show compact schema provenance without multi-line subject text or negative "no schema" noise, preserving detailed interactive provenance for the inspector panel.

## Impact

- **Flutter / Dart UI**:
  - `lib/src/features/topic/topic_detail_view.dart`: Replace the static `TopicPartitionHealthTable` in the messages view with header-driven interactive opening (and warning banner only if unhealthy).
  - `lib/src/features/topic/presentation/widgets/topic_partition_health_dialog.dart` (or popover): Modal or dialog wrapper for partition health breakdown.
  - `lib/src/features/topic/presentation/widgets/analysis/topic_analysis_view.dart`: Integrate partition health into the topic analysis tab.
  - `lib/src/ui/messages/widgets/message_metadata_card.dart`: Eliminate multi-line and negative "no schema" text; render compact inline schema indicator.
  - `lib/src/ui/messages/widgets/message_inspector_panel.dart`: Retain rich schema provenance and inspector navigation.
- **Localization**:
  - Ensure localized labels in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` match any new dialog/chip titles.
- **Tests**:
  - Update `test/src/features/topic/topic_detail_view_test.dart` and `test/src/ui/messages/widgets/message_metadata_card_test.dart` to assert the streamlined presentation and interaction.
