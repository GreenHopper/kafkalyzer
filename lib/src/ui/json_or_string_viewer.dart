import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/ui/hex_viewer.dart';
import 'package:kafkalyzer/src/ui/smart_tree/smart_virtual_json_tree.dart';
import 'package:kafkalyzer/src/utils/app_fonts.dart';
import 'package:kafkalyzer/src/utils/payload_processing_isolate.dart';

class JsonOrStringViewer extends StatefulWidget {
  final String? title;
  final Widget? titleWidget;
  final String rawContent;
  final dynamic preParsedJson; // Optional optimization if already parsed
  final String? searchQuery;
  final bool expand;
  final String? persistenceKey;
  final ValueChanged<int>? onMatchCountChanged;
  final int? focusedMatchIndex;
  final int? initialViewMode;
  final double? treeViewHeight;
  final ValueChanged<String>? onPinToColumn;

  const JsonOrStringViewer({
    super.key,
    this.title,
    this.titleWidget,
    required this.rawContent,
    this.preParsedJson,
    this.searchQuery,
    this.expand = false,
    this.persistenceKey,
    this.onMatchCountChanged,
    this.focusedMatchIndex,
    this.initialViewMode,
    this.treeViewHeight,
    this.onPinToColumn,
  });

  @override
  State<JsonOrStringViewer> createState() => JsonOrStringViewerState();
}

class JsonOrStringViewerState extends State<JsonOrStringViewer> {
  int _viewMode = 0; // 0: Raw, 1: Tree, 3: Hex
  dynamic _parsedJson;
  bool _isValidJson = false;
  bool _isParsing = true;

  final GlobalKey<SmartVirtualJsonTreeState> _treeKey =
      GlobalKey<SmartVirtualJsonTreeState>();
  int _treeMatchCount = 0;
  int _rawMatchCount = 0;
  bool _isBinaryHex = false;
  List<int> _binaryBytes = [];

  @override
  void initState() {
    super.initState();
    _parseContentAsync();
  }

  void jumpToMatch(int index) {
    if (_viewMode == 1) {
      _treeKey.currentState?.jumpToMatch(index);
    }
  }

  void _updateMatchCount() {
    int count = 0;
    if (_viewMode == 1) {
      count = _treeMatchCount;
    } else if (_viewMode == 0) {
      count = _rawMatchCount;
    }
    widget.onMatchCountChanged?.call(count);
  }

  Future<void> _restorePersistence() async {
    if (widget.persistenceKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    if (_isValidJson) {
      final savedMode = prefs.getInt('json_view_mode_${widget.persistenceKey}');
      if (savedMode != null) {
        setState(() {
          // Mode 2 (legacy Cards) is mapped to 1 (Tree)
          _viewMode = (savedMode == 2) ? 1 : (savedMode <= 1 ? savedMode : 1);
          _updateMatchCount();
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant JsonOrStringViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawContent != widget.rawContent ||
        oldWidget.preParsedJson != widget.preParsedJson) {
      _parseContentAsync();
    } else if (oldWidget.searchQuery != widget.searchQuery) {
      _updateMatchCount();
    }
  }

  Future<void> _parseContentAsync() async {
    setState(() {
      _isParsing = true;
    });

    if (widget.preParsedJson != null) {
      _parsedJson = widget.preParsedJson;
      _isValidJson = true;
      _viewMode = widget.initialViewMode ?? 1; // Default to Tree
      _finalizeParsing();
      return;
    }

    if (widget.rawContent.isEmpty) {
      _isValidJson = false;
      _viewMode = 0;
      _finalizeParsing();
      return;
    }

    if (widget.rawContent.startsWith('<Binary Data>:') ||
        widget.rawContent.startsWith('<Binary Key>:')) {
      _isValidJson = false;
      _viewMode = 3;
      _isBinaryHex = true;
      final parts = widget.rawContent.split(':');
      if (parts.length >= 2) {
        final hexStr = parts.sublist(1).join(':').trim();
        _binaryBytes = await parseHexToBytesInIsolate(hexStr);
      }
      _finalizeParsing();
      return;
    }

    _isBinaryHex = false;
    _binaryBytes = [];

    try {
      final decoded = await parseJsonInIsolate(widget.rawContent);
      if (decoded is Map || decoded is List) {
        _parsedJson = decoded;
        _isValidJson = true;
        _viewMode = widget.initialViewMode ?? 1; // Default to Tree
      } else {
        _isValidJson = false;
        _viewMode = 0;
      }
    } catch (_) {
      _isValidJson = false;
      _viewMode = 0;
    }

    _finalizeParsing();
  }

  Future<void> _finalizeParsing() async {
    if (!mounted) return;
    await _restorePersistence();
    setState(() {
      _isParsing = false;
    });
    _updateMatchCount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget contentWidget;

    // View Mode Logic
    if (_isBinaryHex) {
      contentWidget = HexViewer(bytes: _binaryBytes);
    } else if (_isValidJson && _viewMode == 1) {
      contentWidget = SizedBox(
        height: widget.treeViewHeight ?? 300,
        child: SmartVirtualJsonTree(
          key: _treeKey,
          json: _parsedJson,
          searchQuery: widget.searchQuery,
          focusedMatchIndex: widget.focusedMatchIndex,
          onMatchCountChanged: (count) {
            _treeMatchCount = count;
            _updateMatchCount();
          },
          onPinToColumn: widget.onPinToColumn,
        ),
      );
    } else {
      // _viewMode == 0 or not valid JSON
      String textToHighlight = widget.rawContent;
      bool isTruncated = false;
      const maxLength = 500000;
      if (textToHighlight.length > maxLength) {
        textToHighlight = textToHighlight.substring(0, maxLength);
        isTruncated = true;
      }

      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isTruncated)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              color: colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Display truncated to 500k characters for performance. Use 'Copy' to extract the complete data.",
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildHighlightedRawText(
            textToHighlight,
            AppFonts.robotoMono(fontSize: 13, color: colorScheme.onSurface),
            context,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child:
                  widget.titleWidget ??
                  (widget.title != null
                      ? Text(
                          widget.title!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        )
                      : const SizedBox.shrink()),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: "Copy content",
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.rawContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Content copied to clipboard"),
                      ),
                    );
                  },
                ),
                if (_isValidJson) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 32,
                    child: ToggleButtons(
                      borderRadius: BorderRadius.circular(8),
                      isSelected: [_viewMode == 0, _viewMode == 1],
                      onPressed: (index) async {
                        setState(() {
                          _viewMode = index;
                          _updateMatchCount();
                        });
                        if (widget.persistenceKey != null) {
                          final prefs = await SharedPreferences.getInstance();
                          prefs.setInt(
                            'json_view_mode_${widget.persistenceKey}',
                            index,
                          );
                        }
                      },
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Raw', style: TextStyle(fontSize: 12)),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Tree', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Flexible(
          fit: widget.expand ? FlexFit.tight : FlexFit.loose,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: _isParsing
                ? const Center(child: CircularProgressIndicator())
                : ((_viewMode == 1 || _isBinaryHex)
                      ? contentWidget
                      : SingleChildScrollView(child: contentWidget)),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightedRawText(
    String text,
    TextStyle? style,
    BuildContext context,
  ) {
    if (widget.searchQuery == null || widget.searchQuery!.isEmpty) {
      return SelectableText(text, style: style);
    }

    final query = widget.searchQuery!.toLowerCase();
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
      final isFocused = matchCount == widget.focusedMatchIndex;

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

      start = index + query.length;
    }

    if (_viewMode == 0) {
      if (_rawMatchCount != matchCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _rawMatchCount != matchCount) {
            _rawMatchCount = matchCount;
            widget.onMatchCountChanged?.call(_rawMatchCount);
          }
        });
      }
    }

    return SelectableText.rich(TextSpan(children: matches));
  }
}
