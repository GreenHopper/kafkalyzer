import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_analysis_summary_cards.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/utils/schema_type_labels.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

extension TopicMetadataFacts on TopicMetadata {
  bool get metadataKnown => metadataError == null;
}

Future<void> openTopicByNameWithFeedback({
  required ActiveConnectionController controller,
  required ClusterProfile profile,
  required String topicName,
  ScaffoldMessengerState? messenger,
  AppLocalizations? l10n,
  bool forceNew = false,
}) async {
  try {
    await controller.openTopicByName(profile, topicName, forceNew: forceNew);
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          l10n?.topicOpenFailedNotice(topicName, e.toString()) ??
              'Could not open topic "$topicName": $e',
        ),
        action: SnackBarAction(
          label: l10n?.retry ?? 'Retry',
          onPressed: () {
            openTopicByNameWithFeedback(
              controller: controller,
              profile: profile,
              topicName: topicName,
              messenger: messenger,
              l10n: l10n,
              forceNew: forceNew,
            );
          },
        ),
      ),
    );
  }
}

bool hasSchema(
  SchemaController controller,
  ClusterProfile cluster,
  String topicName,
) {
  final schemas = controller.getSchemas(cluster);
  if (schemas == null) return false;
  return schemas.contains("$topicName-key") ||
      schemas.contains("$topicName-value");
}

/// Returns the localized schema badge label for [topicName] on [cluster],
/// or `null` when no schema exists for the topic and the subject list loaded.
String? resolveTopicSchemaLabel(
  AppLocalizations? l10n,
  SchemaController? controller,
  ClusterProfile cluster,
  String topicName,
) {
  if (controller == null) return null;
  final subjectListFailed =
      controller.errorFor(cluster) != null &&
      controller.getSchemas(cluster) == null;
  if (subjectListFailed) {
    return l10n?.schemaTypeUnknown ?? 'Schema (unknown)';
  }
  final schemas = controller.getSchemas(cluster);
  if (schemas == null) return null;
  final hasKey = schemas.contains('$topicName-key');
  final hasValue = schemas.contains('$topicName-value');
  if (!hasKey && !hasValue) return null;

  return topicSchemaBadgeLabel(
    l10n,
    keyState: hasKey
        ? controller.schemaTypeFor(cluster, '$topicName-key')
        : null,
    valueState: hasValue
        ? controller.schemaTypeFor(cluster, '$topicName-value')
        : null,
    subjectListFailed: false,
  );
}

(String prefix, String leaf) parseTopicNameSegments(String topicName) {
  final lastDotIndex = topicName.lastIndexOf('.');
  if (lastDotIndex != -1) {
    return (
      topicName.substring(0, lastDotIndex + 1),
      topicName.substring(lastDotIndex + 1),
    );
  }
  return ('', topicName);
}

class MiddleEllipsisIndices {
  final int headEnd;
  final int tailStart;

  const MiddleEllipsisIndices({required this.headEnd, required this.tailStart});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiddleEllipsisIndices &&
          runtimeType == other.runtimeType &&
          headEnd == other.headEnd &&
          tailStart == other.tailStart;

  @override
  int get hashCode => Object.hash(headEnd, tailStart);

  @override
  String toString() =>
      'MiddleEllipsisIndices(headEnd: $headEnd, tailStart: $tailStart)';
}

MiddleEllipsisIndices? computeMiddleEllipsisIndices(
  String topicName,
  int maxVisibleChars,
) {
  if (topicName.length <= maxVisibleChars || maxVisibleChars <= 0) {
    return null;
  }

  if (maxVisibleChars < 2) {
    return MiddleEllipsisIndices(headEnd: 1, tailStart: topicName.length);
  }

  final lastDotIndex = topicName.lastIndexOf('.');
  final prefixLen = (lastDotIndex != -1) ? lastDotIndex + 1 : 0;
  final leafLen = topicName.length - prefixLen;

  int tailLen;
  if (prefixLen == 0) {
    final headLen = (maxVisibleChars * 0.35).floor().clamp(
      1,
      maxVisibleChars - 1,
    );
    tailLen = maxVisibleChars - headLen;
  } else {
    final minPrefix = prefixLen > 6 ? 6 : prefixLen;
    final maxLeaf = maxVisibleChars - minPrefix;

    if (leafLen <= maxLeaf) {
      tailLen = leafLen;
    } else {
      tailLen = (maxVisibleChars * 0.65).round().clamp(1, maxVisibleChars - 1);
    }
  }

  final headLen = maxVisibleChars - tailLen;
  final headEnd = headLen.clamp(1, topicName.length - 1);
  final tailStart = (topicName.length - tailLen).clamp(
    headEnd + 1,
    topicName.length,
  );

  return MiddleEllipsisIndices(headEnd: headEnd, tailStart: tailStart);
}

List<TextSpan> buildTopicNameSpans({
  required String topicName,
  int? headEnd,
  int? tailStart,
  required TextStyle prefixStyle,
  required TextStyle leafStyle,
  required TextStyle highlightStyle,
  required TextStyle ellipsisStyle,
  String? highlightQuery,
  RegExp? highlightPattern,
}) {
  if (topicName.isEmpty) return const [];

  final hasEllipsis =
      headEnd != null && tailStart != null && headEnd < tailStart;
  final lastDotIndex = topicName.lastIndexOf('.');

  final matches = <(int start, int end)>[];
  if (highlightPattern != null) {
    for (final m in highlightPattern.allMatches(topicName)) {
      if (m.end > m.start) {
        matches.add((m.start, m.end));
      }
    }
  } else {
    final query = highlightQuery?.trim().toLowerCase();
    if (query != null && query.isNotEmpty) {
      final lowerName = topicName.toLowerCase();
      int searchStart = 0;
      while (searchStart < lowerName.length) {
        final idx = lowerName.indexOf(query, searchStart);
        if (idx == -1) break;
        matches.add((idx, idx + query.length));
        searchStart = idx + query.length.clamp(1, lowerName.length);
      }
    }
  }

  bool isIndexHighlighted(int index) {
    for (final (start, end) in matches) {
      if (index >= start && index < end) return true;
    }
    return false;
  }

  List<TextSpan> buildSpanRange(int rangeStart, int rangeEnd) {
    if (rangeStart >= rangeEnd) return [];
    final spans = <TextSpan>[];
    int currentChunkStart = rangeStart;
    TextStyle? currentStyle;

    for (int i = rangeStart; i < rangeEnd; i++) {
      final isPrefix = lastDotIndex != -1 && i <= lastDotIndex;
      final baseStyle = isPrefix ? prefixStyle : leafStyle;
      final isHighlighted = isIndexHighlighted(i);
      final effectiveStyle = isHighlighted
          ? baseStyle.merge(highlightStyle)
          : baseStyle;

      if (currentStyle == null) {
        currentStyle = effectiveStyle;
        currentChunkStart = i;
      } else if (currentStyle != effectiveStyle) {
        spans.add(
          TextSpan(
            text: topicName.substring(currentChunkStart, i),
            style: currentStyle,
          ),
        );
        currentStyle = effectiveStyle;
        currentChunkStart = i;
      }
    }

    if (currentStyle != null && currentChunkStart < rangeEnd) {
      spans.add(
        TextSpan(
          text: topicName.substring(currentChunkStart, rangeEnd),
          style: currentStyle,
        ),
      );
    }

    return spans;
  }

  if (!hasEllipsis) {
    return buildSpanRange(0, topicName.length);
  }

  final result = <TextSpan>[];
  result.addAll(buildSpanRange(0, headEnd));
  result.add(TextSpan(text: '…', style: ellipsisStyle));
  result.addAll(buildSpanRange(tailStart, topicName.length));
  return result;
}

List<TextSpan> fitTopicNameToWidth({
  required String topicName,
  required double maxWidth,
  required TextStyle prefixStyle,
  required TextStyle leafStyle,
  required TextStyle highlightStyle,
  required TextStyle ellipsisStyle,
  String? highlightQuery,
  RegExp? highlightPattern,
}) {
  if (topicName.isEmpty) return const [];
  if (maxWidth <= 0 || !maxWidth.isFinite) {
    return buildTopicNameSpans(
      topicName: topicName,
      prefixStyle: prefixStyle,
      leafStyle: leafStyle,
      highlightStyle: highlightStyle,
      ellipsisStyle: ellipsisStyle,
      highlightQuery: highlightQuery,
      highlightPattern: highlightPattern,
    );
  }

  final fullSpans = buildTopicNameSpans(
    topicName: topicName,
    prefixStyle: prefixStyle,
    leafStyle: leafStyle,
    highlightStyle: highlightStyle,
    ellipsisStyle: ellipsisStyle,
    highlightQuery: highlightQuery,
    highlightPattern: highlightPattern,
  );

  final painter = TextPainter(
    text: TextSpan(children: fullSpans),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );
  painter.layout();

  if (painter.width <= maxWidth) {
    return fullSpans;
  }

  int low = 2;
  int high = topicName.length - 1;
  int bestChars = 2;

  while (low <= high) {
    final mid = (low + high) ~/ 2;
    final indices = computeMiddleEllipsisIndices(topicName, mid);
    if (indices == null) {
      high = mid - 1;
      continue;
    }

    final candidateSpans = buildTopicNameSpans(
      topicName: topicName,
      headEnd: indices.headEnd,
      tailStart: indices.tailStart,
      prefixStyle: prefixStyle,
      leafStyle: leafStyle,
      highlightStyle: highlightStyle,
      ellipsisStyle: ellipsisStyle,
      highlightQuery: highlightQuery,
      highlightPattern: highlightPattern,
    );

    painter.text = TextSpan(children: candidateSpans);
    painter.layout();

    if (painter.width <= maxWidth) {
      bestChars = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }

  final finalIndices = computeMiddleEllipsisIndices(topicName, bestChars);
  return buildTopicNameSpans(
    topicName: topicName,
    headEnd: finalIndices?.headEnd,
    tailStart: finalIndices?.tailStart,
    prefixStyle: prefixStyle,
    leafStyle: leafStyle,
    highlightStyle: highlightStyle,
    ellipsisStyle: ellipsisStyle,
    highlightQuery: highlightQuery,
    highlightPattern: highlightPattern,
  );
}

String splitPolicy(String policy) {
  if (policy.length > 15) return "Policy: ...";
  return policy;
}

String formatRetentionDuration(String raw, AppLocalizations l10n) {
  final val = int.tryParse(raw.trim());
  if (val == null) return raw;
  if (val == -1) return l10n.retentionUnlimited;
  if (val < 0) return raw;
  if (val == 0) return l10n.durationMinutes(0);
  if (val < 60000) return l10n.durationSeconds(val ~/ 1000);

  final totalMinutes = val ~/ 60000;
  final days = totalMinutes ~/ (24 * 60);
  final hours = (totalMinutes % (24 * 60)) ~/ 60;
  final minutes = totalMinutes % 60;

  final parts = <String>[
    if (days > 0) l10n.durationDays(days),
    if (hours > 0) l10n.durationHours(hours),
    if (minutes > 0) l10n.durationMinutes(minutes),
  ];
  return parts.take(2).join(' ');
}

String formatRetentionBytes(String raw, AppLocalizations l10n) {
  final val = int.tryParse(raw.trim());
  if (val == null) return raw;
  if (val == -1) return l10n.retentionUnlimited;
  if (val < 0) return raw;
  return l10n.retentionBytesPerPartition(
    TopicAnalysisSummaryCards.formatBytes(val),
  );
}

Future<void> confirmCloseTab(
  BuildContext context, {
  required bool isOperationRunning,
  required VoidCallback onClose,
}) async {
  if (!isOperationRunning) {
    onClose();
    return;
  }

  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.operationInProgress ?? 'Operation in Progress'),
      content: Text(
        l10n?.operationInProgressMessage ??
            'A search or analysis is still running on this tab. '
                'Close the tab and cancel the operation?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n?.close ?? 'Close'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    onClose();
  }
}
