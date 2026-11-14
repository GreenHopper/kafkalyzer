import 'package:material_ui/material_ui.dart' hide StepState;
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/connection_diagnostics.dart';

class ConnectionDiagnosticsPanel extends StatelessWidget {
  final ConnectionDiagnosis diagnosis;

  const ConnectionDiagnosticsPanel({super.key, required this.diagnosis});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (overallIcon, overallColor, overallText) = _overallSummary(
      l10n,
      colorScheme,
    );

    return Material(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: diagnosis.outcome == DiagnosisOutcome.ok
              ? colorScheme.primary.withValues(alpha: 0.4)
              : colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Semantics(
                  label: overallText,
                  child: Icon(overallIcon, color: overallColor, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    overallText,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: overallColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (diagnosis.outcome == DiagnosisOutcome.failedStageUnknown &&
                diagnosis.unattributed.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.diagRawErrorLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                diagnosis.unattributed.join('\n'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            for (final stage in diagnosis.stages)
              _buildStageRow(context, l10n, stage),
          ],
        ),
      ),
    );
  }

  (IconData, Color, String) _overallSummary(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    switch (diagnosis.outcome) {
      case DiagnosisOutcome.ok:
        return (
          Icons.check_circle_outline,
          colorScheme.primary,
          l10n.diagOverallOk,
        );
      case DiagnosisOutcome.failed:
        final failedStage = diagnosis.stages.cast<StageResult?>().firstWhere(
          (s) => s?.state == StageState.failed,
          orElse: () => null,
        );
        final text = failedStage != null
            ? l10n.diagOverallFailedAtStage(_stageName(l10n, failedStage.stage))
            : l10n.diagOverallStageUnknown;
        return (Icons.error_outline, colorScheme.error, text);
      case DiagnosisOutcome.failedStageUnknown:
        return (
          Icons.help_outline,
          colorScheme.error,
          l10n.diagOverallStageUnknown,
        );
    }
  }

  Widget _buildStageRow(
    BuildContext context,
    AppLocalizations l10n,
    StageResult stage,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stateLabel = _stateName(l10n, stage.state);
    final (icon, iconColor) = _stageVisual(stage.state, colorScheme);
    final hintText = _stageHintText(l10n, stage);

    final header = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                label: stateLabel,
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _stageName(l10n, stage.stage),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                stateLabel,
                style: theme.textTheme.labelMedium?.copyWith(color: iconColor),
              ),
            ],
          ),
          if (hintText != null)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 2),
              child: Text(
                hintText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (stage.raw != null && stage.raw!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.diagRawErrorLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SelectableText(
                    stage.raw!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (stage.stage == DiagnosisStage.network && stage.servers.isNotEmpty) {
      return Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(left: 26, bottom: 6),
          dense: true,
          initiallyExpanded: stage.state == StageState.failed,
          title: header,
          children: [
            for (final server in stage.servers)
              _buildServerRow(context, l10n, server),
          ],
        ),
      );
    }

    return header;
  }

  Widget _buildServerRow(
    BuildContext context,
    AppLocalizations l10n,
    ServerCheck server,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dnsLabel = _stepLabel(l10n, server.dns);
    final tcpLabel = _stepLabel(l10n, server.tcp);
    final (dnsIcon, dnsColor) = _stepVisual(server.dns, colorScheme);
    final (tcpIcon, tcpColor) = _stepVisual(server.tcp, colorScheme);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            server.entry,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: '${l10n.diagServerDnsLabel}: $dnsLabel',
                    child: Icon(dnsIcon, size: 14, color: dnsColor),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${l10n.diagServerDnsLabel}: $dnsLabel',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: '${l10n.diagServerTcpLabel}: $tcpLabel',
                    child: Icon(tcpIcon, size: 14, color: tcpColor),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${l10n.diagServerTcpLabel}: $tcpLabel',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          if (server.addresses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${l10n.diagServerResolvedLabel}: ${server.addresses.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (server.connectedAddress != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                l10n.diagServerConnectedTo(server.connectedAddress!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (server.hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _hintText(l10n, server.hint!, null),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (server.raw != null && server.raw!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.diagRawErrorLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SelectableText(
                    server.raw!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String? _stageHintText(AppLocalizations l10n, StageResult stage) {
    if (stage.state == StageState.notChecked &&
        stage.notCheckedReason != null) {
      switch (stage.notCheckedReason!) {
        case NotCheckedReason.previousStageFailed:
          final failedStage = diagnosis.stages.cast<StageResult?>().firstWhere(
            (s) => s?.state == StageState.failed,
            orElse: () => null,
          );
          final prevName = failedStage != null
              ? _stageName(l10n, failedStage.stage)
              : _stageName(l10n, DiagnosisStage.network);
          return l10n.diagNotCheckedPreviousFailed(prevName);
        case NotCheckedReason.budgetExhausted:
          return l10n.diagNotCheckedBudgetExhausted;
      }
    }
    if (stage.hint != null) {
      return _hintText(l10n, stage.hint!, stage.httpStatus);
    }
    return null;
  }

  String _stageName(AppLocalizations l10n, DiagnosisStage stage) {
    switch (stage) {
      case DiagnosisStage.network:
        return l10n.diagStageNetwork;
      case DiagnosisStage.tls:
        return l10n.diagStageTls;
      case DiagnosisStage.authentication:
        return l10n.diagStageAuthentication;
      case DiagnosisStage.metadata:
        return l10n.diagStageMetadata;
      case DiagnosisStage.schemaRegistry:
        return l10n.diagStageSchemaRegistry;
    }
  }

  String _stateName(AppLocalizations l10n, StageState state) {
    switch (state) {
      case StageState.ok:
        return l10n.diagStateOk;
      case StageState.failed:
        return l10n.diagStateFailed;
      case StageState.notChecked:
        return l10n.diagStateNotChecked;
      case StageState.notApplicable:
        return l10n.diagStateNotApplicable;
      case StageState.undetermined:
        return l10n.diagStateUndetermined;
    }
  }

  String _stepLabel(AppLocalizations l10n, StepState state) {
    switch (state) {
      case StepState.ok:
        return l10n.diagStateOk;
      case StepState.failed:
        return l10n.diagStateFailed;
      case StepState.notChecked:
        return l10n.diagStateNotChecked;
    }
  }

  (IconData, Color) _stageVisual(StageState state, ColorScheme colorScheme) {
    switch (state) {
      case StageState.ok:
        return (Icons.check_circle_outline, colorScheme.primary);
      case StageState.failed:
        return (Icons.error_outline, colorScheme.error);
      case StageState.notChecked:
        return (Icons.remove_circle_outline, colorScheme.outline);
      case StageState.notApplicable:
        return (Icons.do_not_disturb_alt_outlined, colorScheme.outline);
      case StageState.undetermined:
        return (Icons.help_outline, colorScheme.tertiary);
    }
  }

  (IconData, Color) _stepVisual(StepState state, ColorScheme colorScheme) {
    switch (state) {
      case StepState.ok:
        return (Icons.check_circle_outline, colorScheme.primary);
      case StepState.failed:
        return (Icons.error_outline, colorScheme.error);
      case StepState.notChecked:
        return (Icons.remove_circle_outline, colorScheme.outline);
    }
  }

  String _hintText(AppLocalizations l10n, DiagnosisHint hint, int? httpStatus) {
    switch (hint) {
      case DiagnosisHint.invalidEntry:
        return l10n.diagHintInvalidEntry;
      case DiagnosisHint.hostUnknown:
        return l10n.diagHintHostUnknown;
      case DiagnosisHint.connectionRefused:
        return l10n.diagHintConnectionRefused;
      case DiagnosisHint.connectTimeout:
        return l10n.diagHintConnectTimeout;
      case DiagnosisHint.certificateRejected:
        return l10n.diagHintCertificateRejected;
      case DiagnosisHint.tlsHandshakeFailed:
        return l10n.diagHintTlsHandshakeFailed;
      case DiagnosisHint.protocolMismatch:
        return l10n.diagHintProtocolMismatch;
      case DiagnosisHint.authenticationFailed:
        return l10n.diagHintAuthenticationFailed;
      case DiagnosisHint.mechanismRejected:
        return l10n.diagHintMechanismRejected;
      case DiagnosisHint.notAuthorized:
        return l10n.diagHintNotAuthorized;
      case DiagnosisHint.requestTimeout:
        return l10n.diagHintRequestTimeout;
      case DiagnosisHint.registryUnreachable:
        return l10n.diagHintRegistryUnreachable;
      case DiagnosisHint.registryUnauthorized:
        return l10n.diagHintRegistryUnauthorized;
      case DiagnosisHint.registryHttpError:
        return l10n.diagHintRegistryHttpError(httpStatus ?? 0);
      case DiagnosisHint.generic:
        return l10n.diagHintGeneric;
    }
  }
}
