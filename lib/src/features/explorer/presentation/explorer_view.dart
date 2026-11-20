import 'dart:async';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:watch_it/watch_it.dart';
import 'package:kafkalyzer/src/features/cluster/domain/connection_error.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/navigation/widgets/quick_jump_dialog.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/schema_viewer_dialog.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/subject_browser_list.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/ui/shortcuts/app_shortcuts.dart';
import 'package:kafkalyzer/src/ui/widgets/error_banner.dart';

import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/topic_detail_view.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';
import 'package:kafkalyzer/src/features/topic/utils/dlq_topic_detector.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/environment_tag.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/explorer_onboarding_view.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/cluster_overview_view.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/explorer_sidebar_clusters.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/explorer_sidebar_topics.dart';
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
  _SidebarBrowseMode _browseMode = _SidebarBrowseMode.topics;
  final ScrollController _tabScrollController = ScrollController();
  bool _isSidebarCollapsed = false;
  double _sidebarWidth = ExplorerView.defaultSidebarWidth;

  @override
  void initState() {
    super.initState();
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
            ExplorerClusterList(
              clusterController: clusterController,
              activeController: activeController,
              topicController: topicController,
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
                Expanded(
                  child: ExplorerTopicPanel(
                    activeController: activeController,
                    topicController: topicController,
                    schemaController: schemaController,
                    onQuickJump: () => _showQuickJumpDialog(context),
                  ),
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
        ? resolveLatestProfile(
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
        ? resolveLatestProfile(record.profile, getIt<ClusterListController>())
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
