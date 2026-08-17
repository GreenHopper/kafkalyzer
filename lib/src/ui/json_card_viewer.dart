import 'package:material_ui/material_ui.dart';

class JsonCardViewer extends StatelessWidget {
  final dynamic json;
  final String? searchQuery;
  final ValueSetter<GlobalKey>? onMatchFound;
  final int? focusedMatchIndex;

  const JsonCardViewer({
    super.key,
    required this.json,
    this.searchQuery,
    this.onMatchFound,
    this.focusedMatchIndex,
  });

  @override
  Widget build(BuildContext context) {
    // We need a mutable counter to track matches across the recursive tree
    final matchCounter = ValueNotifier<int>(0);
    return _buildNode(context, json, null, matchCounter);
  }

  Widget _buildNode(
    BuildContext context,
    dynamic content,
    Color? parentColor,
    ValueNotifier<int> matchCounter,
  ) {
    if (content is Map<String, dynamic>) {
      if (content.isEmpty) return const Text("{}");

      // Split content into primitives (simple values) and complex (nested objects/lists)
      final primitives = <MapEntry<String, dynamic>>[];
      final complex = <MapEntry<String, dynamic>>[];

      for (var entry in content.entries) {
        if (entry.value is Map || entry.value is List) {
          complex.add(entry);
        } else {
          primitives.add(entry);
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Primitive Values at the Top (Wrapped)
          if (primitives.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: primitives.map((e) {
                  return _buildFieldCard(
                    context,
                    e.key,
                    e.value,
                    parentColor,
                    matchCounter,
                  );
                }).toList(),
              ),
            ),
          // ... (rest of the file remains similar but preserving context)

          // 2. Complex Objects Below (Masonry Grid Layout)
          if (complex.isNotEmpty)
            // 2. Complex Objects Below (Masonry Grid Layout)
            if (complex.isNotEmpty)
              Builder(
                builder: (context) {
                  // LayoutBuilder crashes inside IntrinsicHeight (used by Timeline).
                  // Fallback to MediaQuery for responsive decision.
                  // We use a Builder to ensure we have the right context if needed, though usually fine.
                  final width = MediaQuery.of(context).size.width;
                  int crossAxisCount = 1;
                  if (width > 1200) {
                    crossAxisCount = 3;
                  } else if (width > 800) {
                    crossAxisCount = 2;
                  }

                  // Distribute items into columns (Masonry style round-robin)
                  final columns = List.generate(
                    crossAxisCount,
                    (_) => <Widget>[],
                  );
                  for (var i = 0; i < complex.length; i++) {
                    final entry = complex[i];
                    final colIndex = i % crossAxisCount;
                    columns[colIndex].add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildFieldCard(
                          context,
                          entry.key,
                          entry.value,
                          parentColor,
                          matchCounter,
                        ),
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < crossAxisCount; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: columns[i],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
        ],
      );
    } else if (content is List) {
      if (content.isEmpty) return const Text("[]");
      // Lists are also complex, but for consistency we render them vertically for now
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: content.asMap().entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _buildFieldCard(
              context,
              "[${e.key}]",
              e.value,
              parentColor,
              matchCounter,
            ),
          );
        }).toList(),
      );
    } else {
      return Text(content.toString());
    }
  }

  Widget _buildFieldCard(
    BuildContext context,
    String key,
    dynamic value,
    Color? parentColor,
    ValueNotifier<int> matchCounter,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isComplex = value is Map || value is List;

    Color baseColor;
    if (parentColor != null) {
      // Inherit parent color for nested items to reduce color noise
      baseColor = parentColor;
    } else {
      // Root level items get a color from the palette
      final palette = [
        Colors.blue,
        Colors.teal,
        Colors.indigo,
        Colors.purple,
        Colors.deepOrange,
        Colors.pink,
        Colors.amber.shade900,
        Colors.cyan,
      ];
      final colorIndex = key.hashCode.abs() % palette.length;
      baseColor = palette[colorIndex];
    }

    if (isComplex) {
      // Complex Object Card (Section)
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: baseColor.withValues(
            alpha: 0.05,
          ), // Tinted background matching the header
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: baseColor.withValues(alpha: 0.2),
          ), // Subtle colored border
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Section Header
            Text(
              key.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: baseColor, // Consistent color for this field name
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            // Nested Content - Pass baseColor down!
            _buildNode(context, value, baseColor, matchCounter),
          ],
        ),
      );
    } else {
      // Primitive Value Card (KeyValue Pair)
      return Container(
        constraints: const BoxConstraints(
          minWidth: 100,
        ), // Min width for small values
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          // No shadow for cleaner look
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            _buildHighlightedText(
              key.toUpperCase(),
              theme.textTheme.labelSmall?.copyWith(
                color: baseColor.withValues(alpha: 0.8),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
              context,
              matchCounter,
            ),
            const SizedBox(height: 4),
            // Value
            _buildHighlightedText(
              value.toString(),
              theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
              context,
              matchCounter,
              isSelectable: true,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildHighlightedText(
    String text,
    TextStyle? style,
    BuildContext context,
    ValueNotifier<int> matchCounter, {
    bool isSelectable = false,
  }) {
    // If no search query, just return text
    if (searchQuery == null || searchQuery!.isEmpty) {
      if (isSelectable) {
        return SelectableText(text, style: style);
      }
      return Text(text, style: style);
    }

    final query = searchQuery!.toLowerCase();
    final lowerText = text.toLowerCase();
    final matches = <TextSpan>[];
    int start = 0;
    int matchCount = 0;

    while (true) {
      final index = lowerText.indexOf(query, start);
      if (index == -1) {
        if (start < text.length) {
          matches.add(TextSpan(text: text.substring(start), style: style));
        }
        break;
      }

      if (index > start) {
        matches.add(TextSpan(text: text.substring(start, index), style: style));
      }

      final match = text.substring(index, index + query.length);
      final currentMatchIndex = matchCounter.value;
      final isFocused = focusedMatchIndex == currentMatchIndex;

      matches.add(
        TextSpan(
          text: match,
          style: style?.copyWith(
            backgroundColor: isFocused
                ? Colors.orange
                : Theme.of(context).colorScheme.tertiaryContainer,
            color: isFocused
                ? Colors.black
                : Theme.of(context).colorScheme.onTertiaryContainer,
            fontWeight: isFocused ? FontWeight.bold : null,
          ),
        ),
      );
      matchCount++;
      matchCounter.value++;

      start = index + query.length;
    }

    final span = TextSpan(children: matches);
    Widget widget;

    if (isSelectable) {
      widget = SelectableText.rich(span);
    } else {
      widget = Text.rich(span);
    }

    // Register matches if any
    if (matchCount > 0 && onMatchFound != null) {
      final key = GlobalKey();
      // Register the SAME key for all matches in this text block
      for (var i = 0; i < matchCount; i++) {
        onMatchFound!(key);
      }
      return KeyedSubtree(key: key, child: widget);
    }

    return widget;
  }
}
