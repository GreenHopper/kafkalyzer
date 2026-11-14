import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';

/// Kind of entry shown in the command palette.
///
/// Declaration order defines the tie-break priority in ranking (design D7).
enum PaletteEntryKind {
  reference,
  destination,
  cluster,
  topic,
  consumerGroup,
  script,
}

extension PaletteEntryKindUi on PaletteEntryKind {
  IconData get icon => switch (this) {
    PaletteEntryKind.reference => Icons.link,
    PaletteEntryKind.destination => Icons.dashboard_outlined,
    PaletteEntryKind.cluster => Icons.dns_outlined,
    PaletteEntryKind.topic => Icons.topic_outlined,
    PaletteEntryKind.consumerGroup => Icons.group_work_outlined,
    PaletteEntryKind.script => Icons.description_outlined,
  };

  String label(AppLocalizations l10n) => switch (this) {
    PaletteEntryKind.reference => l10n.commandPaletteKindReference,
    PaletteEntryKind.destination => l10n.commandPaletteKindDestination,
    PaletteEntryKind.cluster => l10n.commandPaletteKindCluster,
    PaletteEntryKind.topic => l10n.commandPaletteKindTopic,
    PaletteEntryKind.consumerGroup => l10n.commandPaletteKindConsumerGroup,
    PaletteEntryKind.script => l10n.commandPaletteKindScript,
  };
}

/// A single actionable item in the command palette.
class PaletteEntry {
  const PaletteEntry({
    required this.kind,
    required this.label,
    required this.run,
    this.subtitle,
    this.isOpenTab = false,
  });

  final PaletteEntryKind kind;
  final String label;
  final String? subtitle;
  final bool isOpenTab;
  final Future<void> Function() run;
}

/// A [PaletteEntry] paired with its fuzzy-match highlight indices and score.
class RankedPaletteEntry {
  const RankedPaletteEntry({
    required this.entry,
    required this.score,
    required this.matchedIndices,
  });

  final PaletteEntry entry;
  final double score;
  final List<int> matchedIndices;
}
