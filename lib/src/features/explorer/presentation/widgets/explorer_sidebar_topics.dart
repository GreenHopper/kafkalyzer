import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/domain/topic_list_query.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_list_item.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';
import 'package:kafkalyzer/src/ui/widgets/error_banner.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/topic_list_refresh_ticker.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';

/// Sidebar panel for one connected cluster: topic count and list actions, the
/// filter chips and text field, and the topic list itself.
class ExplorerTopicPanel extends StatefulWidget {
  final ActiveConnectionController activeController;
  final TopicController topicController;
  final SchemaController schemaController;
  final VoidCallback onQuickJump;

  const ExplorerTopicPanel({
    super.key,
    required this.activeController,
    required this.topicController,
    required this.schemaController,
    required this.onQuickJump,
  });

  @override
  State<ExplorerTopicPanel> createState() => _ExplorerTopicPanelState();
}

class _ExplorerTopicPanelState extends State<ExplorerTopicPanel> {
  ActiveConnectionController get activeController => widget.activeController;
  TopicController get topicController => widget.topicController;
  SchemaController get schemaController => widget.schemaController;

  late final TextEditingController _filterController = TextEditingController(
    text: widget.topicController.topicFilter,
  );

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _topicsControls(context, l10n),
        _topicFilter(context, l10n),
        _topicList(context),
      ],
    );
  }

  Widget _topicsControls(BuildContext context, AppLocalizations l10n) {
    final activeProfile = activeController.activeProfile!;
    final view = topicController.topicListView(activeController.activeProfile);
    final totalCount = topicController.getTopics(activeProfile)?.length ?? 0;
    final fetchedAt = topicController.fetchedAt(activeProfile);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${l10n.topics} (${view.visibleTopics.length}/$totalCount)",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (fetchedAt != null)
                      _TopicListAgeLabel(fetchedAt: fetchedAt),
                  ],
                ),
              ),
              PopupMenuButton<TopicSortOrder>(
                key: const Key('topic_sort_menu_button'),
                tooltip: l10n.topicListSortTooltip,
                icon: const Icon(Icons.sort, size: 16),
                padding: EdgeInsets.zero,
                initialValue: topicController.topicSortOrder,
                onSelected: topicController.setTopicSortOrder,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: TopicSortOrder.name,
                    child: Text(l10n.topicListSortName),
                  ),
                  PopupMenuItem(
                    value: TopicSortOrder.partitions,
                    child: Text(l10n.topicListSortPartitions),
                  ),
                  PopupMenuItem(
                    value: TopicSortOrder.health,
                    child: Text(l10n.topicListSortHealth),
                  ),
                ],
              ),
              IconButton(
                key: const Key('topic_group_by_prefix_button'),
                icon: Icon(
                  topicController.groupTopicsByPrefix
                      ? Icons.account_tree
                      : Icons.account_tree_outlined,
                  size: 16,
                  color: topicController.groupTopicsByPrefix
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: l10n.topicListGroupByPrefixTooltip,
                padding: EdgeInsets.zero,
                onPressed: topicController.toggleGroupByPrefix,
              ),
              IconButton(
                key: const Key('explorer_quick_jump_button'),
                icon: const Icon(Icons.bolt, size: 16),
                tooltip: l10n.quickJumpTitle,
                padding: EdgeInsets.zero,
                onPressed: () => widget.onQuickJump(),
              ),
              IconButton(
                key: const Key('explorer_refresh_topics_button'),
                icon: const Icon(Icons.refresh, size: 16),
                tooltip: l10n.refreshTooltip,
                padding: EdgeInsets.zero,
                onPressed:
                    activeController.isConnecting ||
                        topicController.isLoading(activeProfile)
                    ? null
                    : () {
                        topicController.fetchTopics(activeProfile, force: true);
                        if (!schemaController.isLoading(activeProfile)) {
                          schemaController.fetchSchemas(
                            activeProfile,
                            force: true,
                          );
                        }
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topicFilter(BuildContext context, AppLocalizations l10n) {
    final view = topicController.topicListView(activeController.activeProfile);
    if (_filterController.text != topicController.topicFilter) {
      _filterController.value = TextEditingValue(
        text: topicController.topicFilter,
        selection: TextSelection.collapsed(
          offset: topicController.topicFilter.length,
        ),
      );
    }

    final modeLabel = switch (topicController.topicFilterMode) {
      TopicFilterMode.substring => l10n.topicListFilterModeSubstring,
      TopicFilterMode.glob => l10n.topicListFilterModeGlob,
      TopicFilterMode.regex => l10n.topicListFilterModeRegex,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: Text(l10n.internalTopicsFilter),
                selected: topicController.showInternalTopics,
                onSelected: (val) =>
                    topicController.toggleShowInternalTopics(val),
                visualDensity: VisualDensity.compact,
              ),
              FilterChip(
                label: Text(l10n.streamTopicsFilter),
                selected: topicController.showStreamTopics,
                onSelected: (val) =>
                    topicController.toggleShowStreamTopics(val),
                visualDensity: VisualDensity.compact,
              ),
              if (view.totalHidden > 0)
                Tooltip(
                  message: l10n.topicListHiddenTooltip(
                    view.hiddenByInternal,
                    view.hiddenByStream,
                    view.hiddenByText,
                  ),
                  child: ActionChip(
                    key: const Key('topic_hidden_count_chip'),
                    avatar: const Icon(Icons.visibility_off_outlined, size: 14),
                    label: Text(
                      '${l10n.topicListHiddenCount(view.totalHidden)} · ${l10n.topicListShowAll}',
                    ),
                    onPressed: () {
                      _filterController.clear();
                      topicController.showAllTopics();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (topicController.unhealthyTopicsOnly)
                InputChip(
                  key: const Key('topic_unhealthy_only_chip'),
                  avatar: Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(
                    l10n.topicListUnhealthyOnlyChip(
                      topicController
                          .topics(activeController.activeProfile)
                          .length,
                    ),
                  ),
                  onDeleted: topicController.clearUnhealthyTopicsOnly,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('topic_filter_text_field'),
            controller: _filterController,
            decoration: InputDecoration(
              hintText: l10n.filterTopics,
              errorText: view.patternError != null
                  ? l10n.topicListInvalidPattern
                  : null,
              prefixIcon: PopupMenuButton<TopicFilterMode>(
                key: const Key('topic_filter_mode_button'),
                tooltip: l10n.topicListFilterModeTooltip,
                initialValue: topicController.topicFilterMode,
                onSelected: topicController.setTopicFilterMode,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: TopicFilterMode.substring,
                    child: Text(l10n.topicListFilterModeSubstring),
                  ),
                  PopupMenuItem(
                    value: TopicFilterMode.glob,
                    child: Text(l10n.topicListFilterModeGlob),
                  ),
                  PopupMenuItem(
                    value: TopicFilterMode.regex,
                    child: Text(l10n.topicListFilterModeRegex),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        modeLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              suffixIcon: _filterController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      tooltip: l10n.clear,
                      onPressed: () {
                        _filterController.clear();
                        topicController.updateTopicFilter("");
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              isDense: true,
            ),
            onChanged: (value) {
              topicController.updateTopicFilter(value);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _topicList(BuildContext context) {
    final activeProfile = activeController.activeProfile!;
    final hasCached = topicController.hasCachedTopics(activeProfile);
    final isLoading =
        activeController.isConnecting ||
        topicController.isLoading(activeProfile);

    if (isLoading && !hasCached) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    final topicError = topicController.errorFor(activeProfile);
    final l10n = AppLocalizations.of(context)!;
    if (topicError != null && !hasCached) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ErrorBanner(
              title: l10n.topicsLoadFailedTitle,
              detail: topicError,
              onRetry: () =>
                  topicController.fetchTopics(activeProfile, force: true),
            ),
          ),
        ),
      );
    }

    final view = topicController.topicListView(activeController.activeProfile);
    final rows = view.rows;
    final failureGroups = view.failureGroups;
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          if (isLoading && hasCached)
            const LinearProgressIndicator(
              key: Key('topic_list_refresh_progress'),
              minHeight: 2,
            ),
          if (topicError != null && hasCached)
            Container(
              key: const Key('topic_list_refresh_error_notice'),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.topicListRefreshFailedNotice(topicError),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        topicController.fetchTopics(activeProfile, force: true),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          if (topicController.topicPreferencesUnreadable ||
              topicController.topicPreferencesWriteBlocked)
            Container(
              key: const Key('topic_list_prefs_notice'),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      topicController.topicPreferencesWriteBlocked
                          ? l10n.topicListPrefsWriteBlockedNotice
                          : l10n.topicListPrefsUnreadableNotice,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    tooltip: l10n.close,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    onPressed: topicController.dismissTopicPreferencesNotice,
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                switch (row) {
                  case FavouritesHeaderRow():
                    return Padding(
                      key: const Key('topic_favourites_section_header'),
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${l10n.topicListFavouritesSection} (${row.count})',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  case TopicGroupHeaderRow():
                    return InkWell(
                      key: Key('topic_group_header_${row.prefix}'),
                      onTap: () =>
                          topicController.toggleGroupCollapsed(row.prefix),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                        child: Row(
                          children: [
                            Icon(
                              row.isCollapsed
                                  ? Icons.chevron_right
                                  : Icons.expand_more,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                row.prefix,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              '(${row.count})',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  case TopicItemRow():
                    final topic =
                        row.topic ??
                        TopicMetadata(
                          name: row.name,
                          partitionCount: -1,
                          replicationFactor: -1,
                        );
                    final isSelected = activeController.openTopics.any(
                      (t) =>
                          t.topic.name == row.name &&
                          t.profile.name == activeProfile.name,
                    );
                    return TopicListItem(
                      topic: topic,
                      isSelected: isSelected,
                      highlightQuery: topicController.topicFilter,
                      highlightPattern: view.highlightPattern,
                      isFavourite: row.isFavourite,
                      isMissingFavourite: row.isMissingFavourite,
                      onToggleFavourite: () =>
                          topicController.toggleFavourite(row.name),
                      associatedFailureTopics: row.isMissingFavourite
                          ? null
                          : failureGroups[row.name],
                      onSelectFailureTopic: (childTopicName) {
                        openTopicByNameWithFeedback(
                          controller: activeController,
                          profile: activeProfile,
                          topicName: childTopicName,
                          messenger: ScaffoldMessenger.maybeOf(context),
                          l10n: l10n,
                        );
                      },
                      onTap: row.isMissingFavourite
                          ? () => openTopicByNameWithFeedback(
                              controller: activeController,
                              profile: activeProfile,
                              topicName: row.name,
                              messenger: ScaffoldMessenger.maybeOf(context),
                              l10n: l10n,
                            )
                          : () => activeController.setActiveTopic(
                              topic,
                              activeProfile,
                            ),
                      onDoubleTap: row.isMissingFavourite
                          ? null
                          : () => activeController.streamTopicWithDefaults(
                              topic,
                              activeProfile,
                            ),
                      onOpenInNewTab: row.isMissingFavourite
                          ? null
                          : () => activeController.openTopic(
                              topic: topic,
                              profile: activeProfile,
                              forceNew: true,
                            ),
                      clusterProfile: activeProfile,
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicListAgeLabel extends StatefulWidget {
  final DateTime fetchedAt;

  const _TopicListAgeLabel({required this.fetchedAt});

  @override
  State<_TopicListAgeLabel> createState() => _TopicListAgeLabelState();
}

class _TopicListAgeLabelState extends State<_TopicListAgeLabel> {
  final TopicListRefreshTicker _ticker = TopicListRefreshTicker();

  @override
  void initState() {
    super.initState();
    _ticker.start(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(widget.fetchedAt);
    final label = diff.inMinutes < 1
        ? l10n.topicListUpdatedJustNow
        : diff.inMinutes < 60
        ? l10n.topicListUpdatedMinutesAgo(diff.inMinutes)
        : l10n.topicListUpdatedHoursAgo(diff.inHours);

    return Text(
      label,
      key: const Key('topic_list_age_label'),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
