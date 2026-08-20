import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_analysis_report_file.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/hourly_production_chart.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/key_and_field_distribution_view.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/partition_balance_view.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_analysis_summary_cards.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

enum ScanScopeOption { full, sample10k, sample50k, sample100k }

class TopicAnalysisView extends StatefulWidget {
  final TopicMetadata topic;
  final ClusterProfile profile;
  final TopicAnalysisController controller;

  const TopicAnalysisView({
    super.key,
    required this.topic,
    required this.profile,
    required this.controller,
  });

  @override
  State<TopicAnalysisView> createState() => _TopicAnalysisViewState();
}

class _TopicAnalysisViewState extends State<TopicAnalysisView> {
  ScanScopeOption _selectedScope = ScanScopeOption.full;
  bool _importing = false;
  bool _exporting = false;

  bool get _busy => _importing || _exporting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isAnalyzing = widget.controller.isAnalyzing;
        final report = widget.controller.report;
        final error = widget.controller.error;

        return Column(
          children: [
            _buildControlsBar(context, colorScheme, l10n, isAnalyzing),
            if (isAnalyzing) _buildProgressBanner(context, colorScheme, l10n),
            if (error != null) _buildErrorBanner(context, colorScheme, error),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (report != null) ...[
                      TopicAnalysisSummaryCards(report: report),
                      const SizedBox(height: 16),
                      HourlyProductionChart(
                        hourlyDistribution: report.hourlyDistribution,
                      ),
                      const SizedBox(height: 16),
                      PartitionBalanceView(
                        partitionStats: report.partitionStats,
                        totalMessages: report.totalMessages,
                      ),
                      const SizedBox(height: 16),
                      KeyAndFieldDistributionView(
                        topKeys: report.topKeys,
                        contentTypes: report.contentTypeDistribution,
                        fieldFrequencies: report.fieldFrequencies,
                      ),
                    ] else if (!isAnalyzing) ...[
                      _buildEmptyState(context, colorScheme, l10n, theme),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlsBar(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
    bool isAnalyzing,
  ) {
    return Material(
      color: colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${l10n?.scanScope ?? 'Scan Scope'}:',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                DropdownButton<ScanScopeOption>(
                  value: _selectedScope,
                  onChanged: isAnalyzing
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _selectedScope = val);
                          }
                        },
                  items: [
                    DropdownMenuItem(
                      value: ScanScopeOption.full,
                      child: Text(
                        l10n?.fullTopicScan ?? 'Full Scan (All Messages)',
                      ),
                    ),
                    DropdownMenuItem(
                      value: ScanScopeOption.sample10k,
                      child: Text(
                        l10n?.sampleLast10k ?? 'Sample Last 10,000 Messages',
                      ),
                    ),
                    DropdownMenuItem(
                      value: ScanScopeOption.sample50k,
                      child: Text(
                        l10n?.sampleLast50k ?? 'Sample Last 50,000 Messages',
                      ),
                    ),
                    DropdownMenuItem(
                      value: ScanScopeOption.sample100k,
                      child: Text(
                        l10n?.sampleLast100k ?? 'Sample Last 100,000 Messages',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (widget.controller.isImported) _buildImportedChip(context, l10n),
            _buildImportButton(context, l10n),
            _buildExportButton(context, l10n),
            if (isAnalyzing)
              FilledButton.tonalIcon(
                onPressed: () => widget.controller.stopAnalysis(),
                icon: const Icon(Icons.stop_rounded),
                label: Text(l10n?.stopAnalysis ?? 'Stop Analysis'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                ),
              )
            else
              FilledButton.icon(
                onPressed: _busy ? null : _startScan,
                icon: const Icon(Icons.analytics_outlined),
                label: Text(l10n?.startAnalysis ?? 'Start Analysis'),
              ),
          ],
        ),
      ),
    );
  }

  void _startScan() {
    int? maxMsgs;
    switch (_selectedScope) {
      case ScanScopeOption.full:
        maxMsgs = null;
        break;
      case ScanScopeOption.sample10k:
        maxMsgs = 10000;
        break;
      case ScanScopeOption.sample50k:
        maxMsgs = 50000;
        break;
      case ScanScopeOption.sample100k:
        maxMsgs = 100000;
        break;
    }

    widget.controller.startAnalysis(
      widget.profile,
      widget.topic.name,
      maxMessages: maxMsgs,
      sampleFromLatest: true,
    );
  }

  Widget _buildImportedChip(BuildContext context, AppLocalizations? l10n) {
    final cluster = widget.controller.reportClusterName;
    final time = widget.controller.reportExportedAt;
    final clusterStr = (cluster != null && cluster.isNotEmpty)
        ? cluster
        : (l10n?.unknownCluster ?? 'unknown cluster');
    final timeStr = time != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(time.toLocal())
        : '';
    final label = l10n?.importedFromTime(clusterStr, timeStr) ?? 'Imported';
    return Chip(
      avatar: const Icon(Icons.file_download_outlined, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildImportButton(BuildContext context, AppLocalizations? l10n) {
    return FilledButton.tonalIcon(
      onPressed: _busy ? null : _onImport,
      icon: _importing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.file_open_outlined),
      label: Text(l10n?.importAnalysisReport ?? 'Import Analysis Report'),
    );
  }

  Widget _buildExportButton(BuildContext context, AppLocalizations? l10n) {
    final canExport = widget.controller.report != null && !_busy;
    return FilledButton.icon(
      onPressed: canExport ? _onExport : null,
      icon: _exporting
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_alt_outlined),
      label: Text(l10n?.exportAnalysisReport ?? 'Export Analysis Report'),
    );
  }

  Future<void> _onImport() async {
    setState(() => _importing = true);
    final ok = await widget.controller.importReport();
    if (!mounted) return;
    setState(() => _importing = false);
    final l10n = AppLocalizations.of(context);
    if (ok) {
      _showSnackBar(
        l10n?.analysisImportedSuccessfully ?? 'Analysis report imported',
      );
    } else if (widget.controller.importErrorKind != null) {
      _showSnackBar(_importErrorMessage(l10n));
    }
    // Cancelled: no message.
  }

  Future<void> _onExport() async {
    if (widget.controller.report == null) return;
    setState(() => _exporting = true);
    try {
      final path = await widget.controller.exportReport(
        clusterName: widget.profile.name,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      if (path != null) {
        _showSnackBar(
          l10n?.analysisExportedSuccessfully ?? 'Analysis report exported',
        );
      }
      // null: user cancelled the save dialog.
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _showSnackBar(l10n?.exportFailed ?? 'Failed to export');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _importErrorMessage(AppLocalizations? l10n) {
    final kind = widget.controller.importErrorKind;
    if (kind == TopicAnalysisImportErrorKind.unsupportedVersion) {
      final version =
          widget.controller.importErrorFoundVersion?.toString() ?? '?';
      return l10n?.importUnsupportedVersion(version) ?? 'Unsupported version';
    }
    if (kind == TopicAnalysisImportErrorKind.notAnAnalysisFile) {
      return l10n?.importNotAValidAnalysisFile ?? 'Not a valid analysis file';
    }
    return l10n?.importMalformed ?? 'Could not read file';
  }

  Widget _buildProgressBanner(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
  ) {
    final numberFormat = NumberFormat.decimalPattern();
    final scanned = widget.controller.scannedMessages;
    final total = widget.controller.totalMessagesToScan;
    final progress = widget.controller.progressRatio;
    final mps = widget.controller.messagesPerSecond;
    final etaText = _computeEta(scanned, total, progress, mps);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress > 0 ? progress : null,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '${l10n?.analyzingTopic ?? 'Analyzing topic...'} '
                  '(${numberFormat.format(scanned)} / ${numberFormat.format(total)} messages • ${(progress * 100).toStringAsFixed(1)}%)',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              if (mps > 0)
                Text(
                  '${numberFormat.format(mps.round())} msgs/sec',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              if (etaText != null) ...[
                if (mps > 0) const SizedBox(width: 12),
                Text(
                  etaText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  String? _computeEta(int scanned, int total, double progress, double mps) {
    if (total <= 0 || progress <= 0 || progress >= 1.0) return null;

    int remainingSeconds;
    if (mps > 0) {
      remainingSeconds = ((total - scanned) / mps).round();
    } else if (widget.controller.startTime != null) {
      final elapsedSeconds = DateTime.now()
          .difference(widget.controller.startTime!)
          .inSeconds;
      if (elapsedSeconds <= 0) return null;
      final totalEstimated = elapsedSeconds / progress;
      remainingSeconds = (totalEstimated - elapsedSeconds).round();
    } else {
      return null;
    }

    if (remainingSeconds <= 0) return null;
    if (remainingSeconds < 60) return '~$remainingSeconds s';
    return '~${remainingSeconds ~/ 60} m';
  }

  Widget _buildErrorBanner(
    BuildContext context,
    ColorScheme colorScheme,
    String error,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.insights_rounded,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.topicAnalysis ?? 'Topic Content Analysis',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                l10n?.noAnalysisYet ??
                    'No analysis data yet. Click Start Analysis to profile message volume, peak hours, partition balance, and key distributions.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n?.startAnalysis ?? 'Start Analysis'),
            ),
          ],
        ),
      ),
    );
  }
}
