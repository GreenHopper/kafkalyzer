import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

/// Interactive security guidance dialog detailing kafkalyzer's read-only invariants
/// and recommended least-privilege Kafka service account ACL configurations.
class ReadOnlyGuidanceDialog extends StatelessWidget {
  const ReadOnlyGuidanceDialog({super.key});

  static const String topicAclCommand =
      'kafka-acls.sh --bootstrap-server <bootstrap:9092> \\\n'
      '  --add --allow-principal User:<service_account> \\\n'
      '  --operation Describe --operation Read --operation DescribeConfigs \\\n'
      '  --topic "*"';

  static const String groupAclCommand =
      'kafka-acls.sh --bootstrap-server <bootstrap:9092> \\\n'
      '  --add --allow-principal User:<service_account> \\\n'
      '  --operation Describe \\\n'
      '  --group "*"';

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const ReadOnlyGuidanceDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.readOnlySecurityTitle)),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.readOnlySecurityDescription,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                l10n.readOnlyAclRecommendationTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.readOnlyAclRecommendationDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.readOnlyAclCommandTopicLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _buildCodeContainer(context, topicAclCommand),
              const SizedBox(height: 16),
              Text(
                l10n.readOnlyAclCommandGroupLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _buildCodeContainer(context, groupAclCommand),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () {
            final allCommands = '$topicAclCommand\n\n$groupAclCommand';
            Clipboard.setData(ClipboardData(text: allCommands));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.readOnlyAclCommandsCopied),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.copy, size: 16),
          label: Text(l10n.readOnlyCopyCommand),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  Widget _buildCodeContainer(BuildContext context, String code) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: SelectableText(
        code,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// A subtle, non-intrusive trust badge communicating kafkalyzer's read-only guarantee.
///
/// Clicking or tapping the badge opens [ReadOnlyGuidanceDialog].
class ReadOnlySecurityBadge extends StatelessWidget {
  final bool showLabel;

  const ReadOnlySecurityBadge({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final labelText = l10n?.readOnlyBadgeLabel ?? 'Read-Only';
    final tooltipText =
        l10n?.readOnlyBadgeTooltip ??
        'kafkalyzer is strictly read-only by design. No write, publish, or offset commit operations are performed.';

    return Tooltip(
      message: tooltipText,
      child: InkWell(
        onTap: () => ReadOnlyGuidanceDialog.show(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.secondary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
              if (showLabel) ...[
                const SizedBox(width: 6),
                Text(
                  labelText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
