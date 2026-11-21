import 'dart:async';
import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-demand, read-only estimated partition offset distribution view.
///
/// Fetches low/high watermarks for a single topic when mounted or refreshed and
/// presents offset spans (`high - low`) and shares without starting any consumer
/// scan or claiming exact message counts.
class PartitionOffsetDistributionView extends StatefulWidget {
  final ClusterProfile profile;
  final String topicName;
  final String? cleanupPolicy;
  final VoidCallback? onOpenAnalysis;

  /// Session-wide collaborators; null falls back to the application container.
  final ActiveConnectionController? connectionController;
  final KafkaMetadataService? kafkaMetadata;

  const PartitionOffsetDistributionView({
    super.key,
    required this.profile,
    required this.topicName,
    this.cleanupPolicy,
    this.onOpenAnalysis,
    this.connectionController,
    this.kafkaMetadata,
  });

  @override
  State<PartitionOffsetDistributionView> createState() =>
      _PartitionOffsetDistributionViewState();
}

class _PartitionOffsetDistributionViewState
    extends State<PartitionOffsetDistributionView> {
  static const double _rowHeight = 40.0;
  static const double _maxListHeight = 240.0;

  PartitionOffsetDistribution? _distribution;
  String? _loadError;
  String? _refreshError;
  bool _isLoading = false;
  bool _isStale = false;
  ActiveConnectionController? _connectionController;

  @override
  void initState() {
    super.initState();
    final connection =
        widget.connectionController ??
        (getIt.isRegistered<ActiveConnectionController>()
            ? getIt<ActiveConnectionController>()
            : null);
    if (connection != null) {
      _connectionController = connection;
      connection.addListener(_onConnectionChanged);
    }
    unawaited(_loadOffsets());
  }

  @override
  void didUpdateWidget(covariant PartitionOffsetDistributionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.name != widget.profile.name ||
        oldWidget.topicName != widget.topicName) {
      _distribution = null;
      _loadError = null;
      _refreshError = null;
      _isStale = false;
      unawaited(_loadOffsets());
    }
  }

  @override
  void dispose() {
    _connectionController?.removeListener(_onConnectionChanged);
    super.dispose();
  }

  void _onConnectionChanged() {
    if (!mounted || _distribution == null) return;
    final activeName = _connectionController?.activeProfile?.name;
    final stale = activeName != widget.profile.name;
    if (stale != _isStale) {
      setState(() {
        _isStale = stale;
      });
    }
  }

  Future<int> _readSkewThreshold() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SettingsService.readInt(
        prefs,
        SettingsService.partitionSkewThresholdSetting,
      );
    } catch (_) {
      return SettingsService.partitionSkewThresholdSetting.defaultValue;
    }
  }

  Future<void> _loadOffsets() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
      _refreshError = null;
    });

    try {
      final threshold = await _readSkewThreshold();
      final metadataService =
          widget.kafkaMetadata ?? getIt<KafkaMetadataService>();
      final result = await metadataService.fetchPartitionOffsets(
        profile: widget.profile,
        topic: widget.topicName,
        skewThresholdPercent: threshold,
      );
      if (!mounted) return;
      final activeName = _connectionController?.activeProfile?.name;
      setState(() {
        _distribution = result;
        _isLoading = false;
        _loadError = null;
        _refreshError = null;
        _isStale =
            _connectionController != null && activeName != widget.profile.name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_distribution == null) {
          _loadError = e.toString();
        } else {
          _refreshError = e.toString();
        }
      });
    }
  }

  bool get _isCompactedTopic {
    final raw = widget.cleanupPolicy;
    if (raw == null) return false;
    return raw
        .split(',')
        .map((part) => part.trim().toLowerCase())
        .contains('compact');
  }

  bool get _isPolicyUnknown {
    final raw = widget.cleanupPolicy;
    return raw == null || raw.trim().isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final numFmt = NumberFormat.decimalPattern(locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context, l10n, theme, locale),
        const SizedBox(height: 8),
        if (_isLoading && _distribution == null)
          _buildInitialLoading(l10n, theme)
        else if (_loadError != null && _distribution == null)
          _buildInitialError(l10n, theme)
        else if (_distribution != null)
          _buildContent(context, l10n, theme, numFmt, _distribution!),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    String locale,
  ) {
    final dist = _distribution;
    final threshold =
        dist?.skewThresholdPercent ??
        SettingsService.partitionSkewThresholdSetting.defaultValue;

    return Row(
      children: [
        Icon(
          Icons.bar_chart_outlined,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.partitionOffsetSectionTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (dist != null && dist.skewStatus == OffsetSkewStatus.skewed)
                Container(
                  key: const Key('partition_offset_skew_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.partitionOffsetSkewBadge(threshold),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (dist != null) ...[
          Text(
            l10n.partitionOffsetReadAt(
              DateFormat.Hms(
                locale,
              ).format(DateTime.fromMillisecondsSinceEpoch(dist.readAtMs)),
            ),
            key: const Key('partition_offset_read_at'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
        ],
        if (_isLoading && dist != null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        IconButton(
          key: const Key('partition_offset_refresh_button'),
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: l10n.partitionOffsetRefreshTooltip,
          onPressed: _isLoading ? null : _loadOffsets,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildInitialLoading(AppLocalizations l10n, ThemeData theme) {
    return Padding(
      key: const Key('partition_offset_loading'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            l10n.partitionOffsetLoading,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialError(AppLocalizations l10n, ThemeData theme) {
    return Container(
      key: const Key('partition_offset_error'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.partitionOffsetLoadError(_loadError!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('partition_offset_retry_button'),
            onPressed: _loadOffsets,
            child: Text(l10n.partitionOffsetRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    NumberFormat numFmt,
    PartitionOffsetDistribution dist,
  ) {
    final threshold =
        dist.skewThresholdPercent ??
        SettingsService.partitionSkewThresholdSetting.defaultValue;
    final listHeight = math.min(
      dist.partitions.length * _rowHeight,
      _maxListHeight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isStale)
          _buildNoticeBanner(
            key: const Key('partition_offset_stale_banner'),
            icon: Icons.link_off,
            text: l10n.partitionOffsetStaleNotice,
            background: theme.colorScheme.secondaryContainer,
            foreground: theme.colorScheme.onSecondaryContainer,
            theme: theme,
          ),
        if (_refreshError != null)
          _buildNoticeBanner(
            key: const Key('partition_offset_refresh_error'),
            icon: Icons.error_outline,
            text: l10n.partitionOffsetReadFailed(_refreshError!),
            background: theme.colorScheme.errorContainer,
            foreground: theme.colorScheme.onErrorContainer,
            theme: theme,
          ),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              dist.complete && dist.totalSpan != null
                  ? l10n.partitionOffsetTotalSpan(
                      numFmt.format(dist.totalSpan!),
                    )
                  : l10n.partitionOffsetKnownSpan(
                      numFmt.format(dist.knownSpan),
                    ),
              key: const Key('partition_offset_span_summary'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              l10n.partitionOffsetEstimateNote,
              key: const Key('partition_offset_estimate_note'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (_isCompactedTopic) ...[
          const SizedBox(height: 6),
          _buildInlineNote(
            key: const Key('partition_offset_compacted_note'),
            icon: Icons.compress,
            text: l10n.partitionOffsetCompactedNote,
            color: theme.colorScheme.tertiary,
            theme: theme,
          ),
        ] else if (_isPolicyUnknown) ...[
          const SizedBox(height: 6),
          _buildInlineNote(
            key: const Key('partition_offset_policy_unknown_note'),
            icon: Icons.help_outline,
            text: l10n.partitionOffsetPolicyUnknownNote,
            color: theme.colorScheme.onSurfaceVariant,
            theme: theme,
          ),
        ],
        if (!dist.complete) ...[
          const SizedBox(height: 6),
          _buildInlineNote(
            key: const Key('partition_offset_incomplete_note'),
            icon: Icons.info_outline,
            text: l10n.partitionOffsetIncompleteNote,
            color: theme.colorScheme.tertiary,
            theme: theme,
          ),
        ],
        if (dist.skewStatus == OffsetSkewStatus.empty) ...[
          const SizedBox(height: 6),
          _buildInlineNote(
            key: const Key('partition_offset_empty_note'),
            icon: Icons.inbox_outlined,
            text: l10n.partitionOffsetEmptyNote,
            color: theme.colorScheme.onSurfaceVariant,
            theme: theme,
          ),
        ],
        const SizedBox(height: 8),
        if (dist.partitions.isNotEmpty) ...[
          _buildTableHeader(l10n, theme),
          const Divider(height: 1),
          SizedBox(
            height: listHeight,
            child: ListView.builder(
              key: const Key('partition_offset_list'),
              itemCount: dist.partitions.length,
              itemExtent: _rowHeight,
              itemBuilder: (context, index) => _buildRow(
                l10n: l10n,
                theme: theme,
                numFmt: numFmt,
                row: dist.partitions[index],
                threshold: threshold,
              ),
            ),
          ),
        ],
        if (widget.onOpenAnalysis != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('partition_offset_open_analysis_button'),
              onPressed: widget.onOpenAnalysis,
              icon: const Icon(Icons.analytics_outlined, size: 16),
              label: Text(l10n.partitionOffsetOpenAnalysisAction),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoticeBanner({
    required Key key,
    required IconData icon,
    required String text,
    required Color background,
    required Color foreground,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineNote({
    required Key key,
    required IconData icon,
    required String text,
    required Color color,
    required ThemeData theme,
  }) {
    return Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(AppLocalizations l10n, ThemeData theme) {
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(l10n.partitionOffsetColumnPartition, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l10n.partitionOffsetColumnLow,
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l10n.partitionOffsetColumnHigh,
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l10n.partitionOffsetColumnSpan,
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(l10n.partitionOffsetColumnShare, style: style),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required AppLocalizations l10n,
    required ThemeData theme,
    required NumberFormat numFmt,
    required PartitionOffsetRow row,
    required int threshold,
  }) {
    final isKnown = row.state == PartitionOffsetState.known;
    final unknown = l10n.partitionOffsetUnknownValue;

    return Container(
      key: Key('partition_offset_row_${row.partition}'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              numFmt.format(row.partition),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isKnown && row.low != null ? numFmt.format(row.low!) : unknown,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isKnown && row.high != null ? numFmt.format(row.high!) : unknown,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isKnown && row.span != null ? numFmt.format(row.span!) : unknown,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: _buildShareOrStateCell(
              l10n: l10n,
              theme: theme,
              row: row,
              threshold: threshold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareOrStateCell({
    required AppLocalizations l10n,
    required ThemeData theme,
    required PartitionOffsetRow row,
    required int threshold,
  }) {
    if (row.state == PartitionOffsetState.known) {
      final share = row.sharePercent;
      if (share == null) {
        return Text(
          l10n.partitionOffsetUnknownValue,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      }
      final barColor = row.skewed
          ? theme.colorScheme.tertiary
          : theme.colorScheme.primary;
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (share / 100.0).clamp(0.0, 1.0),
                minHeight: 6,
                color: barColor,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            child: Text(
              '${share.toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: row.skewed ? theme.colorScheme.tertiary : null,
                fontWeight: row.skewed ? FontWeight.w600 : null,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          if (row.skewed) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: l10n.partitionOffsetSkewRowTooltip(threshold),
              child: Icon(
                Icons.warning_amber_rounded,
                key: Key('partition_offset_skew_icon_${row.partition}'),
                size: 16,
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ],
      );
    }

    final stateLabel = switch (row.state) {
      PartitionOffsetState.notReadable => l10n.partitionOffsetStateNotReadable,
      PartitionOffsetState.failed => l10n.partitionOffsetStateFailed,
      PartitionOffsetState.timedOut => l10n.partitionOffsetStateTimedOut,
      PartitionOffsetState.known => '',
    };

    final label = Text(
      stateLabel,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.tertiary,
      ),
      overflow: TextOverflow.ellipsis,
    );

    if (row.error != null && row.error!.isNotEmpty) {
      return Tooltip(message: row.error!, child: label);
    }
    return label;
  }
}
