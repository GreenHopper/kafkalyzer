# Design

## Context

In `ExplorerView`, the topic sidebar renders a list of topics for the currently active cluster profile using `TopicListItem`. Today, each topic card has `contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)` plus an internal `Wrap` of up to 6 `TopicTag` widgets and an `OutlinedButton`, yielding an item height of 95–110px. This allows only ~3.5 topics to fit within standard vertical viewports.

Above the topic list, `_buildSidebarTopicFilter` renders two separate `Row`s each containing a `Switch` widget for toggling `showInternalTopics` and `showStreamTopics`, consuming ~80px of vertical space before the topic list even begins.

## Goals / Non-Goals

**Goals:**
- Compact `TopicListItem` layout with an overall height of ~44–48px, allowing 8–10 topics to be visible simultaneously.
- Topic name segmentation: Muted/secondary text style for the namespace prefix (all segments preceding the final `.`) and bold primary text for the leaf topic name.
- Streamline on-card metadata to at most two micro-badges: compact partition count (`<N>P`) and schema format badge (`Avro`).
- Move secondary broker configuration tags (`RF`, `cleanup.policy`, `retention.ms`) into a responsive hover tooltip.
- Replace full-width `Switch` rows with a compact horizontal row of `FilterChip`s in `_buildSidebarTopicFilter`.
- Preserve all existing interactions: single-click selection, double-click instant streaming, and "open in new tab" icon button.
- Maintain full localization in English and German via `AppLocalizations`.

**Non-Goals:**
- Redesigning the cluster switcher sidebar or the `TopicDetailView` header.
- Modifying how topic metadata is retrieved from Kafka or Schema Registry.
- Adding hierarchical tree or folder-collapse navigation in the sidebar (the segmentation is purely visual for readability).

## Decisions

### 1. Topic Name Visual Hierarchy via `Text.rich`

Topic names in Kafka enterprise environments often follow dotted naming conventions (e.g. `com.company.division.service.event_name`). Displaying the entire string in uniform bold font creates visual noise and makes scanning for the actual event name difficult.

**Design:**
Create a helper function `(String prefix, String leaf) parseTopicNameSegments(String topicName)`:
- If `topicName` contains `.`: `prefix` is `topicName.substring(0, lastDotIndex + 1)` and `leaf` is `topicName.substring(lastDotIndex + 1)`.
- If no `.` exists: `prefix` is empty and `leaf` is `topicName`.

Render with `Text.rich`:
```dart
Text.rich(
  TextSpan(
    children: [
      if (prefix.isNotEmpty)
        TextSpan(
          text: prefix,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
            fontWeight: FontWeight.normal,
          ),
        ),
      TextSpan(
        text: leaf,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurface,
        ),
      ),
    ],
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
)
```

*Alternatives considered:*
- Multi-line rendering (prefix on line 1, leaf on line 2): Rejected because it doubles vertical height, defeating the high-density goal.
- Folder-tree view: Deferred to a future capability; requires hierarchical tree state and node expansion logic that increases complexity beyond the immediate UX goal.

### 2. Micro-Badges & Responsive Tooltip

Rather than a wrap of 6 full-size tags, display micro-badges directly in the row:
- **Partition Badge:** A compact badge displaying `${topic.partitionCount}P` (e.g., `12P`).
- **Schema Badge:** If an Avro schema is detected via `getIt<SchemaController>()`, render a compact `Avro` chip.
- **Hover Tooltip:** Wrap the `ListTile` or card in a `Tooltip` with desktop-optimized responsiveness (`waitDuration: const Duration(milliseconds: 350)`):
  - Formats: `Partitions: 12 • Replication Factor: 3 • Retention: 90.0d • Cleanup: delete`

### 3. Compact Filter Chips in Sidebar Header

In `ExplorerView._buildSidebarTopicFilter`:
Replace the two vertical `Row(children: [Text, Switch])` with a single row of compact `FilterChip` widgets:
```dart
Wrap(
  spacing: 8,
  runSpacing: 4,
  children: [
    FilterChip(
      label: Text(l10n.internalTopicsFilter),
      selected: activeController.showInternalTopics,
      onSelected: (val) => activeController.toggleShowInternalTopics(val),
      visualDensity: VisualDensity.compact,
    ),
    FilterChip(
      label: Text(l10n.streamTopicsFilter),
      selected: activeController.showStreamTopics,
      onSelected: (val) => activeController.toggleShowStreamTopics(val),
      visualDensity: VisualDensity.compact,
    ),
  ],
)
```
This saves ~40px of vertical space, pushing the topic list higher into immediate visibility.

## Risks / Trade-offs

- **Very long leaf names:** If a topic name has a very long prefix and leaf, single-line text could truncate the leaf name. Adding `maxLines: 1` with `overflow: TextOverflow.ellipsis` ensures graceful truncation, while the tooltip preserves the full name and config details.
- **Click targets:** Reducing tile height to ~44–48px respects desktop pointer ergonomics (recommended minimum is 36–40px on desktop systems).
