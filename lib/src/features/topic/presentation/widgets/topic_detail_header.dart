import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_facts_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

enum TopicViewMode { messages, analysis, config }

/// The responsive header of a topic tab: close button, title row, mode
/// switcher, schema action, and the slots for the fact strip and progress tile.
///
/// The selected mode and the close behaviour stay with the caller; the header
/// only reports what the user picked.
class TopicDetailHeader extends StatelessWidget {
  final String topicName;
  final ClusterProfile profile;
  final TopicController? topicController;
  final TopicFactsController factsController;
  final TopicViewMode viewMode;
  final ValueChanged<TopicViewMode> onViewModeChanged;
  final VoidCallback onSelectConfig;
  final VoidCallback onClose;
  final bool showSchema;
  final VoidCallback onOpenSchema;
  final Widget tags;
  final Widget progressTile;

  const TopicDetailHeader({
    super.key,
    required this.topicName,
    required this.profile,
    required this.topicController,
    required this.factsController,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onSelectConfig,
    required this.onClose,
    required this.showSchema,
    required this.onOpenSchema,
    required this.tags,
    required this.progressTile,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final closeButton = IconButton(
      onPressed: onClose,
      icon: const Icon(Icons.close),
      tooltip: l10n?.closeTab ?? "Close Tab",
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHigh,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // shortcut: fixed breakpoints, raise the second one if the pane gets wider sidebars
        final compact = constraints.maxWidth < 1220;
        final iconOnly = constraints.maxWidth < 700;

        final identityRow = Row(
          children: [
            closeButton,
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _titleRow(context),
                        const SizedBox(height: 8),
                        tags,
                      ],
                    ),
                  ),
                  if (showSchema) ...[
                    const SizedBox(width: 12),
                    _schemaButton(context),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            _modeSwitcher(context, colorScheme, l10n, iconOnly),
          ],
        );

        if (viewMode != TopicViewMode.messages) {
          return identityRow;
        }

        final alignedProgress = Align(
          alignment: Alignment.centerRight,
          child: progressTile,
        );

        if (!compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  closeButton,
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(child: _titleRow(context)),
                        if (showSchema) ...[
                          const SizedBox(width: 12),
                          _schemaButton(context),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _modeSwitcher(context, colorScheme, l10n, iconOnly),
                  const SizedBox(width: 16),
                  Flexible(child: alignedProgress),
                ],
              ),
              const SizedBox(height: 6),
              Padding(padding: const EdgeInsets.only(left: 56), child: tags),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                closeButton,
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(child: _titleRow(context)),
                      if (showSchema) ...[
                        const SizedBox(width: 12),
                        _schemaButton(context),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _modeSwitcher(context, colorScheme, l10n, iconOnly),
              ],
            ),
            const SizedBox(height: 6),
            Padding(padding: const EdgeInsets.only(left: 56), child: tags),
            const SizedBox(height: 8),
            alignedProgress,
          ],
        );
      },
    );
  }

  Widget _modeSwitcher(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
    bool iconOnly,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TopicModeButton(
            icon: Icons.list_alt_rounded,
            label: l10n?.messagesView ?? 'Messages',
            isSelected: viewMode == TopicViewMode.messages,
            showLabel: !iconOnly,
            onTap: () => onViewModeChanged(TopicViewMode.messages),
          ),
          const SizedBox(width: 2),
          _TopicModeButton(
            icon: Icons.analytics_outlined,
            label: l10n?.topicAnalysis ?? 'Analysis',
            isSelected: viewMode == TopicViewMode.analysis,
            showLabel: !iconOnly,
            onTap: () => onViewModeChanged(TopicViewMode.analysis),
          ),
          const SizedBox(width: 2),
          _TopicModeButton(
            icon: Icons.tune,
            label: l10n?.topicModeConfig ?? 'Configuration',
            isSelected: viewMode == TopicViewMode.config,
            showLabel: !iconOnly,
            onTap: onSelectConfig,
          ),
        ],
      ),
    );
  }

  Widget _titleRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            topicName,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          tooltip: l10n?.copyTopicName ?? "Copy Topic Name",
          onPressed: () {
            Clipboard.setData(ClipboardData(text: topicName));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n?.topicNameCopied ?? "Topic name copied"),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
        IconButton(
          key: const Key('topic_header_refresh_facts_button'),
          icon: const Icon(Icons.refresh, size: 18),
          tooltip:
              l10n?.topicHeaderRefreshFactsTooltip ?? 'Refresh topic facts',
          onPressed: () {
            topicController?.fetchTopics(profile, force: true);
            factsController.refresh();
          },
        ),
      ],
    );
  }

  Widget _schemaButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: OutlinedButton.icon(
        onPressed: onOpenSchema,
        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
        icon: const Icon(Icons.schema_outlined, size: 16),
        label: Text(AppLocalizations.of(context)?.schemaAction ?? "Schema"),
      ),
    );
  }
}

class _TopicModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback onTap;

  const _TopicModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            if (!showLabel) const SizedBox(width: 4),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
