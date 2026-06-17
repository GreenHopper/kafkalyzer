import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:json_explorer/json_explorer.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kafkalyzer/src/ui/json_card_viewer.dart';
import 'package:kafkalyzer/src/ui/hex_viewer.dart';

class MatchRegistry {
  final List<GlobalKey> _keys = [];
  int get count => _keys.length;
  void register(GlobalKey key) => _keys.add(key);
  GlobalKey? getKey(int index) => (index >= 0 && index < _keys.length) ? _keys[index] : null;
  void clear() => _keys.clear();
}

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
  });

  @override
  State<JsonOrStringViewer> createState() => JsonOrStringViewerState();
}

class JsonOrStringViewerState extends State<JsonOrStringViewer> {
  int _viewMode = 0; // 0: Raw, 1: JSON, 2: Cards
  dynamic _parsedJson;
  bool _isValidJson = false;

  final JsonExplorerStore _store = JsonExplorerStore();
  final MatchRegistry _matchRegistry = MatchRegistry();
  final ItemScrollController _itemScrollController = ItemScrollController();
  int _rawMatchCount = 0;
  bool _isBinaryHex = false;
  List<int> _binaryBytes = [];

  List<int> _hexToBytes(String hex) {
    List<int> bytes = [];
    try {
      for (int i = 0; i < hex.length; i += 2) {
        if (i + 1 < hex.length) {
          bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
        }
      }
    } catch (_) {
      // Ignore parsing errors for partial hex
    }
    return bytes;
  }

  @override
  void initState() {
    super.initState();
    _parseContent();
    _restorePersistence();
    _updateMatchCount();
  }

  void jumpToMatch(int index) {
    if (_viewMode == 2) {
      // Cards
      final key = _matchRegistry.getKey(index);
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (_viewMode == 0) {
      // Raw match jumping not fully supported without line splitting,
      // but we could try scrolling if we had logic.
      // For now, no-op or improved later.
    } else if (_viewMode == 1) {
      // Tree view jumping:
      if (index >= 0 && index < _store.searchResults.length) {
        // 1. Sync store focus to this index so it renders highlighted
        _syncStoreFocus(index);

        // 2. Scroll to the node containing this match
        final result = _store.searchResults[index];
        final nodeIndex = _store.displayNodes.indexOf(result.node);

        if (nodeIndex >= 0) {
          _itemScrollController.scrollTo(
            index: nodeIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.5, // Center the item
          );
        }
      }
    }
  }

  void _syncStoreFocus(int targetIndex) {
    // Helper to move store focus to the target index.
    // Since we don't have direct setter, we cycle.
    // Optimization: if we are far, we could just reset search? No, that clears state.
    // We assume the user navigates sequentially mostly.

    if (_store.searchResults.isEmpty) return;

    // Safety break to prevent infinite loops if something is wrong
    int attempts = 0;
    while (_store.focusedSearchResultIndex != targetIndex && attempts < _store.searchResults.length * 2) {
      // Decide direction?
      // focusedSearchResultIndex is 0..N
      // We can just loop next.
      _store.focusNextSearchResult(loop: true);
      attempts++;
    }
  }

  void _updateMatchCount() {
    // Post frame callback to ensure widgets are built and registered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      int count = 0;
      if (_viewMode == 2) {
        // Cards
        count = _matchRegistry.count;
      } else if (_viewMode == 0) {
        // Raw
        count = _rawMatchCount;
      } else if (_viewMode == 1) {
        // Tree View
        // Count matches in displayNodes
        // We assume JsonExplorer filters/expands to show matches.
        // We need to count how many nodes actually CONTAIN the search term in key or value.
        // Note: JsonExplorer might highlight multiple times in one string?
        // For simplicity, we count each NODE that matches as 1 match (or 2 if both key and value match?)
        // Let's count occurrence based.

        final query = widget.searchQuery?.toLowerCase();
        if (query != null && query.isNotEmpty) {
          // Use store results directly
          count = _store.searchResults.length;
        }
      }
      widget.onMatchCountChanged?.call(count);
    });
  }

  Future<void> _restorePersistence() async {
    if (widget.persistenceKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // Only restore if current content is valid JSON, otherwise we are forced to Raw (0)
    // Wait, if it IS valid JSON, parseContent sets it to Cards (2).
    // So if persistence says 0 (Raw), 1 (Tree), or 2 (Cards), we respect it if valid.
    if (_isValidJson) {
      final savedMode = prefs.getInt('json_view_mode_${widget.persistenceKey}');
      if (savedMode != null && savedMode >= 0 && savedMode <= 2) {
        setState(() {
          _viewMode = savedMode;
          // Re-trigger search if needed if mode switched to Tree
          if (_viewMode == 1 && widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
            _store.search(widget.searchQuery!);
          }
          _updateMatchCount();
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant JsonOrStringViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawContent != widget.rawContent || oldWidget.preParsedJson != widget.preParsedJson) {
      _parseContent();
      _updateMatchCount();
    }
    if (oldWidget.searchQuery != widget.searchQuery) {
      if (_isValidJson && _viewMode == 1) {
        _store.search(widget.searchQuery ?? '');
        if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
          _store.expandSearchResults();
        }
      }
      _updateMatchCount();
    }
  }

  void _parseContent() {
    if (widget.preParsedJson != null) {
      _parsedJson = widget.preParsedJson;
      _isValidJson = true;
      _viewMode = widget.initialViewMode ?? 2; // Default to Cards
      _store.buildNodes(_parsedJson);
      if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
        _store.search(widget.searchQuery!);
        _store.expandSearchResults();
      }
      return;
    }

    if (widget.rawContent.isEmpty) {
      _isValidJson = false;
      _viewMode = 0;
      return;
    }

    if (widget.rawContent.startsWith('<Binary Data>:') || widget.rawContent.startsWith('<Binary Key>:')) {
      _isValidJson = false;
      _viewMode = 3;
      _isBinaryHex = true;
      final parts = widget.rawContent.split(':');
      if (parts.length >= 2) {
        final hexStr = parts.sublist(1).join(':').trim();
        _binaryBytes = _hexToBytes(hexStr);
      }
      return;
    }

    _isBinaryHex = false;
    _binaryBytes = [];

    try {
      final decoded = json.decode(widget.rawContent);
      if (decoded is Map || decoded is List) {
        _parsedJson = decoded;
        _isValidJson = true;
        _viewMode = widget.initialViewMode ?? 2; // Default to Cards
        _store.buildNodes(_parsedJson);
        if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
          _store.search(widget.searchQuery!);
          _store.expandSearchResults();
        }
      } else {
        _isValidJson = false;
        _viewMode = 0;
      }
    } catch (_) {
      _isValidJson = false;
      _viewMode = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget contentWidget;

    // View Mode Logic
    if (_isBinaryHex) {
      contentWidget = HexViewer(bytes: _binaryBytes);
    } else if (_isValidJson && _viewMode == 2) {
      _matchRegistry.clear();
      contentWidget = JsonCardViewer(
        json: _parsedJson,
        searchQuery: widget.searchQuery,
        focusedMatchIndex: widget.focusedMatchIndex,
        onMatchFound: _matchRegistry.register,
      );
    } else if (_isValidJson && _viewMode == 1) {
      contentWidget = SizedBox(
        height: widget.treeViewHeight ?? 300,
        child: ChangeNotifierProvider.value(
          value: _store,
          child: Consumer<JsonExplorerStore>(
            builder: (context, store, child) {
              return JsonExplorer(
                nodes: store.displayNodes,
                itemScrollController: _itemScrollController,
                theme: JsonExplorerTheme(
                  rootKeyTextStyle: GoogleFonts.robotoMono(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  propertyKeyTextStyle: GoogleFonts.robotoMono(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  valueTextStyle: GoogleFonts.robotoMono(color: colorScheme.onSurface, fontSize: 13),
                  indentationLineColor: colorScheme.outlineVariant,
                  highlightColor: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  keySearchHighlightTextStyle: GoogleFonts.robotoMono(
                    color: colorScheme.onTertiaryContainer,
                    backgroundColor: colorScheme.tertiaryContainer,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  valueSearchHighlightTextStyle: GoogleFonts.robotoMono(
                    color: colorScheme.onTertiaryContainer,
                    backgroundColor: colorScheme.tertiaryContainer,
                    fontSize: 13,
                  ),
                  focusedKeySearchHighlightTextStyle: GoogleFonts.robotoMono(
                    color: Colors.black,
                    backgroundColor: Colors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  focusedValueSearchHighlightTextStyle: GoogleFonts.robotoMono(
                    color: Colors.black,
                    backgroundColor: Colors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                valueStyleBuilder: (value, style) {
                  if (value is num) {
                    return PropertyOverrides(style: style.copyWith(color: colorScheme.secondary));
                  } else if (value is bool) {
                    return PropertyOverrides(style: style.copyWith(color: colorScheme.tertiary));
                  } else if (value is String) {
                    return PropertyOverrides(style: style.copyWith(color: colorScheme.primary));
                  }
                  return PropertyOverrides(style: style);
                },
              );
            },
          ),
        ),
      );
    } else {
      // _viewMode == 0 or not valid JSON
      contentWidget = _buildHighlightedRawText(
        widget.rawContent,
        GoogleFonts.robotoMono(fontSize: 13, color: colorScheme.onSurface),
        context,
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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text("Content copied to clipboard")));
                  },
                ),
                if (_isValidJson) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 32,
                    child: ToggleButtons(
                      borderRadius: BorderRadius.circular(8),
                      isSelected: [_viewMode == 0, _viewMode == 1, _viewMode == 2],
                      onPressed: (index) async {
                        setState(() {
                          _viewMode = index;
                          if (_viewMode == 1 && widget.searchQuery != null) {
                            _store.search(widget.searchQuery!);
                          }
                          _updateMatchCount();
                        });
                        if (widget.persistenceKey != null) {
                          final prefs = await SharedPreferences.getInstance();
                          prefs.setInt('json_view_mode_${widget.persistenceKey}', index);
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
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Cards', style: TextStyle(fontSize: 12)),
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
            // For Tree view (viewMode 1), JsonExplorer is already scrollable.
            // For others (Raw/Cards/HexViewer), we need to ensure they are scrollable.
            child: (_viewMode == 1 || _isBinaryHex) ? contentWidget : SingleChildScrollView(child: contentWidget),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightedRawText(String text, TextStyle? style, BuildContext context) {
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
            backgroundColor: isFocused ? Colors.orange : Theme.of(context).colorScheme.tertiaryContainer,
            color: isFocused ? Colors.black : Theme.of(context).colorScheme.onTertiaryContainer,
            fontWeight: isFocused ? FontWeight.bold : null,
          ),
        ),
      );
      matchCount++;

      start = index + query.length;
    }

    // Update raw match count if we are in raw mode
    if (_viewMode == 0) {
      // We can't update state during build easily, but since this is called during build...
      // We should probably calculate this BEFORE build or use other means.
      // However, _buildHighlightedText is called once.
      // Optimisation: check if count changed.
      if (_rawMatchCount != matchCount) {
        // Schedule update
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
