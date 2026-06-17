import 'package:flutter/material.dart';
import 'package:json_diff/json_diff.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/json_converter.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

class JsonDiffWidget extends StatefulWidget {
  final DiffNode diffNode;

  const JsonDiffWidget({super.key, required this.diffNode});

  @override
  State<JsonDiffWidget> createState() => _JsonDiffWidgetState();
}

class _JsonDiffWidgetState extends State<JsonDiffWidget> {
  late List<DiffViewNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = JsonConverter.fromDiff(widget.diffNode);
  }

  @override
  void didUpdateWidget(covariant JsonDiffWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.diffNode != oldWidget.diffNode) {
      _nodes = JsonConverter.fromDiff(widget.diffNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_nodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          AppLocalizations.of(context)!.noDifferencesFound,
          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: _nodes.map((n) => _buildNode(n)).toList());
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

  Widget _buildStructuralNode(DiffViewNode node) {
    const double indentSize = 16.0;
    Color? keyColor;
    Color? iconColor;
    IconData icon;
    TextStyle? textStyle;

    switch (node.type) {
      case NodeType.add:
        keyColor = Colors.green;
        iconColor = Colors.green;
        icon = Icons.add;
        break;
      case NodeType.remove:
        keyColor = Colors.red;
        iconColor = Colors.red;
        icon = Icons.remove;
        textStyle = const TextStyle(decoration: TextDecoration.lineThrough);
        break;
      default:
        keyColor = null;
        iconColor = Colors.grey;
        icon = node.isExpanded ? Icons.folder_open : Icons.folder;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  node.isExpanded ? (icon == Icons.folder ? Icons.folder_open : icon) : icon,
                  size: 14,
                  color: iconColor,
                ),
                const SizedBox(width: 4),
                Text(
                  node.key,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: keyColor,
                  ).merge(textStyle),
                ),
              ],
            ),
          ),
        ),
        if (node.isExpanded) ...node.children.map((child) => _buildNode(child)),
      ],
    );
  }

  Widget _buildAddedNode(DiffViewNode node) {
    const double indentSize = 16.0;
    return Padding(
      padding: EdgeInsets.only(left: node.depth * indentSize),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.green, fontFamily: 'monospace'),
        child: Row(
          children: [
            const Icon(Icons.add, size: 12, color: Colors.green),
            const SizedBox(width: 4),
            Text("${node.key}: "),
            Expanded(child: Text("${node.newValue}")),
          ],
        ),
      ),
    );
  }

  Widget _buildRemovedNode(DiffViewNode node) {
    const double indentSize = 16.0;
    return Padding(
      padding: EdgeInsets.only(left: node.depth * indentSize),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.red, decoration: TextDecoration.lineThrough, fontFamily: 'monospace'),
        child: Row(
          children: [
            const Icon(Icons.remove, size: 12, color: Colors.red),
            const SizedBox(width: 4),
            Text("${node.key}: "),
            Expanded(child: Text("${node.oldValue}")),
          ],
        ),
      ),
    );
  }

  Widget _buildChangedNode(DiffViewNode node) {
    const double indentSize = 16.0;
    return Padding(
      padding: EdgeInsets.only(left: node.depth * indentSize),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit, size: 12, color: Colors.orange),
          const SizedBox(width: 4),
          Text(
            "${node.key}: ",
            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontFamily: 'monospace', color: Colors.black87),
                children: [
                  TextSpan(
                    text: "${node.oldValue}",
                    style: const TextStyle(color: Colors.red, decoration: TextDecoration.lineThrough),
                  ),
                  const TextSpan(
                    text: "  ➔  ",
                    style: TextStyle(color: Colors.grey),
                  ),
                  TextSpan(
                    text: "${node.newValue}",
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
