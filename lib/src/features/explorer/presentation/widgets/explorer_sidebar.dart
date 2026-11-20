import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/domain/connection_error.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/explorer_view.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/explorer_sidebar_clusters.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/explorer_sidebar_topics.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/schema_viewer_dialog.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/subject_browser_list.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';
import 'package:kafkalyzer/src/ui/widgets/error_banner.dart';

enum _SidebarBrowseMode { topics, subjects }

/// The Explorer sidebar: cluster list, browse-mode switcher, topic panel and
/// the drag handle that resizes it. Collapsed state stays with the caller,
/// which also draws the divider and binds the sidebar shortcut.
class ExplorerSidebar extends StatefulWidget {
  final ClusterListController clusterController;
  final ActiveConnectionController activeController;
  final TopicController topicController;
  final SchemaController schemaController;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onQuickJump;

  const ExplorerSidebar({
    super.key,
    required this.clusterController,
    required this.activeController,
    required this.topicController,
    required this.schemaController,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onQuickJump,
  });

  @override
  State<ExplorerSidebar> createState() => _ExplorerSidebarState();
}

class _ExplorerSidebarState extends State<ExplorerSidebar> {
  _SidebarBrowseMode _browseMode = _SidebarBrowseMode.topics;
  double _width = ExplorerView.defaultSidebarWidth;

  ClusterListController get clusterController => widget.clusterController;
  ActiveConnectionController get activeController => widget.activeController;
  TopicController get topicController => widget.topicController;
  SchemaController get schemaController => widget.schemaController;

  @override
  void initState() {
    super.initState();
    _loadWidth();
  }

  Future<void> _loadWidth() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _width =
          (prefs.getDouble(ExplorerView.sidebarWidthPrefKey) ??
                  ExplorerView.defaultSidebarWidth)
              .clamp(
                ExplorerView.minSidebarWidth,
                ExplorerView.maxSidebarWidth,
              );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.centerLeft,
        child: widget.collapsed
            ? _collapsedRail(context, l10n)
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_expanded(context, l10n), _resizeHandle()],
              ),
      ),
    );
  }

  Widget _resizeHandle() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        key: const Key('explorer_sidebar_resize_handle'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          setState(() {
            _width = (_width + details.delta.dx).clamp(
              ExplorerView.minSidebarWidth,
              ExplorerView.maxSidebarWidth,
            );
          });
        },
        onHorizontalDragEnd: (_) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble(ExplorerView.sidebarWidthPrefKey, _width);
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

  Widget _collapsedRail(BuildContext context, AppLocalizations l10n) {
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
              onPressed: widget.onToggleCollapsed,
            ),
            const SizedBox(height: 8),
            IconButton(
              key: const Key('explorer_collapsed_quick_jump_button'),
              icon: const Icon(Icons.bolt, size: 20),
              tooltip: l10n.quickJumpTitle,
              onPressed: () => widget.onQuickJump(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expanded(BuildContext context, AppLocalizations l10n) {
    return SizedBox(
      key: const Key('explorer_sidebar_container'),
      width: _width,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, l10n),
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
                    onQuickJump: () => widget.onQuickJump(),
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
              _errorBox(context, activeController),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppLocalizations l10n) {
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
            onPressed: widget.onToggleCollapsed,
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

  Widget _errorBox(
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
}
