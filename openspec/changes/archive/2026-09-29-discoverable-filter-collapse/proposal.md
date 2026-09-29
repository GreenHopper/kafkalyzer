## Why

The Search Configuration filter panel already expands and collapses via an `ExpansionTile`, but the default chevron is replaced by a static `Icons.tune` trailing icon. Users treat that icon as a settings control rather than a collapse toggle, so they do not realize they can reclaim vertical space for message results. Making the expand/collapse affordance obvious improves scan-time UX without changing filter behavior.

## What Changes

- Restore a clear expand/collapse visual affordance on the Search Configuration header (chevron that reflects expanded vs collapsed state).
- Keep the header fully clickable to toggle expansion, with an accessible tooltip that states collapse/expand intent.
- Optionally retain a secondary visual cue that the section is a filter/settings area, without replacing the chevron.
- Localize the Search Configuration title and any new tooltips via `AppLocalizations`.
- Add widget tests that verify the panel can be collapsed and re-expanded from the header affordance.

## Capabilities

### New Capabilities
- `search-configuration-panel`: Collapsible search filter panel on the topic search view, including discoverable expand/collapse affordances and header interaction.

### Modified Capabilities
- (none)

## Impact

- Dart/Flutter UI: `lib/src/features/topic/topic_detail_view.dart` (`_buildSettings` / `ExpansionTile` trailing and header).
- Localization: `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb` (and generated localization files).
- Tests: widget coverage under `test/src/features/topic/` for expand/collapse discoverability and behavior.
- No Rust, bridge, or Kafka API changes.
