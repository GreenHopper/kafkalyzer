import 'dart:async';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:watch_it/watch_it.dart';
import 'package:kafkalyzer/src/features/cluster/domain/connection_error.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/topic/domain/topic_list_query.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/navigation/widgets/quick_jump_dialog.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/schema_viewer_dialog.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/subject_browser_list.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/ui/shortcuts/app_shortcuts.dart';
import 'package:kafkalyzer/src/ui/widgets/error_banner.dart';

import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/topic_detail_view.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_list_item.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';
import 'package:kafkalyzer/src/features/topic/utils/dlq_topic_detector.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/environment_tag.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/insecure_tls_badge.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/explorer_onboarding_view.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/cluster_overview_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExplorerView extends WatchingStatefulWidget {
  const ExplorerView({super.key});

  static const String sidebarCollapsedPrefKey = 'explorer_sidebar_collapsed';
  static const String sidebarWidthPrefKey = 'explorer_sidebar_width';
  static const double defaultSidebarWidth = 360.0;
  static const double minSidebarWidth = 260.0;
  static const double maxSidebarWidth = 700.0;

  @override
  State<ExplorerView> createState() => _ExplorerViewState();
}

enum _SidebarBrowseMode { topics, subjects }

class _ExplorerViewState extends State<ExplorerView> {
  late TextEditingController _filterController;
  _SidebarBrowseMode _browseMode = _SidebarBrowseMode.topics;
  final TextEditingController _clusterFilterController =
      TextEditingController();
  String _clusterFilterQuery = '';
  final ScrollController _tabScrollController = ScrollController();
  bool _isSidebarCollapsed = false;
  double _sidebarWidth = ExplorerView.defaultSidebarWidth;

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController(
      text: getIt<ActiveConnectionController>().topicFilter,
    );
    _loadSidebarPreference();
  }

  Future<void> _loadSidebarPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isSidebarCollapsed =
          prefs.getBool(ExplorerView.sidebarCollapsedPrefKey) ?? false;
      _sidebarWidth =
          (prefs.getDouble(ExplorerView.sidebarWidthPrefKey) ??
                  ExplorerView.defaultSidebarWidth)
              .clamp(
                ExplorerView.minSidebarWidth,
                ExplorerView.maxSidebarWidth,
              );
    });
  }

  Future<void> _toggleSidebar() async {
    setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      ExplorerView.sidebarCollapsedPrefKey,
      _isSidebarCollapsed,
    );
  }

  @override
  void dispose() {
    _filterController.dispose();
    _clusterFilterController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  void _showQuickJumpDialog(BuildContext context) {
    final clusterController = getIt<ClusterListController>();
    final activeController = getIt<ActiveConnectionController>();
    showDialog<void>(
      context: context,
      builder: (ctx) => QuickJumpDialog(
        availableClusters: clusterController.clusters,
        currentCluster: activeController.activeProfile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final clusterController = watchIt<ClusterListController>();
    final activeController = watchIt<ActiveConnectionController>();
    final topicController = watchIt<TopicController>();

    final unrestored = activeController.unrestoredTopics;
    if (unrestored.isNotEmpty) {
      final snapshot = List<String>.from(unrestored);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        activeController.acknowledgeUnrestoredTopics();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.unrestoredTabsMessage(snapshot.length, snapshot.join(', ')),
            ),
          ),
        );
      });
    }
    final schemaController = watchIt<SchemaController>();

    return CallbackShortcuts(
      bindings: {
        ...AppShortcuts.toggleExplorerSidebar.bind(_toggleSidebar),
        ...AppShortcuts.quickJump.bind(() => _showQuickJumpDialog(context)),
      },
      child: Focus(
        autofocus: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSidebarArea(
              context,
              l10n,
              clusterController,
              activeController,
              topicController,
              schemaController,
            ),
            if (_isSidebarCollapsed)
              VerticalDivider(
                width: 1,
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            Expanded(
              child: _buildContent(
                context,
                l10n,
                clusterController,
                activeController,
                topicController,
                schemaController,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarArea(
    BuildContext context,
    AppLocalizations l10n,
    ClusterListController clusterController,
    ActiveConnectionController activeController,
    TopicController topicController,
    SchemaController schemaController,
  ) {
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.centerLeft,
        child: _isSidebarCollapsed
            ? _buildCollapsedSidebarRail(context, l10n)
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSidebar(
                    context,
                    l10n,
                    clusterController,
                    activeController,
                    topicController,
                    schemaController,
                  ),
                  _buildSidebarResizeHandle(context),
                ],
              ),
      ),
    );
  }

  Widget _buildSidebarResizeHandle(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        key: const Key('explorer_sidebar_resize_handle'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          setState(() {
            _sidebarWidth = (_sidebarWidth + details.delta.dx).clamp(
              ExplorerView.minSidebarWidth,
              ExplorerView.maxSidebarWidth,
            );
          });
        },
        onHorizontalDragEnd: (_) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(
            ExplorerView.sidebarWidthPrefKey,
            _sidebarWidth,
          );
        },
        child: Container(
          width: 6,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedSidebarRail(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return SizedBox(
      width: 40,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Column(
          children: [
            const SizedBox(height: 8),
            IconButton(
              key: const Key('explorer_expand_sidebar'),
              icon: const Icon(Icons.view_sidebar_outlined),
              tooltip: l10n.expandSidebar,
              onPressed: _toggleSidebar,
            ),
            const SizedBox(height: 8),
            IconButton(
              key: const Key('explorer_collapsed_quick_jump_button'),
              icon: const Icon(Icons.bolt, size: 20),
              tooltip: l10n.quickJumpTitle,
              onPressed: () => _showQuickJumpDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    AppLocalizations l10n,
    ClusterListController clusterController,
    ActiveConnectionController activeController,
    TopicController topicController,
    SchemaController schemaController,
  ) {
    return SizedBox(
      key: const Key('explorer_sidebar_container'),
      width: _sidebarWidth,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSidebarHeader(context, l10n),
            _buildSidebarClusterList(
              context,
              clusterController,
              activeController,
              topicController,
            ),
            if (activeController.activeProfile != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Semantics(
                  label: l10n.explorerModeSwitcherSemantics,
                  child: SegmentedButton<_SidebarBrowseMode>(
                    key: const Key('explorer_browse_mode_switcher'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment<_SidebarBrowseMode>(
                        value: _SidebarBrowseMode.topics,
                        label: Text(l10n.explorerModeTopics),
                        icon: const Icon(Icons.topic_outlined, size: 16),
                      ),
                      ButtonSegment<_SidebarBrowseMode>(
                        value: _SidebarBrowseMode.subjects,
                        label: Text(l10n.explorerModeSubjects),
                        icon: const Icon(Icons.schema_outlined, size: 16),
                      ),
                    ],
                    selected: {_browseMode},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _browseMode = selection.first;
                      });
                    },
                  ),
                ),
              ),
              if (_browseMode == _SidebarBrowseMode.topics) ...[
                _buildSidebarTopicsControls(
                  context,
                  l10n,
                  activeController,
                  topicController,
                  schemaController,
                ),
                _buildSidebarTopicFilter(context, l10n, activeController),
                _buildSidebarTopicList(
                  context,
                  activeController,
                  topicController,
                ),
              ] else
                SubjectBrowserList(
                  profile: activeController.activeProfile!,
                  schemaController: schemaController,
                  topicNames:
                      topicController
                          .getTopics(activeController.activeProfile!)
                          ?.map((t) => t.name)
                          .toList() ??
                      const [],
                  onSelectSubject: (subject) {
                    final activeProfile = activeController.activeProfile!;
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => SchemaViewerDialog(
                        profile: activeProfile,
                        initialSubject: subject,
                        controller: schemaController,
                        onNavigateToTopic: (topicName) {
                          openTopicByNameWithFeedback(
                            controller: activeController,
                            profile: activeProfile,
                            topicName: topicName,
                            messenger: ScaffoldMessenger.maybeOf(context),
                            l10n: l10n,
                          );
                        },
                      ),
                    );
                  },
                  onOpenClusterSettings: () {
                    final activeProfile = activeController.activeProfile!;
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => ClusterConfigDialog(
                        cluster: activeProfile,
                        existingNames: clusterController.clusters
                            .map((c) => c.name)
                            .toList(),
                      ),
                    );
                  },
                ),
            ],
            if (_browseMode == _SidebarBrowseMode.topics &&
                activeController.activeProfile != null &&
                schemaController.errorFor(activeController.activeProfile!) !=
                    null)
              ErrorBanner(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                title: l10n.subjectsLoadFailed(
                  schemaController.errorFor(activeController.activeProfile!)!,
                ),
              ),
            if (activeController.error != null)
              _buildErrorBox(context, activeController),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.clusters,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          IconButton(
            key: const Key('explorer_collapse_sidebar'),
            icon: const Icon(Icons.view_sidebar_outlined),
            tooltip: l10n.collapseSidebar,
            visualDensity: VisualDensity.compact,
            onPressed: _toggleSidebar,
          ),
        ],
      ),
    );
  }

  ClusterProfile _resolveLatestProfile(
    ClusterProfile fallback,
    ClusterListController clusterController,
  ) {
    return clusterController.clusters.cast<ClusterProfile?>().firstWhere(
          (c) => c?.name == fallback.name,
          orElse: () => null,
        ) ??
        fallback;
  }

  Future<void> _handleDisconnectCluster(
    BuildContext context,
    ClusterProfile cluster,
    ActiveConnectionController activeController,
  ) async {
    if (activeController.hasRunningOperations(cluster)) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.disconnectConfirmTitle(cluster.name)),
          content: Text(l10n.disconnectConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.disconnectConfirmAction),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    activeController.disconnect();
  }

  Widget _buildSidebarClusterList(
    BuildContext context,
    ClusterListController clusterController,
    ActiveConnectionController activeController,
    TopicController topicController,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final showFilter = clusterController.clusters.length > 5;
    final filtered = showFilter
        ? clusterController.clusters
              .where((c) => matchesClusterFilter(c, _clusterFilterQuery))
              .toList()
        : clusterController.clusters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFilter) ...[
          ClusterFilterField(
            controller: _clusterFilterController,
            dense: true,
            onChanged: (q) => setState(() => _clusterFilterQuery = q),
          ),
          const SizedBox(height: 8),
        ],
        if (showFilter && filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  l10n.clusterFilterNoMatch,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton(
                  onPressed: () {
                    _clusterFilterController.clear();
                    setState(() => _clusterFilterQuery = '');
                  },
                  child: Text(l10n.clusterFilterClear),
                ),
              ],
            ),
          )
        else
          LimitedBox(
            maxHeight: 200,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: filtered.map((cluster) {
                  return _buildClusterListItem(
                    context,
                    cluster,
                    activeController,
                    topicController,
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildClusterListItem(
    BuildContext context,
    ClusterProfile cluster,
    ActiveConnectionController activeController,
    TopicController topicController,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isActive = activeController.activeProfile?.name == cluster.name;
    final isConnecting =
        activeController.connectingProfile?.name == cluster.name ||
        (isActive && activeController.isConnecting);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isActive,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
        selectedColor: Theme.of(context).colorScheme.onPrimaryContainer,
        title: _buildClusterListTitle(
          context,
          cluster,
          isActive,
          topicController,
        ),
        onTap: isConnecting
            ? null
            : () {
                getIt<ActiveConnectionController>().connect(cluster);
                getIt<SchemaController>().fetchSchemas(cluster);
              },
        trailing: isConnecting
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : (isActive
                  ? Semantics(
                      label: l10n.disconnectClusterTooltip,
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.link_off, size: 16),
                        tooltip: l10n.disconnectClusterTooltip,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _handleDisconnectCluster(
                          context,
                          cluster,
                          activeController,
                        ),
                      ),
                    )
                  : null),
      ),
    );
  }

  Widget _buildClusterListTitle(
    BuildContext context,
    ClusterProfile cluster,
    bool isActive,
    TopicController topicController,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasEnvTag =
            cluster.environmentLabel != null &&
            cluster.environmentLabel!.trim().isNotEmpty;
        final isNarrow =
            constraints.maxWidth.isFinite &&
            (constraints.maxWidth < 210 ||
                (hasEnvTag && constraints.maxWidth < 250) ||
                (cluster.name.length > 14 && constraints.maxWidth < 245));
        return Row(
          children: [
            if (topicController.hasCachedTopics(cluster))
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            Flexible(
              child: Text(
                cluster.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : (topicController.hasCachedTopics(cluster)
                            ? Theme.of(context).colorScheme.primary
                            : null),
                ),
              ),
            ),
            if (cluster.environmentLabel != null &&
                cluster.environmentLabel!.trim().isNotEmpty) ...[
              const SizedBox(width: 6),
              EnvironmentTagChip(profile: cluster, compact: true),
            ],
            if (cluster.tlsVerification == TlsVerification.disabled) ...[
              const SizedBox(width: 6),
              InsecureTlsBadge(compact: true, iconOnly: isNarrow),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSidebarTopicsControls(
    BuildContext context,
    AppLocalizations l10n,
    ActiveConnectionController activeController,
    TopicController topicController,
    SchemaController schemaController,
  ) {
    final activeProfile = activeController.activeProfile!;
    final view = activeController.topicListView;
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
                initialValue: activeController.topicSortOrder,
                onSelected: activeController.setTopicSortOrder,
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
                  activeController.groupTopicsByPrefix
                      ? Icons.account_tree
                      : Icons.account_tree_outlined,
                  size: 16,
                  color: activeController.groupTopicsByPrefix
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: l10n.topicListGroupByPrefixTooltip,
                padding: EdgeInsets.zero,
                onPressed: activeController.toggleGroupByPrefix,
              ),
              IconButton(
                key: const Key('explorer_quick_jump_button'),
                icon: const Icon(Icons.bolt, size: 16),
                tooltip: l10n.quickJumpTitle,
                padding: EdgeInsets.zero,
                onPressed: () => _showQuickJumpDialog(context),
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

  Widget _buildSidebarTopicFilter(
    BuildContext context,
    AppLocalizations l10n,
    ActiveConnectionController activeController,
  ) {
    final view = activeController.topicListView;
    if (_filterController.text != activeController.topicFilter) {
      _filterController.value = TextEditingValue(
        text: activeController.topicFilter,
        selection: TextSelection.collapsed(
          offset: activeController.topicFilter.length,
        ),
      );
    }

    final modeLabel = switch (activeController.topicFilterMode) {
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
                selected: activeController.showInternalTopics,
                onSelected: (val) =>
                    activeController.toggleShowInternalTopics(val),
                visualDensity: VisualDensity.compact,
              ),
              FilterChip(
                label: Text(l10n.streamTopicsFilter),
                selected: activeController.showStreamTopics,
                onSelected: (val) =>
                    activeController.toggleShowStreamTopics(val),
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
                      activeController.showAllTopics();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (activeController.unhealthyTopicsOnly)
                InputChip(
                  key: const Key('topic_unhealthy_only_chip'),
                  avatar: Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(
                    l10n.topicListUnhealthyOnlyChip(
                      activeController.topics.length,
                    ),
                  ),
                  onDeleted: activeController.clearUnhealthyTopicsOnly,
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
                initialValue: activeController.topicFilterMode,
                onSelected: activeController.setTopicFilterMode,
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
                        activeController.updateTopicFilter("");
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
              activeController.updateTopicFilter(value);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTopicList(
    BuildContext context,
    ActiveConnectionController activeController,
    TopicController topicController,
  ) {
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

    final view = activeController.topicListView;
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
          if (activeController.topicPreferencesUnreadable ||
              activeController.topicPreferencesWriteBlocked)
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
                      activeController.topicPreferencesWriteBlocked
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
                    onPressed: activeController.dismissTopicPreferencesNotice,
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
                          activeController.toggleGroupCollapsed(row.prefix),
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
                      highlightQuery: activeController.topicFilter,
                      highlightPattern: view.highlightPattern,
                      isFavourite: row.isFavourite,
                      isMissingFavourite: row.isMissingFavourite,
                      onToggleFavourite: () =>
                          activeController.toggleFavourite(row.name),
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

  String _connectionErrorTitle(
    AppLocalizations l10n,
    ConnectionErrorKind kind,
  ) {
    switch (kind) {
      case ConnectionErrorKind.invalidBootstrapServers:
        return l10n.connectionErrorInvalidBootstrapServers;
      case ConnectionErrorKind.tlsVerificationFailed:
        return l10n.connectionErrorTlsVerificationFailed;
      case ConnectionErrorKind.validationFailed:
        return l10n.connectionErrorValidationFailed;
      case ConnectionErrorKind.brokerTransport:
        return l10n.connectionErrorBrokerTransport;
      case ConnectionErrorKind.connectionRefused:
        return l10n.connectionErrorConnectionRefused;
      case ConnectionErrorKind.other:
        return l10n.connectionErrorOther;
    }
  }

  Widget _buildErrorBox(
    BuildContext context,
    ActiveConnectionController activeController,
  ) {
    final err = activeController.error!;
    final l10n = AppLocalizations.of(context)!;
    final title = _connectionErrorTitle(l10n, err.kind);
    return ErrorBanner(
      margin: const EdgeInsets.all(12),
      title: title,
      detail: err.detail,
      onDismiss: activeController.clearError,
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    ClusterListController clusterController,
    ActiveConnectionController activeController,
    TopicController topicController,
    SchemaController schemaController,
  ) {
    if (activeController.activeProfile == null) {
      return ExplorerOnboardingView(
        clusters: clusterController.clusters,
        connectingProfile: activeController.connectingProfile,
        onAddCluster: () async {
          final result = await showDialog<ClusterProfile>(
            context: context,
            builder: (context) => ClusterConfigDialog(
              existingNames: clusterController.clusters
                  .map((c) => c.name)
                  .toList(),
            ),
          );
          if (result != null) {
            clusterController.addCluster(result);
          }
        },
        onSelectCluster: (profile) {
          activeController.connect(profile);
          schemaController.fetchSchemas(profile);
        },
        onSelectRecentTopic: (clusterName, topicName) async {
          final targetCluster = clusterController.clusters
              .cast<ClusterProfile?>()
              .firstWhere((c) => c?.name == clusterName, orElse: () => null);
          if (targetCluster == null) return;

          final messenger = ScaffoldMessenger.maybeOf(context);
          final l10n = AppLocalizations.of(context);
          if (activeController.activeProfile?.name != clusterName) {
            await activeController.connect(targetCluster);
            schemaController.fetchSchemas(targetCluster);
          }

          if (!mounted) return;
          await openTopicByNameWithFeedback(
            controller: activeController,
            profile: targetCluster,
            topicName: topicName,
            messenger: messenger,
            l10n: l10n,
          );
        },
      );
    }

    if (activeController.openTopics.isEmpty) {
      final activeProfile = activeController.activeProfile!;
      final allTopics = topicController.getTopics(activeProfile);
      final isLoading =
          activeController.isConnecting ||
          topicController.isLoading(activeProfile);

      return ClusterOverviewView(
        profile: activeProfile,
        topics: allTopics,
        isLoading: isLoading,
        onShowUnhealthyTopics: activeController.showUnhealthyTopicsOnly,
        onSelectTopic: (topicName) {
          openTopicByNameWithFeedback(
            controller: activeController,
            profile: activeProfile,
            topicName: topicName,
            messenger: ScaffoldMessenger.maybeOf(context),
            l10n: AppLocalizations.of(context),
          );
        },
      );
    }

    final activeIndex = activeController.openTopics.indexWhere(
      (t) => t.id == activeController.activeTopic?.id,
    );
    final safeIndex = activeIndex >= 0 ? activeIndex : 0;

    final activeBannerProfile = activeController.activeProfile != null
        ? _resolveLatestProfile(
            activeController.activeProfile!,
            getIt<ClusterListController>(),
          )
        : null;

    return Column(
      children: [
        if (activeBannerProfile != null)
          EnvironmentBanner(profile: activeBannerProfile),
        _buildTabBar(context, l10n, activeController),
        _buildTabViews(activeController, safeIndex),
      ],
    );
  }

  String _getTabTitle(
    ActiveConnectionController activeController,
    OpenTopicRecord record,
  ) {
    final matchingTabs = activeController.openTopics
        .where(
          (t) =>
              t.topic.name == record.topic.name &&
              t.profile.name == record.profile.name,
        )
        .toList();
    if (matchingTabs.length > 1) {
      final instanceIndex = matchingTabs.indexOf(record) + 1;
      return '${record.topic.name} ($instanceIndex)';
    }
    return record.topic.name;
  }

  Widget _buildTabBar(
    BuildContext context,
    AppLocalizations l10n,
    ActiveConnectionController activeController,
  ) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              final offset =
                  _tabScrollController.offset + pointerSignal.scrollDelta.dy;
              _tabScrollController.jumpTo(
                offset.clamp(
                  0.0,
                  _tabScrollController.position.maxScrollExtent,
                ),
              );
            }
          },
          child: Scrollbar(
            controller: _tabScrollController,
            thumbVisibility: true,
            child: ListView.builder(
              controller: _tabScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: activeController.openTopics.length,
              itemBuilder: (context, index) {
                return _buildTabItem(
                  context,
                  l10n,
                  activeController,
                  activeController.openTopics[index],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(
    BuildContext context,
    AppLocalizations l10n,
    ActiveConnectionController activeController,
    OpenTopicRecord record,
  ) {
    final isSelected = activeController.activeTopic?.id == record.id;
    final streamCtrl = activeController.getStreamController(record.id);
    final analysisCtrl = activeController.getAnalysisController(record.id);

    return InkWell(
      onTap: () => activeController.setActiveTabId(record.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
            right: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: ListenableBuilder(
          listenable: Listenable.merge([streamCtrl, analysisCtrl]),
          builder: (context, _) => _buildTabItemContent(
            context,
            l10n,
            activeController,
            record,
            streamCtrl,
            analysisCtrl,
            isSelected,
          ),
        ),
      ),
    );
  }

  Widget _buildTabItemContent(
    BuildContext context,
    AppLocalizations l10n,
    ActiveConnectionController activeController,
    OpenTopicRecord record,
    MessageStreamController streamCtrl,
    TopicAnalysisController analysisCtrl,
    bool isSelected,
  ) {
    final title = _getTabTitle(activeController, record);
    final isRunning = streamCtrl.isStreaming || analysisCtrl.isAnalyzing;

    final resolvedTabProfile = getIt.isRegistered<ClusterListController>()
        ? _resolveLatestProfile(record.profile, getIt<ClusterListController>())
        : record.profile;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                if (DlqTopicDetector.isDlqTopic(record.topic.name)) ...[
                  const SizedBox(width: 4),
                  Container(
                    key: const Key('tab_dlq_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      l10n.dlqBadgeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  resolvedTabProfile.name,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                if (resolvedTabProfile.environmentLabel != null &&
                    resolvedTabProfile.environmentLabel!.trim().isNotEmpty) ...[
                  const SizedBox(width: 4),
                  EnvironmentTagChip(
                    profile: resolvedTabProfile,
                    compact: true,
                  ),
                ],
              ],
            ),
          ],
        ),
        if (streamCtrl.isStreaming) ...[
          const SizedBox(width: 8),
          _buildTabProgressIndicator(
            context,
            l10n,
            streamCtrl.progress,
            streamCtrl.startTime,
          ),
        ] else if (analysisCtrl.isAnalyzing) ...[
          const SizedBox(width: 8),
          _buildTabProgressIndicator(
            context,
            l10n,
            analysisCtrl.progressRatio,
            analysisCtrl.startTime,
          ),
        ] else if (streamCtrl.messages.isNotEmpty) ...[
          const SizedBox(width: 8),
          _buildTabMessageCount(context, streamCtrl),
        ],
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_to_photos_outlined, size: 14),
          tooltip: l10n.duplicateTab,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          visualDensity: VisualDensity.compact,
          onPressed: () => activeController.openTopic(
            topic: record.topic,
            profile: record.profile,
            forceNew: true,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(
            Icons.close,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          tooltip: l10n.closeTab,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: () => confirmCloseTab(
            context,
            isOperationRunning: isRunning,
            onClose: () => activeController.closeTopicTab(record.id),
          ),
        ),
      ],
    );
  }

  Widget _buildTabProgressIndicator(
    BuildContext context,
    AppLocalizations l10n,
    double progress,
    DateTime? startTime,
  ) {
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: progress > 0 ? progress : null,
            minHeight: 2,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              String etaText = l10n.scanning;
              if (progress > 0 && startTime != null && progress < 1.0) {
                final elapsedSeconds = DateTime.now()
                    .difference(startTime)
                    .inSeconds;
                final totalEstimatedSeconds = elapsedSeconds / progress;
                final remainingSeconds =
                    (totalEstimatedSeconds - elapsedSeconds).round();
                if (remainingSeconds > 0) {
                  if (remainingSeconds < 60) {
                    etaText = "~$remainingSeconds s";
                  } else {
                    etaText = "~${remainingSeconds ~/ 60} m";
                  }
                }
              }
              return Text(
                etaText,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabMessageCount(
    BuildContext context,
    MessageStreamController streamCtrl,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        "${streamCtrl.messages.length}",
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _buildTabViews(
    ActiveConnectionController activeController,
    int safeIndex,
  ) {
    return Expanded(
      child: IndexedStack(
        index: safeIndex,
        children: activeController.openTopics.map((record) {
          return TopicDetailView(
            key: ValueKey(record.id),
            tabId: record.id,
            topic: record.topic,
            profile: record.profile,
          );
        }).toList(),
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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
