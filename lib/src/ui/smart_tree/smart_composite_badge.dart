import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/ui/smart_tree/entity_formatter_registry.dart';

/// An interactive badge displaying a compressed summary of a composite semantic entity.
///
/// On hover, displays an [OverlayPortal] preview. On click, pins the popover open
/// to allow selecting text, inspecting details, and copying values.
class SmartCompositeBadge extends StatefulWidget {
  final String keyName;
  final dynamic data;
  final FormattedBadgeData badgeInfo;
  final bool initiallyPinned;

  const SmartCompositeBadge({
    super.key,
    required this.keyName,
    required this.data,
    required this.badgeInfo,
    this.initiallyPinned = false,
  });

  @override
  State<SmartCompositeBadge> createState() => _SmartCompositeBadgeState();
}

class _SmartCompositeBadgeState extends State<SmartCompositeBadge> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _link = LayerLink();
  late bool _isPinnedByClick;

  @override
  void initState() {
    super.initState();
    _isPinnedByClick = widget.initiallyPinned;
    if (_isPinnedByClick) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_overlayController.isShowing) {
          _overlayController.show();
        }
      });
    }
  }

  void _show() {
    if (!_overlayController.isShowing) {
      _overlayController.show();
    }
  }

  void _hide() {
    if (!_isPinnedByClick && _overlayController.isShowing) {
      _overlayController.hide();
    }
  }

  void _copyFullObject(BuildContext context) {
    String text;
    try {
      text = const JsonEncoder.withIndent('  ').convert(widget.data);
    } catch (_) {
      text = widget.data.toString();
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Object copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = widget.badgeInfo.color ?? theme.colorScheme.primary;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) => _buildPopover(context, badgeColor),
        child: MouseRegion(
          onEnter: (_) => _show(),
          onExit: (_) => _hide(),
          child: InkWell(
            onTap: () {
              setState(() {
                _isPinnedByClick = !_isPinnedByClick;
                if (_isPinnedByClick) {
                  _show();
                } else {
                  _hide();
                }
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                border: Border.all(
                  color: _isPinnedByClick
                      ? badgeColor
                      : badgeColor.withValues(alpha: 0.4),
                  width: _isPinnedByClick ? 1.5 : 1.0,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.badgeInfo.icon, size: 14, color: badgeColor),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (widget.keyName.isNotEmpty)
                            TextSpan(
                              text: '${widget.keyName}: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: badgeColor.withValues(alpha: 0.9),
                              ),
                            ),
                          TextSpan(
                            text: widget.badgeInfo.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isPinnedByClick ? Icons.lock : Icons.unfold_more,
                    size: 11,
                    color: _isPinnedByClick ? badgeColor : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopover(BuildContext context, Color badgeColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Positioned(
      width: 340,
      child: CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        child: MouseRegion(
          onEnter: (_) => _show(),
          onExit: (_) => _hide(),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(widget.badgeInfo.icon, size: 16, color: badgeColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.keyName.isNotEmpty
                              ? widget.keyName
                              : 'Entity Details',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 14),
                        tooltip: 'Copy whole object',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _copyFullObject(context),
                      ),
                      if (_isPinnedByClick)
                        IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          tooltip: 'Close',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              _isPinnedByClick = false;
                              _hide();
                            });
                          },
                        ),
                    ],
                  ),
                  const Divider(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildDetailRows(colorScheme),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetailRows(ColorScheme colorScheme) {
    if (widget.data is Map) {
      final map = widget.data as Map;
      return map.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 95,
                child: Text(
                  entry.key.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  entry.value?.toString() ?? 'null',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList();
    } else if (widget.data is List) {
      final list = widget.data as List;
      return list.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  '[${entry.key}]',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  entry.value?.toString() ?? 'null',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList();
    }

    return [
      SelectableText(
        widget.data?.toString() ?? 'null',
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          color: colorScheme.onSurface,
        ),
      ),
    ];
  }
}
