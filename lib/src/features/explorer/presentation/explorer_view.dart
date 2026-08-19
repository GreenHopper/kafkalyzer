import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:watch_it/watch_it.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';

import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/topic_detail_view.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_list_item.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';

class ExplorerView extends WatchingStatefulWidget {
  const ExplorerView({super.key});

  @override
  State<ExplorerView> createState() => _ExplorerViewState();
}

class _ExplorerViewState extends State<ExplorerView> {
  late TextEditingController _filterController;
  final ScrollController _tabScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController(
      text: getIt<ActiveConnectionController>().topicFilter,
    );
  }

  @override
  void dispose() {
    _filterController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final clusterController = watchIt<ClusterListController>();
    final activeController = watchIt<ActiveConnectionController>();
    final topicController = watchIt<TopicController>();
    final schemaController = watchIt<SchemaController>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebar(
          context,
          l10n,
          clusterController,
          activeController,
          topicController,
          schemaController,
        ),
        VerticalDivider(
          width: 1,
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        // Main Content
        Expanded(
          child: _buildContent(
            context,
            l10n,
            activeController,
            topicController,
            schemaController,
          ),
        ),
      ],
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
      width: 360,
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
            ],
            if (activeController.error != null)
              _buildErrorBox(context, activeController),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        l10n.clusters,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSidebarClusterList(
    BuildContext context,
    ClusterListController clusterController,
    ActiveConnectionController activeController,
    TopicController topicController,
  ) {
    return LimitedBox(
      maxHeight: 200,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: clusterController.clusters.map((cluster) {
            return _buildClusterListItem(
              context,
              cluster,
              activeController,
              topicController,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildClusterListItem(
    BuildContext context,
    ClusterProfile cluster,
    ActiveConnectionController activeController,
    TopicController topicController,
  ) {
    final isActive = activeController.activeProfile?.name == cluster.name;
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
        onTap: () {
          getIt<ActiveConnectionController>().connect(cluster);
          getIt<SchemaController>().fetchSchemas(cluster);
        },
        trailing: isActive && activeController.isConnecting
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
    );
  }

  Widget _buildClusterListTitle(
    BuildContext context,
    ClusterProfile cluster,
    bool isActive,
    TopicController topicController,
  ) {
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
        Text(
          cluster.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isActive
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : (topicController.hasCachedTopics(cluster)
                      ? Theme.of(context).colorScheme.primary
                      : null),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarTopicsControls(
    BuildContext context,
    AppLocalizations l10n,
    ActiveConnectionController activeController,
    TopicController topicController,
    SchemaController schemaController,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "${l10n.topics} (${activeController.topics.length}/${topicController.getTopics(activeController.activeProfile!)?.length ?? 0})",
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed:
                activeController.isConnecting ||
                    topicController.isLoading(
                      activeController.activeProfile!,
                    ) ||
                    schemaController.isLoading(activeController.activeProfile!)
                ? null
                : () {
                    topicController.fetchTopics(
                      activeController.activeProfile!,
                      force: true,
                    );
                    schemaController.fetchSchemas(
                      activeController.activeProfile!,
                      force: true,
                    );
                  },
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Internal Topics",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: activeController.showInternalTopics,
                  onChanged: (val) =>
                      activeController.toggleShowInternalTopics(val),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Kafka Stream Topics",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: activeController.showStreamTopics,
                  onChanged: (val) =>
                      activeController.toggleShowStreamTopics(val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _filterController,
            decoration: InputDecoration(
              hintText: l10n.filterTopics,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _filterController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
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
    return Expanded(
      child:
          (activeController.isConnecting ||
              topicController.isLoading(activeController.activeProfile!))
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: activeController.topics.length,
              itemBuilder: (context, index) {
                final topic = activeController.topics[index];
                final isSelected = activeController.openTopics.any(
                  (t) =>
                      t.topic.name == topic.name &&
                      t.profile.name == activeController.activeProfile?.name,
                );
                return TopicListItem(
                  topic: topic,
                  isSelected: isSelected,
                  onTap: () => activeController.setActiveTopic(
                    topic,
                    activeController.activeProfile,
                  ),
                  onOpenInNewTab: () => activeController.openTopic(
                    topic: topic,
                    profile: activeController.activeProfile,
                    forceNew: true,
                  ),
                  clusterProfile: activeController.activeProfile,
                );
              },
            ),
    );
  }

  Widget _buildErrorBox(
    BuildContext context,
    ActiveConnectionController activeController,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Text(
        "Error: ${activeController.error}",
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    ActiveConnectionController activeController,
    TopicController topicController,
    SchemaController schemaController,
  ) {
    if (activeController.activeProfile == null) {
      return _buildNoClusterSelected(context, l10n);
    }

    if (activeController.openTopics.isEmpty) {
      return _buildNoTopicSelected(context);
    }

    final activeIndex = activeController.openTopics.indexWhere(
      (t) => t.id == activeController.activeTopic?.id,
    );
    final safeIndex = activeIndex >= 0 ? activeIndex : 0;

    return Column(
      children: [
        _buildTabBar(context, l10n, activeController),
        _buildTabViews(activeController, safeIndex),
      ],
    );
  }

  Widget _buildNoClusterSelected(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hub_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.selectClusterToViewTopics,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTopicSelected(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            "Select a topic from the sidebar to start",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            Text(
              record.profile.name,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 10,
              ),
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
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          onPressed: () => activeController.openTopic(
            topic: record.topic,
            profile: record.profile,
            forceNew: true,
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => confirmCloseTab(
            context,
            isOperationRunning: isRunning,
            onClose: () => activeController.closeTopicTab(record.id),
          ),
          child: Tooltip(
            message: l10n.closeTab,
            child: Icon(
              Icons.close,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
                style: TextStyle(
                  fontSize: 9,
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
        style: TextStyle(
          fontSize: 10,
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
