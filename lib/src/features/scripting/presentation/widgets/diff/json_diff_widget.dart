import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/diff_tree_builder.dart';
import 'package:kafkalyzer/src/rust/api/json_diff.dart';
import 'package:kafkalyzer/src/ui/text_preview_utils.dart';
import 'package:kafkalyzer/src/utils/app_fonts.dart';
import 'package:material_ui/material_ui.dart';

class JsonDiffWidget extends StatefulWidget {
  final List<JsonDiffEntry> entries;
  final void Function(String path)? onIgnorePath;
  final int hiddenCount;
  final VoidCallback? onHiddenTap;

  const JsonDiffWidget({
    super.key,
    required this.entries,
    this.onIgnorePath,
    this.hiddenCount = 0,
    this.onHiddenTap,
  });

  @override
  State<JsonDiffWidget> createState() => _JsonDiffWidgetState();
}

class _JsonDiffWidgetState extends State<JsonDiffWidget> {
  late List<DiffViewNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = DiffTreeBuilder.fromEntries(widget.entries);
  }

  @override
  void didUpdateWidget(covariant JsonDiffWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.entries, oldWidget.entries)) {
      _nodes = DiffTreeBuilder.fromEntries(widget.entries);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_nodes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              AppLocalizations.of(context)!.noDifferencesFound,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (widget.hiddenCount > 0) _buildHiddenFooter(context),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._nodes.map(_buildNode),
        if (widget.hiddenCount > 0) _buildHiddenFooter(context),
      ],
    );
  }

  Widget _buildHiddenFooter(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = 'Hidden (${widget.hiddenCount})';
    final textWidget = Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 4.0),
      child: Text(
        l10n != null ? _localizedHiddenCount(l10n, widget.hiddenCount) : label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
    if (widget.onHiddenTap == null) return textWidget;
    return InkWell(onTap: widget.onHiddenTap, child: textWidget);
  }

  String _localizedHiddenCount(AppLocalizations l10n, int count) {
    return l10n.diffHiddenCount(count);
  }

  Widget _wrapWithContextMenu(DiffViewNode node, Widget child) {
    final path = node.path;
    final onIgnore = widget.onIgnorePath;
    if (onIgnore == null || path == null || path.isEmpty) {
      return child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) async {
        final overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox?;
        final position = details.globalPosition;
        final rect = overlay != null
            ? RelativeRect.fromRect(
                Rect.fromLTWH(position.dx, position.dy, 0, 0),
                Offset.zero & overlay.size,
              )
            : RelativeRect.fromLTRB(
                position.dx,
                position.dy,
                position.dx,
                position.dy,
              );
        final selected = await showMenu<String>(
          context: context,
          position: rect,
          items: [
            PopupMenuItem<String>(
              value: path,
              child: Text(
                AppLocalizations.of(context)?.ignoreThisField ??
                    'Ignore this field',
              ),
            ),
          ],
        );
        if (selected != null) {
          onIgnore(selected);
        }
      },
      child: child,
    );
  }

  Widget _buildNode(DiffViewNode node) {
    if (node.children.isNotEmpty) {
      return _buildStructuralNode(node);
    }

    // Leaf nodes
    switch (node.type) {
      case NodeType.add:
        return _buildAddedNode(node);
      case NodeType.remove:
        return _buildRemovedNode(node);
      case NodeType.change:
        return _buildChangedNode(node);
      default:
        return const SizedBox.shrink();
    }
  }

  Color _addedColor(ColorScheme colorScheme, Color surfaceBg) {
    return TextPreviewUtils.ensureContrast(
      colorScheme.primary,
      surfaceBg,
      colorScheme.onSurface,
    );
  }

  Color _removedColor(ColorScheme colorScheme, Color surfaceBg) {
    return TextPreviewUtils.ensureContrast(
      colorScheme.error,
      surfaceBg,
      colorScheme.onSurface,
    );
  }

  Color _changedIconColor(ColorScheme colorScheme, Color surfaceBg) {
    return TextPreviewUtils.ensureContrast(
      colorScheme.tertiary,
      surfaceBg,
      colorScheme.onSurface,
    );
  }

  Widget _buildStructuralNode(DiffViewNode node) {
    const double indentSize = 16.0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final surfaceBg = theme.cardTheme.color ?? colorScheme.surfaceContainerLow;
    final baseFontSize = theme.textTheme.bodyMedium?.fontSize ?? 13.0;
    Color keyColor;
    Color iconColor;
    IconData icon;
    TextDecoration? decoration;

    switch (node.type) {
      case NodeType.add:
        keyColor = _addedColor(colorScheme, surfaceBg);
        iconColor = keyColor;
        icon = Icons.add;
        break;
      case NodeType.remove:
        keyColor = _removedColor(colorScheme, surfaceBg);
        iconColor = keyColor;
        icon = Icons.remove;
        decoration = TextDecoration.lineThrough;
        break;
      default:
        keyColor = colorScheme.onSurface;
        iconColor = colorScheme.onSurfaceVariant;
        icon = node.isExpanded ? Icons.folder_open : Icons.folder;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wrapWithContextMenu(
          node,
          Padding(
            padding: EdgeInsets.only(left: node.depth * indentSize),
            child: InkWell(
              onTap: () {
                setState(() {
                  node.isExpanded = !node.isExpanded;
                });
              },
              child: Row(
                children: [
                  Icon(
                    node.isExpanded
                        ? (icon == Icons.folder ? Icons.folder_open : icon)
                        : icon,
                    size: 14,
                    color: iconColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    node.key,
                    style: AppFonts.robotoMono(
                      fontSize: baseFontSize,
                      height: 1.4,
                      fontWeight: FontWeight.bold,
                      color: keyColor,
                    ).copyWith(decoration: decoration),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (node.isExpanded) ...node.children.map(_buildNode),
      ],
    );
  }

  Widget _buildAddedNode(DiffViewNode node) {
    const double indentSize = 16.0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final surfaceBg = theme.cardTheme.color ?? colorScheme.surfaceContainerLow;
    final baseFontSize = theme.textTheme.bodyMedium?.fontSize ?? 13.0;
    final addedColor = _addedColor(colorScheme, surfaceBg);

    return _wrapWithContextMenu(
      node,
      Padding(
        padding: EdgeInsets.only(left: node.depth * indentSize),
        child: DefaultTextStyle(
          style: AppFonts.robotoMono(
            fontSize: baseFontSize,
            height: 1.4,
            color: addedColor,
          ),
          child: Row(
            children: [
              Icon(Icons.add, size: 12, color: addedColor),
              const SizedBox(width: 4),
              Text(
                "${node.key}: ",
                style: AppFonts.robotoMono(
                  fontSize: baseFontSize,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: addedColor,
                ),
              ),
              Expanded(child: Text("${node.newValue}")),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemovedNode(DiffViewNode node) {
    const double indentSize = 16.0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final surfaceBg = theme.cardTheme.color ?? colorScheme.surfaceContainerLow;
    final baseFontSize = theme.textTheme.bodyMedium?.fontSize ?? 13.0;
    final removedColor = _removedColor(colorScheme, surfaceBg);

    return _wrapWithContextMenu(
      node,
      Padding(
        padding: EdgeInsets.only(left: node.depth * indentSize),
        child: DefaultTextStyle(
          style: AppFonts.robotoMono(
            fontSize: baseFontSize,
            height: 1.4,
            color: removedColor,
          ).copyWith(decoration: TextDecoration.lineThrough),
          child: Row(
            children: [
              Icon(Icons.remove, size: 12, color: removedColor),
              const SizedBox(width: 4),
              Text("${node.key}: "),
              Expanded(child: Text("${node.oldValue}")),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangedNode(DiffViewNode node) {
    const double indentSize = 16.0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final surfaceBg = theme.cardTheme.color ?? colorScheme.surfaceContainerLow;
    final baseFontSize = theme.textTheme.bodyMedium?.fontSize ?? 13.0;
    final removedColor = _removedColor(colorScheme, surfaceBg);
    final editIconColor = _changedIconColor(colorScheme, surfaceBg);
    final arrowColor = TextPreviewUtils.ensureContrast(
      colorScheme.onSurfaceVariant,
      surfaceBg,
      colorScheme.onSurface,
    );
    final newValueColor = TextPreviewUtils.ensureContrast(
      colorScheme.onSurface,
      surfaceBg,
      colorScheme.onSurface,
    );
    final baseMono = AppFonts.robotoMono(
      fontSize: baseFontSize,
      height: 1.4,
      color: newValueColor,
    );

    return _wrapWithContextMenu(
      node,
      Padding(
        padding: EdgeInsets.only(left: node.depth * indentSize),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: Icon(Icons.edit, size: 12, color: editIconColor),
            ),
            const SizedBox(width: 4),
            Text(
              "${node.key}: ",
              style: baseMono.copyWith(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: RichText(
                textScaler: MediaQuery.textScalerOf(context),
                text: TextSpan(
                  style: baseMono,
                  children: [
                    TextSpan(
                      text: "${node.oldValue}",
                      style: baseMono.copyWith(
                        color: removedColor,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    TextSpan(
                      text: "  ➔  ",
                      style: baseMono.copyWith(color: arrowColor),
                    ),
                    TextSpan(
                      text: "${node.newValue}",
                      style: baseMono.copyWith(
                        color: newValueColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
