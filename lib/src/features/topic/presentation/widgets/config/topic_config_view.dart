import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/widgets/environment_tag.dart';
import 'package:kafkalyzer/src/ui/widgets/insecure_tls_badge.dart';
import 'package:kafkalyzer/src/features/topic/domain/topic_config_text.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_config_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/config/topic_config_compare_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/topic_config.dart';

class TopicConfigView extends StatelessWidget {
  final TopicConfigController controller;
  final List<ClusterProfile>? clusters;
  final List<String> Function(ClusterProfile profile)? cachedTopicsLookup;

  const TopicConfigView({
    super.key,
    required this.controller,
    this.clusters,
    this.cachedTopicsLookup,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final compare = controller.compare;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toolbar(
              controller: controller,
              l10n: l10n,
              onCompare: () => _openCompareDialog(context),
              onCopy: _canCopy() ? () => _copyAsText(context, l10n) : null,
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: compare == null
                  ? _SideHeaderCard(
                      profile: controller.leftProfile,
                      topic: controller.leftTopic,
                      sideState: controller.left,
                      onRetry: controller.retryLeft,
                      l10n: l10n,
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _SideHeaderCard(
                            profile: controller.leftProfile,
                            topic: controller.leftTopic,
                            sideState: controller.left,
                            onRetry: controller.retryLeft,
                            l10n: l10n,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SideHeaderCard(
                            profile: compare.profile,
                            topic: compare.topic,
                            sideState: compare.right,
                            onRetry: controller.retryRight,
                            l10n: l10n,
                          ),
                        ),
                      ],
                    ),
            ),
            if (compare != null)
              _ComparisonSummaryBar(controller: controller, l10n: l10n),
            Expanded(
              child: compare == null
                  ? _SingleConfigBody(controller: controller, l10n: l10n)
                  : _CompareConfigBody(controller: controller, l10n: l10n),
            ),
          ],
        );
      },
    );
  }

  bool _canCopy() {
    if (!controller.isComparing) {
      return controller.left.snapshot != null;
    }
    return controller.diff != null;
  }

  Future<void> _openCompareDialog(BuildContext context) async {
    final selection = await showTopicConfigCompareDialog(
      context: context,
      currentProfile: controller.leftProfile,
      openTopicName: controller.leftTopic,
      clusters: clusters,
      cachedTopicsLookup: cachedTopicsLookup,
    );
    if (selection != null) {
      await controller.startComparison(selection.$1, selection.$2);
    }
  }

  Future<void> _copyAsText(BuildContext context, AppLocalizations l10n) async {
    final String text;
    final compare = controller.compare;
    if (compare == null) {
      final snapshot = controller.left.snapshot;
      if (snapshot == null) return;
      text = formatSingleTopicConfigText(
        profileName: controller.leftProfile.name,
        topicName: controller.leftTopic,
        snapshot: snapshot,
        visibleEntries: controller.visibleSingleEntries,
        l10n: l10n,
      );
    } else {
      final diff = controller.diff;
      final leftSnapshot = controller.left.snapshot;
      final rightSnapshot = compare.right.snapshot;
      if (diff == null || leftSnapshot == null || rightSnapshot == null) return;
      text = formatTopicConfigDiffText(
        leftProfileName: controller.leftProfile.name,
        leftTopicName: controller.leftTopic,
        leftSnapshot: leftSnapshot,
        rightProfileName: compare.profile.name,
        rightTopicName: compare.topic,
        rightSnapshot: rightSnapshot,
        differenceCount: diff.differenceCount,
        visibleRows: controller.visibleDiffRows,
        l10n: l10n,
      );
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.topicConfigCopiedToClipboard),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final TopicConfigController controller;
  final AppLocalizations l10n;
  final VoidCallback onCompare;
  final VoidCallback? onCopy;

  const _Toolbar({
    required this.controller,
    required this.l10n,
    required this.onCompare,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isComparing = controller.isComparing;
    final toggleLabel = isComparing
        ? l10n.topicConfigDiffToggle
        : l10n.topicConfigNonDefaultToggle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.topicConfigRefreshTooltip,
            onPressed: controller.refresh,
          ),
          Tooltip(
            message: isComparing
                ? l10n.topicConfigDiffToggle
                : l10n.topicConfigNonDefaultToggleTooltip,
            child: FilterChip(
              label: Text(toggleLabel),
              selected: controller.nonDefaultOnly,
              onSelected: (_) => controller.toggleNonDefaultOnly(),
            ),
          ),
          if (!isComparing)
            OutlinedButton.icon(
              icon: const Icon(Icons.compare_arrows, size: 18),
              label: Text(l10n.topicConfigCompareAction),
              onPressed: onCompare,
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.close, size: 18),
              label: Text(l10n.topicConfigCloseComparisonAction),
              onPressed: controller.closeComparison,
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            label: Text(l10n.topicConfigCopyAsText),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

class _SideHeaderCard extends StatelessWidget {
  final ClusterProfile profile;
  final String topic;
  final TopicConfigSideState sideState;
  final VoidCallback onRetry;
  final AppLocalizations l10n;

  const _SideHeaderCard({
    required this.profile,
    required this.topic,
    required this.sideState,
    required this.onRetry,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = sideState.snapshot;
    final isUnavailable =
        snapshot != null &&
        snapshot.availability != TopicConfigAvailability.available;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUnavailable
              ? theme.colorScheme.error.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                profile.name,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (profile.environmentLabel != null &&
                  profile.environmentLabel!.trim().isNotEmpty)
                EnvironmentTagChip(profile: profile, compact: true),
              if (profile.tlsVerification == TlsVerification.disabled)
                const InsecureTlsBadge(compact: true),
              Text(
                topic,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              if (sideState.isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (isUnavailable) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    topicConfigUnavailableReason(snapshot, l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: onRetry, child: Text(l10n.retry)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparisonSummaryBar extends StatelessWidget {
  final TopicConfigController controller;
  final AppLocalizations l10n;

  const _ComparisonSummaryBar({required this.controller, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final compare = controller.compare!;
    final isLoading = controller.left.isLoading || compare.right.isLoading;
    final diff = controller.diff;

    final String text;
    if (isLoading && diff == null) {
      text = l10n.topicConfigComparisonInProgress;
    } else if (diff == null) {
      return const SizedBox.shrink();
    } else if (diff.differenceCount != null) {
      text = l10n.topicConfigDifferencesCount(diff.differenceCount!);
    } else {
      text = l10n.topicConfigDifferencesUnknown;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SingleConfigBody extends StatelessWidget {
  final TopicConfigController controller;
  final AppLocalizations l10n;

  const _SingleConfigBody({required this.controller, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.left.snapshot;
    if (controller.left.isLoading && snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot == null ||
        snapshot.availability != TopicConfigAvailability.available) {
      return const SizedBox.shrink();
    }
    if (snapshot.entries.isEmpty) {
      return Center(child: Text(l10n.topicConfigEmptyReported));
    }
    final entries = controller.visibleSingleEntries;
    if (entries.isEmpty) {
      return Center(child: Text(l10n.topicConfigEmptyNonDefaultFilter));
    }

    return Column(
      children: [
        _TableHeaderRow(
          columns: [
            _HeaderColumn(l10n.topicConfigColumnName, flex: 3),
            _HeaderColumn(l10n.topicConfigColumnValue, flex: 3),
            _HeaderColumn(l10n.topicConfigColumnSource, flex: 2),
            _HeaderColumn(l10n.topicConfigColumnDefault, flex: 1),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _SingleEntryRow(entry: entry, l10n: l10n);
            },
          ),
        ),
      ],
    );
  }
}

class _CompareConfigBody extends StatelessWidget {
  final TopicConfigController controller;
  final AppLocalizations l10n;

  const _CompareConfigBody({required this.controller, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final diff = controller.diff;
    if (diff == null) {
      if (controller.left.isLoading ||
          (controller.compare?.right.isLoading ?? false)) {
        return const Center(child: CircularProgressIndicator());
      }
      return const SizedBox.shrink();
    }
    if (diff.rows.isEmpty) {
      return Center(child: Text(l10n.topicConfigEmptyReported));
    }
    final rows = controller.visibleDiffRows;
    if (rows.isEmpty) {
      return Center(child: Text(l10n.topicConfigEmptyDiffFilter));
    }

    final leftAvailable =
        controller.left.snapshot?.availability ==
        TopicConfigAvailability.available;
    final rightAvailable =
        controller.compare?.right.snapshot?.availability ==
        TopicConfigAvailability.available;

    return Column(
      children: [
        _TableHeaderRow(
          columns: [
            _HeaderColumn(l10n.topicConfigColumnName, flex: 3),
            _HeaderColumn(l10n.topicConfigColumnLeftValue, flex: 2),
            _HeaderColumn(l10n.topicConfigColumnLeftSource, flex: 2),
            _HeaderColumn(l10n.topicConfigColumnRightValue, flex: 2),
            _HeaderColumn(l10n.topicConfigColumnRightSource, flex: 2),
            _HeaderColumn(l10n.topicConfigColumnStatus, flex: 2),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return _DiffEntryRow(
                row: row,
                leftAvailable: leftAvailable,
                rightAvailable: rightAvailable,
                l10n: l10n,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderColumn {
  final String label;
  final int flex;

  const _HeaderColumn(this.label, {required this.flex});
}

class _TableHeaderRow extends StatelessWidget {
  final List<_HeaderColumn> columns;

  const _TableHeaderRow({required this.columns});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final col in columns)
            Expanded(
              flex: col.flex,
              child: Text(
                col.label,
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _SingleEntryRow extends StatelessWidget {
  final TopicConfigEntry entry;
  final AppLocalizations l10n;

  const _SingleEntryRow({required this.entry, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueText = topicConfigValueLabel(entry, l10n);
    final mutedValue = entry.isSensitive || entry.value == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SelectableText(
              entry.name,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: SelectableText(
              valueText,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: mutedValue ? null : 'monospace',
                fontStyle: mutedValue ? FontStyle.italic : null,
                color: mutedValue ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              topicConfigSourceLabel(entry.source, l10n),
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              entry.isDefault
                  ? l10n.topicConfigDefaultYes
                  : l10n.topicConfigDefaultNo,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffEntryRow extends StatelessWidget {
  final TopicConfigDiffRow row;
  final bool leftAvailable;
  final bool rightAvailable;
  final AppLocalizations l10n;

  const _DiffEntryRow({
    required this.row,
    required this.leftAvailable,
    required this.rightAvailable,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leftSource = row.left != null
        ? topicConfigSourceLabel(row.left!.source, l10n)
        : (leftAvailable
              ? l10n.topicConfigPlaceholderNoValue
              : l10n.topicConfigPlaceholderUnknown);
    final rightSource = row.right != null
        ? topicConfigSourceLabel(row.right!.source, l10n)
        : (rightAvailable
              ? l10n.topicConfigPlaceholderNoValue
              : l10n.topicConfigPlaceholderUnknown);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SelectableText(
              row.name,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: SelectableText(
              topicConfigValueLabel(
                row.left,
                l10n,
                sideAvailable: leftAvailable,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              leftSource,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: SelectableText(
              topicConfigValueLabel(
                row.right,
                l10n,
                sideAvailable: rightAvailable,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              rightSource,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: _StatusBadge(
              status: row.status,
              label: topicConfigStatusLabel(row.status, l10n),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TopicConfigDiffStatus status;
  final String label;

  const _StatusBadge({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = switch (status) {
      TopicConfigDiffStatus.equal => (
        Icons.check_circle_outline,
        colorScheme.onSurfaceVariant,
      ),
      TopicConfigDiffStatus.different => (
        Icons.compare_arrows,
        colorScheme.primary,
      ),
      TopicConfigDiffStatus.onlyLeft => (
        Icons.arrow_back,
        colorScheme.tertiary,
      ),
      TopicConfigDiffStatus.onlyRight => (
        Icons.arrow_forward,
        colorScheme.tertiary,
      ),
      TopicConfigDiffStatus.notComparable => (
        Icons.lock_outline,
        colorScheme.secondary,
      ),
      TopicConfigDiffStatus.unknown => (Icons.help_outline, colorScheme.error),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
