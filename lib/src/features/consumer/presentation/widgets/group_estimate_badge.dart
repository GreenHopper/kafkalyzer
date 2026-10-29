import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import '../../domain/consumer_lag_estimate.dart';

/// Renders the processing rate and backlog recovery estimate for a consumer group.
class GroupEstimateBadge extends StatelessWidget {
  final int? delta;
  final String formattedDelta;
  final ConsumerLagEstimate? estimate;
  final AppLocalizations l10n;

  const GroupEstimateBadge({
    super.key,
    required this.delta,
    required this.formattedDelta,
    this.estimate,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    if (delta == null && estimate == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "-",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }

    final status = estimate?.status ?? LagProcessingStatus.pending;
    final Color color;
    final String displayText;

    switch (status) {
      case LagProcessingStatus.caughtUp:
        color = Colors.green;
        displayText = l10n.lagEstimateCaughtUp;
        break;

      case LagProcessingStatus.draining:
        color = Colors.green;
        final eta = ConsumerLagEstimate.formatEta(
          estimate?.estimatedTimeToClear,
        );
        if (eta.isNotEmpty) {
          displayText = l10n.lagEstimateEtaPrefix(eta);
        } else {
          displayText = formattedDelta.isNotEmpty ? formattedDelta : "-";
        }
        break;

      case LagProcessingStatus.accumulating:
        color = Colors.orange;
        displayText = l10n.lagEstimateGrowing;
        break;

      case LagProcessingStatus.stalled:
        color = Theme.of(context).colorScheme.outline;
        displayText = l10n.lagEstimateStalled;
        break;

      case LagProcessingStatus.pending:
        if (delta != null && formattedDelta.isNotEmpty) {
          if (delta! > 0) {
            color = Colors.red;
          } else if (delta! < 0) {
            color = Colors.green;
          } else {
            color = Theme.of(context).colorScheme.outline;
          }
          displayText = formattedDelta;
        } else {
          color = Theme.of(context).colorScheme.outline;
          displayText = "-";
        }
        break;
    }

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: color,
        ),
      ),
    );

    final tooltipText = _buildTooltip(context);
    if (tooltipText != null && tooltipText.isNotEmpty) {
      return Tooltip(message: tooltipText, child: badge);
    }

    return badge;
  }

  String? _buildTooltip(BuildContext context) {
    if (estimate == null) return null;

    final rateStr = ConsumerLagEstimate.formatRate(
      estimate!.ratePerSecond,
      unit: l10n.lagEstimateRateUnit,
    );

    final deltaStr = formattedDelta.isNotEmpty
        ? formattedDelta
        : (estimate!.observedLagDelta != null
              ? (estimate!.observedLagDelta! > 0
                    ? "+${estimate!.observedLagDelta}"
                    : "${estimate!.observedLagDelta}")
              : "-");

    final intervalStr = estimate!.elapsedDuration != null
        ? '${(estimate!.elapsedDuration!.inMilliseconds / 1000.0).toStringAsFixed(1)}s'
        : '-';

    final statusStr = switch (estimate!.status) {
      LagProcessingStatus.caughtUp => l10n.lagEstimateCaughtUp,
      LagProcessingStatus.draining =>
        estimate!.estimatedTimeToClear != null
            ? l10n.lagEstimateEtaPrefix(
                ConsumerLagEstimate.formatEta(estimate!.estimatedTimeToClear),
              )
            : 'Draining',
      LagProcessingStatus.accumulating => l10n.lagEstimateGrowing,
      LagProcessingStatus.stalled => l10n.lagEstimateStalled,
      LagProcessingStatus.pending => l10n.lagEstimatePending,
    };

    return l10n.lagEstimateTooltip(rateStr, deltaStr, intervalStr, statusStr);
  }
}
