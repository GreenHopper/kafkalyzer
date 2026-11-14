import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../dependency_injection.dart';
import '../../../rust/api/kafka_types.dart';
import '../../cluster/presentation/controllers/active_connection_controller.dart';
import '../../cluster/presentation/controllers/cluster_list_controller.dart';
import '../../consumer/application/consumer_group_directory.dart';
import '../../scripting/presentation/controllers/script_controller.dart';
import '../../topic/presentation/controllers/topic_controller.dart';
import '../main_navigation_controller.dart';
import '../widgets/quick_jump_dialog.dart';
import 'palette_entry.dart';
import 'palette_sources.dart';

/// Top-aligned, keyboard-first command palette dialog.
class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({
    super.key,
    required this.rootContext,
    this.snapshotOverride,
    this.onOpenReferenceOverride,
  });

  /// Outer navigator context used after the palette pops (for example to open
  /// [QuickJumpDialog]).
  final BuildContext rootContext;

  /// Optional snapshot override for widget tests.
  final PaletteSnapshot? snapshotOverride;

  /// Optional reference-launch override for widget tests.
  final Future<void> Function(String rawReference)? onOpenReferenceOverride;

  static Future<void> show(
    BuildContext context, {
    PaletteSnapshot? snapshotOverride,
    Future<void> Function(String rawReference)? onOpenReferenceOverride,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => CommandPaletteDialog(
        rootContext: context,
        snapshotOverride: snapshotOverride,
        onOpenReferenceOverride: onOpenReferenceOverride,
      ),
    );
  }

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  int _highlightIndex = 0;
  List<GlobalKey> _rowKeys = const [];

  @override
  void dispose() {
    _queryController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  PaletteSnapshot _buildSnapshot(AppLocalizations l10n) {
    if (widget.snapshotOverride != null) {
      return widget.snapshotOverride!;
    }

    final nav = getIt<MainNavigationController>();
    final clusterList = getIt<ClusterListController>();
    final activeConn = getIt<ActiveConnectionController>();
    final topicController = getIt<TopicController>();
    final scriptController = getIt<ScriptController>();
    final groupDirectory = getIt.isRegistered<ConsumerGroupDirectory>()
        ? getIt<ConsumerGroupDirectory>()
        : null;

    final activeProfile = activeConn.activeProfile;
    final topics = activeProfile == null
        ? null
        : topicController.getTopics(activeProfile);
    final openTopicNames = activeConn.openTopics
        .map((t) => t.topic.name)
        .toSet();
    final groupIds = activeProfile == null
        ? null
        : groupDirectory?.idsFor(activeProfile.name);

    return PaletteSnapshot(
      l10n: l10n,
      clusters: clusterList.clusters,
      activeProfile: activeProfile,
      topics: topics,
      openTopicNames: openTopicNames,
      consumerGroupIds: groupIds,
      scripts: scriptController.scripts,
      onSelectDestination: nav.select,
      onOpenCluster: (ClusterProfile profile) async {
        nav.select(MainDestination.explorer);
        if (activeConn.activeProfile?.name != profile.name) {
          await activeConn.connect(profile);
        }
      },
      onOpenTopic: (topic) {
        final profile = activeConn.activeProfile;
        if (profile == null) return;
        nav.select(MainDestination.explorer);
        activeConn.openTopic(topic: topic, profile: profile, forceNew: false);
      },
      onOpenConsumerGroup: nav.openConsumerGroup,
      onOpenScript: (script) => nav.openScript(script.id),
    );
  }

  Future<void> _openReference(String rawRef) {
    if (widget.onOpenReferenceOverride != null) {
      return widget.onOpenReferenceOverride!(rawRef);
    }
    final rootCtx = widget.rootContext;
    if (!rootCtx.mounted) return Future.value();
    return showDialog<void>(
      context: rootCtx,
      builder: (_) => QuickJumpDialog(initialInput: rawRef),
    );
  }

  void _ensureRowKeys(int count) {
    if (_rowKeys.length == count) return;
    _rowKeys = List<GlobalKey>.generate(count, (_) => GlobalKey());
  }

  void _moveHighlight(int delta, int count) {
    if (count == 0) return;
    setState(() {
      _highlightIndex = (_highlightIndex + delta + count) % count;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _highlightIndex >= _rowKeys.length) return;
      final rowContext = _rowKeys[_highlightIndex].currentContext;
      if (rowContext != null) {
        Scrollable.ensureVisible(
          rowContext,
          alignment: 0.5,
          duration: Duration.zero,
        );
      }
    });
  }

  Future<void> _runEntry(PaletteEntry entry) async {
    Navigator.of(context).pop();
    await entry.run();
  }

  Widget _buildHighlightedLabel(
    BuildContext context,
    String text,
    List<int> matchedIndices,
  ) {
    if (matchedIndices.isEmpty) {
      return Text(text, overflow: TextOverflow.ellipsis);
    }
    final matchedSet = matchedIndices.toSet();
    final baseStyle = DefaultTextStyle.of(context).style;
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.bold);
    final spans = <TextSpan>[];
    final buffer = StringBuffer();
    var currentMatched = matchedSet.contains(0);

    for (var i = 0; i < text.length; i++) {
      final isMatched = matchedSet.contains(i);
      if (isMatched != currentMatched && buffer.isNotEmpty) {
        spans.add(
          TextSpan(
            text: buffer.toString(),
            style: currentMatched ? boldStyle : baseStyle,
          ),
        );
        buffer.clear();
        currentMatched = isMatched;
      }
      buffer.write(text[i]);
    }
    if (buffer.isNotEmpty) {
      spans.add(
        TextSpan(
          text: buffer.toString(),
          style: currentMatched ? boldStyle : baseStyle,
        ),
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final snapshot = _buildSnapshot(l10n);
    final result = rankPaletteEntries(
      query: _queryController.text,
      snapshot: snapshot,
      onOpenReference: _openReference,
    );
    final visible = result.visible;
    _ensureRowKeys(visible.length);
    final clampedIndex = visible.isEmpty
        ? 0
        : _highlightIndex.clamp(0, visible.length - 1);

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 64, left: 24, right: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      _moveHighlight(1, visible.length),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      _moveHighlight(-1, visible.length),
                },
                child: TextField(
                  controller: _queryController,
                  focusNode: _inputFocusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.go,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.commandPaletteHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() => _highlightIndex = 0),
                  onSubmitted: (_) {
                    if (visible.isEmpty) return;
                    _runEntry(visible[clampedIndex].entry);
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      l10n.commandPaletteNoResults,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: Semantics(
                    container: true,
                    label: l10n.commandPaletteListLabel,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final ranked = visible[index];
                        final entry = ranked.entry;
                        final kindLabel = entry.kind.label(l10n);
                        return Semantics(
                          label: '$kindLabel, ${entry.label}',
                          child: ListTile(
                            key: _rowKeys[index],
                            dense: true,
                            selected: index == clampedIndex,
                            selectedTileColor: theme
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.35),
                            leading: Icon(entry.kind.icon, size: 20),
                            title: _buildHighlightedLabel(
                              context,
                              entry.label,
                              ranked.matchedIndices,
                            ),
                            subtitle: entry.subtitle != null
                                ? Text(entry.subtitle!)
                                : null,
                            trailing: Text(
                              kindLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            onTap: () => _runEntry(entry),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (result.totalMatches > visible.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.commandPaletteResultsCap(
                      visible.length,
                      result.totalMatches,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (result.groupsNotLoaded)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.commandPaletteGroupsNotLoadedNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
