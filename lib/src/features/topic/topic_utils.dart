import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

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
}) {
  if (topicName.isEmpty) return const [];

  final hasEllipsis =
      headEnd != null && tailStart != null && headEnd < tailStart;
  final lastDotIndex = topicName.lastIndexOf('.');

  final matches = <(int start, int end)>[];
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
    );
  }

  final fullSpans = buildTopicNameSpans(
    topicName: topicName,
    prefixStyle: prefixStyle,
    leafStyle: leafStyle,
    highlightStyle: highlightStyle,
    ellipsisStyle: ellipsisStyle,
    highlightQuery: highlightQuery,
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
  );
}

String splitPolicy(String policy) {
  if (policy.length > 15) return "Policy: ...";
  return policy;
}

String formatRetention(String ms) {
  try {
    final val = int.parse(ms);
    if (val == -1) return "Infinite";
    final hours = val / 3600000;
    if (hours >= 24) {
      return "${(hours / 24).toStringAsFixed(1)} days";
    }
    return "${hours.toStringAsFixed(1)} hrs";
  } catch (_) {
    return ms;
  }
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
