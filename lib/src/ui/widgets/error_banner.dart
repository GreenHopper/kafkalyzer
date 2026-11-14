import 'package:flutter/services.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/l10n/app_localizations_en.dart';
import 'package:material_ui/material_ui.dart';

/// Shared inline error banner with localized title, selectable detail text,
/// copy-to-clipboard action, optional retry button, and optional dismiss button.
class ErrorBanner extends StatelessWidget {
  final String title;
  final String? detail;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final String? copyLabel;
  final EdgeInsetsGeometry margin;

  const ErrorBanner({
    super.key,
    required this.title,
    this.detail,
    this.onDismiss,
    this.onRetry,
    this.retryLabel,
    this.copyLabel,
    this.margin = EdgeInsets.zero,
  });

  /// Copies [text] to the system clipboard and shows a localized feedback
  /// [SnackBar] on success or failure.
  static Future<void> copyText(BuildContext context, String text) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n?.copiedToClipboard ?? 'Copied to clipboard'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n?.copyFailed ?? 'Failed to copy to clipboard'),
        ),
      );
    }
  }

  Future<void> _copyError(BuildContext context) async {
    final trimmedDetail = detail?.trim();
    final payload = (trimmedDetail != null && trimmedDetail.isNotEmpty)
        ? '$title\n$trimmedDetail'
        : title;
    await copyText(context, payload);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trimmedDetail = detail?.trim();
    final hasDetail = trimmedDetail != null && trimmedDetail.isNotEmpty;

    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline,
              color: colorScheme.onErrorContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasDetail) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    trimmedDetail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => _copyError(context),
                      icon: Icon(
                        Icons.copy,
                        size: 16,
                        color: colorScheme.onErrorContainer,
                      ),
                      label: Text(
                        copyLabel ?? l10n?.copy ?? AppLocalizationsEn().copy,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                    if (onRetry != null)
                      TextButton(
                        onPressed: onRetry,
                        child: Text(
                          retryLabel ??
                              l10n?.retry ??
                              AppLocalizationsEn().retry,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: colorScheme.onErrorContainer,
              ),
              tooltip: l10n?.close ?? 'Close',
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
