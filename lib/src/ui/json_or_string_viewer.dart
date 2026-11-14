import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/ui/hex_viewer.dart';
import 'package:kafkalyzer/src/ui/smart_tree/smart_virtual_json_tree.dart';
import 'package:kafkalyzer/src/ui/widgets/decode_l10n_helper.dart';
import 'package:kafkalyzer/src/utils/app_fonts.dart';
import 'package:kafkalyzer/src/utils/nested_value_decoder.dart';
import 'package:kafkalyzer/src/utils/payload_processing_isolate.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RawSearchState { idle, running, done, capped, failed }

class JsonOrStringViewer extends StatefulWidget {
  final String? title;
  final Widget? titleWidget;
  final String rawContent;
  final dynamic preParsedJson; // Optional optimization if already parsed
  final String? searchQuery;
  final bool expand;
  final String? persistenceKey;
  final ValueChanged<int>? onMatchCountChanged;
  final ValueChanged<RawSearchState>? onSearchStateChanged;
  final int? focusedMatchIndex;
  final int? initialViewMode;
  final double? treeViewHeight;
  final ValueChanged<String>? onPinToColumn;
  final ValueChanged<String>? onFilterByField;
  final Future<Int32List> Function(String text)? computeRowIndex;
  final Future<({Int32List offsets, bool capped})> Function(
    String text,
    String query,
  )?
  findMatches;
  final bool recognizeHexFallback;
  final String? emptyValueMarker;
  final bool fitTreeHeight;

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
    this.onSearchStateChanged,
    this.focusedMatchIndex,
    this.initialViewMode,
    this.treeViewHeight,
    this.onPinToColumn,
    this.onFilterByField,
    this.computeRowIndex,
    this.findMatches,
    this.recognizeHexFallback = false,
    this.emptyValueMarker,
    this.fitTreeHeight = false,
  });

  @override
  State<JsonOrStringViewer> createState() => JsonOrStringViewerState();
}

class JsonOrStringViewerState extends State<JsonOrStringViewer> {
  int _viewMode = 0; // 0: Raw, 1: Tree, 3: Hex
  dynamic _parsedJson;
  bool _isValidJson = false;
  bool _isParsing = true;
  bool _hideNullFields = false;

  final GlobalKey<SmartVirtualJsonTreeState> _treeKey =
      GlobalKey<SmartVirtualJsonTreeState>();
  final ItemScrollController _rawItemScrollController = ItemScrollController();
  int _treeMatchCount = 0;
  int _rawMatchCount = 0;
  bool _isBinaryHex = false;
  Uint8List _binaryBytes = Uint8List(0);
  Int32List _rawRowStarts = Int32List(0);
  String? _rowIndexError;
  Int32List _rawMatchOffsets = Int32List(0);
  int _rawSearchGeneration = 0;
  RawSearchState _rawSearchState = RawSearchState.idle;

  final List<_DecodeStep> _decodeChain = [];
  int _decodeGeneration = 0;
  bool _isDecoding = false;
  DecodeError? _decodeError;

  bool get _effectiveIsBinaryHex =>
      _decodeChain.isNotEmpty ? _decodeChain.last.bytes != null : _isBinaryHex;

  Uint8List get _effectiveBinaryBytes => _decodeChain.isNotEmpty
      ? (_decodeChain.last.bytes ?? Uint8List(0))
      : _binaryBytes;

  bool get _effectiveIsValidJson => _decodeChain.isNotEmpty
      ? _decodeChain.last.parsedJson != null
      : _isValidJson;

  dynamic get _effectiveParsedJson =>
      _decodeChain.isNotEmpty ? _decodeChain.last.parsedJson : _parsedJson;

  String get _effectiveRawText => _decodeChain.isNotEmpty
      ? (_decodeChain.last.rawText ?? '')
      : widget.rawContent;

  Int32List get _effectiveRawRowStarts =>
      _decodeChain.isNotEmpty ? _decodeChain.last.rawRowStarts : _rawRowStarts;

  int get _effectiveViewMode {
    if (_effectiveIsBinaryHex) return 3;
    if (_effectiveIsValidJson) return _viewMode == 3 ? 1 : _viewMode;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _parseContentAsync();
  }

  void jumpToMatch(int index) {
    final mode = _effectiveViewMode;
    final rowStarts = _effectiveRawRowStarts;
    if (mode == 1) {
      _treeKey.currentState?.jumpToMatch(index);
    } else if (mode == 0) {
      if (index < 0 ||
          index >= _rawMatchOffsets.length ||
          rowStarts.isEmpty ||
          !_rawItemScrollController.isAttached) {
        return;
      }
      final rowIndex = _findRowForOffset(rowStarts, _rawMatchOffsets[index]);
      _rawItemScrollController.scrollTo(
        index: rowIndex,
        duration: const Duration(milliseconds: 200),
        alignment: 0.5,
      );
    }
  }

  int _findRowForOffset(Int32List starts, int offset) {
    var lo = 0;
    var hi = starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  void _updateMatchCount() {
    int count = 0;
    final mode = _effectiveViewMode;
    if (mode == 1) {
      count = _treeMatchCount;
    } else if (mode == 0) {
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
      final savedHideNull = prefs.getBool(
        'json_hide_null_${widget.persistenceKey}',
      );
      if (savedHideNull != null) {
        setState(() {
          _hideNullFields = savedHideNull;
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
      Future.microtask(() {
        if (!mounted) return;
        if (_effectiveViewMode == 0) {
          _runRawSearch();
        } else {
          _updateMatchCount();
        }
      });
    }
  }

  Future<void> _parseContentAsync() async {
    _decodeGeneration++;
    setState(() {
      _isParsing = true;
      _decodeChain.clear();
      _isDecoding = false;
      _decodeError = null;
      _rowIndexError = null;
      _rawRowStarts = Int32List(0);
      _rawMatchOffsets = Int32List(0);
      _rawMatchCount = 0;
      _rawSearchState = RawSearchState.idle;
    });

    if (widget.preParsedJson != null) {
      _parsedJson = widget.preParsedJson;
      _isValidJson = true;
      _isBinaryHex = false;
      _binaryBytes = Uint8List(0);
      _viewMode = widget.initialViewMode ?? 1; // Default to Tree
      await _computeRawRowsIfNeeded();
      await _finalizeParsing();
      return;
    }

    if (widget.rawContent.isEmpty) {
      _isValidJson = false;
      _isBinaryHex = false;
      _binaryBytes = Uint8List(0);
      _viewMode = 0;
      await _finalizeParsing();
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
      } else {
        _binaryBytes = Uint8List(0);
      }
      await _finalizeParsing();
      return;
    }

    if (widget.recognizeHexFallback) {
      final fallbackHex = tryParseHexFallback(widget.rawContent);
      if (fallbackHex != null) {
        _isValidJson = false;
        _viewMode = 3;
        _isBinaryHex = true;
        _binaryBytes = fallbackHex;
        await _finalizeParsing();
        return;
      }
    }

    _isBinaryHex = false;
    _binaryBytes = Uint8List(0);

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

    await _computeRawRowsIfNeeded();
    await _finalizeParsing();
  }

  Future<void> _computeRawRowsIfNeeded() async {
    if (_isBinaryHex || widget.rawContent.isEmpty) return;
    try {
      final indexer = widget.computeRowIndex ?? computeRawRowIndexInIsolate;
      final starts = await indexer(widget.rawContent);
      if (mounted) {
        _rawRowStarts = starts;
      }
    } catch (e) {
      if (mounted) {
        _rowIndexError = e.toString();
      }
    }
  }

  Future<void> _finalizeParsing() async {
    if (!mounted) return;
    await _restorePersistence();
    if (!mounted) return;
    setState(() {
      _isParsing = false;
    });
    if (_viewMode == 0 &&
        !_isBinaryHex &&
        widget.searchQuery != null &&
        widget.searchQuery!.isNotEmpty) {
      await _runRawSearch();
    } else {
      _updateMatchCount();
    }
  }

  Future<void> _runRawSearch() async {
    final generation = ++_rawSearchGeneration;
    final query = widget.searchQuery ?? '';
    final activeText = _effectiveRawText;
    if (query.isEmpty || _effectiveIsBinaryHex || activeText.isEmpty) {
      if (!mounted) return;
      setState(() {
        _rawMatchOffsets = Int32List(0);
        _rawMatchCount = 0;
        _rawSearchState = RawSearchState.idle;
      });
      if (_effectiveViewMode == 0) {
        widget.onMatchCountChanged?.call(0);
        widget.onSearchStateChanged?.call(RawSearchState.idle);
      }
      return;
    }

    if (mounted) {
      setState(() {
        _rawSearchState = RawSearchState.running;
      });
      if (_effectiveViewMode == 0) {
        widget.onSearchStateChanged?.call(RawSearchState.running);
      }
    }

    try {
      final finder = widget.findMatches ?? findRawMatchesInIsolate;
      final result = await finder(activeText, query);
      if (!mounted || generation != _rawSearchGeneration) return;
      final nextState = result.capped
          ? RawSearchState.capped
          : RawSearchState.done;
      setState(() {
        _rawMatchOffsets = result.offsets;
        _rawMatchCount = result.offsets.length;
        _rawSearchState = nextState;
      });
      if (_effectiveViewMode == 0) {
        widget.onMatchCountChanged?.call(_rawMatchCount);
        widget.onSearchStateChanged?.call(nextState);
      }
    } catch (_) {
      if (!mounted || generation != _rawSearchGeneration) return;
      setState(() {
        _rawMatchOffsets = Int32List(0);
        _rawMatchCount = 0;
        _rawSearchState = RawSearchState.failed;
      });
      if (_effectiveViewMode == 0) {
        widget.onMatchCountChanged?.call(0);
        widget.onSearchStateChanged?.call(RawSearchState.failed);
      }
    }
  }

  Object? _currentDecodeInput() {
    if (_decodeChain.isNotEmpty) {
      final top = _decodeChain.last;
      if (top.bytes != null) return top.bytes;
      return top.rawText;
    }
    if (_isBinaryHex) return _binaryBytes;
    if (widget.rawContent.isEmpty) return null;
    return widget.rawContent;
  }

  Future<void> _triggerDecode(DecodeKind kind) async {
    final input = _currentDecodeInput();
    if (input == null) return;
    final generation = _decodeGeneration;
    setState(() {
      _isDecoding = true;
      _decodeError = null;
    });

    final result = await decodeValueAsync(input, kind);
    if (!mounted || generation != _decodeGeneration) return;

    if (result is DecodeFailure) {
      setState(() {
        _isDecoding = false;
        _decodeError = result.error;
      });
      return;
    }

    dynamic parsedJson;
    String? rawText;
    Uint8List? bytes;

    switch (result) {
      case DecodedJson(:final value):
        if (value is Map || value is List) {
          parsedJson = value;
          rawText = const JsonEncoder.withIndent('  ').convert(value);
        } else {
          rawText = value?.toString() ?? 'null';
        }
      case DecodedText(:final text):
        rawText = text;
      case DecodedBytes(bytes: final b):
        bytes = b;
      case DecodeFailure():
        break;
    }

    var rowStarts = Int32List(0);
    if (rawText != null && rawText.isNotEmpty) {
      try {
        final indexer = widget.computeRowIndex ?? computeRawRowIndexInIsolate;
        rowStarts = await indexer(rawText);
      } catch (_) {}
    }
    if (!mounted || generation != _decodeGeneration) return;

    setState(() {
      _isDecoding = false;
      _decodeError = null;
      _decodeChain.add(
        _DecodeStep(
          kind: kind,
          result: result,
          parsedJson: parsedJson,
          rawText: rawText,
          bytes: bytes,
          rawRowStarts: rowStarts,
        ),
      );
      if (parsedJson != null) {
        _viewMode = 1;
      } else if (bytes != null) {
        _viewMode = 3;
      } else {
        _viewMode = 0;
      }
      _rawMatchOffsets = Int32List(0);
      _rawMatchCount = 0;
      _treeMatchCount = 0;
    });

    if (_effectiveViewMode == 0 &&
        widget.searchQuery != null &&
        widget.searchQuery!.isNotEmpty) {
      await _runRawSearch();
    } else {
      _updateMatchCount();
    }
  }

  Future<void> _showOriginal() async {
    _decodeGeneration++;
    setState(() {
      _decodeChain.clear();
      _isDecoding = false;
      _decodeError = null;
      if (_isBinaryHex) {
        _viewMode = 3;
      } else if (_isValidJson) {
        _viewMode = widget.initialViewMode ?? 1;
      } else {
        _viewMode = 0;
      }
      _rawMatchOffsets = Int32List(0);
      _rawMatchCount = 0;
      _treeMatchCount = 0;
    });

    if (_effectiveViewMode == 0 &&
        !_isBinaryHex &&
        widget.searchQuery != null &&
        widget.searchQuery!.isNotEmpty) {
      await _runRawSearch();
    } else {
      _updateMatchCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final activeIsBinary = _effectiveIsBinaryHex;
    final activeBinaryBytes = _effectiveBinaryBytes;
    final activeIsValidJson = _effectiveIsValidJson;
    final activeParsedJson = _effectiveParsedJson;
    final activeRawText = _effectiveRawText;
    final activeRawRowStarts = _effectiveRawRowStarts;
    final activeViewMode = _effectiveViewMode;
    final maxHeight = widget.treeViewHeight ?? 300;

    Widget contentWidget;

    // View Mode Logic
    if (activeIsBinary) {
      final hex = HexViewer(bytes: activeBinaryBytes);
      contentWidget = widget.expand
          ? hex
          : SizedBox(height: maxHeight, child: hex);
    } else if (activeIsValidJson && activeViewMode == 1) {
      final tree = SmartVirtualJsonTree(
        key: _treeKey,
        json: activeParsedJson,
        searchQuery: widget.searchQuery,
        focusedMatchIndex: widget.focusedMatchIndex,
        hideNullFields: _hideNullFields,
        shrinkWrap: widget.fitTreeHeight,
        onMatchCountChanged: (count) {
          _treeMatchCount = count;
          _updateMatchCount();
        },
        onPinToColumn: _decodeChain.isEmpty ? widget.onPinToColumn : null,
        onFilterByField: _decodeChain.isEmpty ? widget.onFilterByField : null,
      );
      contentWidget = widget.fitTreeHeight
          ? ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: tree,
            )
          : SizedBox(height: maxHeight, child: tree);
    } else {
      // _viewMode == 0 or not valid JSON
      if (_rowIndexError != null && _decodeChain.isEmpty) {
        contentWidget = Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: colorScheme.error),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _rowIndexError!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (activeRawText.isEmpty) {
        contentWidget = widget.emptyValueMarker != null
            ? Text(
                widget.emptyValueMarker!,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: colorScheme.outline,
                ),
              )
            : const SizedBox.shrink();
      } else {
        final rawStyle = AppFonts.robotoMono(
          fontSize: 13,
          color: colorScheme.onSurface,
        );
        final rawList = SelectionArea(
          child: ScrollablePositionedList.builder(
            shrinkWrap: widget.fitTreeHeight && !widget.expand,
            itemCount: activeRawRowStarts.length,
            itemScrollController: _rawItemScrollController,
            itemBuilder: (context, index) => _buildRawRow(
              index,
              rawStyle,
              colorScheme,
              activeRawText,
              activeRawRowStarts,
            ),
          ),
        );
        contentWidget = widget.expand
            ? rawList
            : (widget.fitTreeHeight
                  ? ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      child: rawList,
                    )
                  : SizedBox(height: maxHeight, child: rawList));
      }
    }

    final canDecode =
        !_isParsing && (activeIsBinary || activeRawText.isNotEmpty);

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
                if (canDecode)
                  PopupMenuButton<DecodeKind>(
                    tooltip: l10n?.decodeAs ?? 'Decode as…',
                    icon: _isDecoding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : Icon(
                            Icons.transform,
                            size: 16,
                            color: _decodeChain.isNotEmpty
                                ? colorScheme.primary
                                : null,
                          ),
                    itemBuilder: (ctx) {
                      final l10n = AppLocalizations.of(ctx);
                      if (activeIsBinary) {
                        return [
                          PopupMenuItem<DecodeKind>(
                            value: DecodeKind.gzip,
                            child: Text(l10n?.decodeAsGzip ?? 'gzip'),
                          ),
                        ];
                      }
                      return [
                        PopupMenuItem<DecodeKind>(
                          value: DecodeKind.json,
                          child: Text(l10n?.decodeAsJson ?? 'JSON'),
                        ),
                        PopupMenuItem<DecodeKind>(
                          value: DecodeKind.base64,
                          child: Text(l10n?.decodeAsBase64 ?? 'Base64'),
                        ),
                        PopupMenuItem<DecodeKind>(
                          value: DecodeKind.gzip,
                          child: Text(l10n?.decodeAsGzip ?? 'gzip'),
                        ),
                      ];
                    },
                    onSelected: _triggerDecode,
                  ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip:
                      AppLocalizations.of(context)?.copyContent ??
                      'Copy content',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.rawContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)?.contentCopied ??
                              'Content copied to clipboard',
                        ),
                      ),
                    );
                  },
                ),
                if (activeIsValidJson) ...[
                  if (activeViewMode == 1) ...[
                    IconButton(
                      icon: Icon(
                        _hideNullFields
                            ? Icons.filter_alt
                            : Icons.filter_alt_off_outlined,
                        size: 16,
                        color: _hideNullFields
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                      tooltip: _hideNullFields
                          ? (AppLocalizations.of(context)?.showEmptyFields ??
                                'Show empty fields')
                          : (AppLocalizations.of(context)?.hideEmptyFields ??
                                'Hide empty fields'),
                      onPressed: () async {
                        setState(() {
                          _hideNullFields = !_hideNullFields;
                        });
                        if (widget.persistenceKey != null) {
                          final prefs = await SharedPreferences.getInstance();
                          prefs.setBool(
                            'json_hide_null_${widget.persistenceKey}',
                            _hideNullFields,
                          );
                        }
                      },
                    ),
                  ],
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 32,
                    child: ToggleButtons(
                      borderRadius: BorderRadius.circular(8),
                      isSelected: [_viewMode == 0, _viewMode == 1],
                      onPressed: (index) async {
                        setState(() {
                          _viewMode = index;
                        });
                        if (index == 0 &&
                            widget.searchQuery != null &&
                            widget.searchQuery!.isNotEmpty) {
                          _runRawSearch();
                        } else {
                          _updateMatchCount();
                          if (index == 1) {
                            widget.onSearchStateChanged?.call(
                              RawSearchState.idle,
                            );
                          }
                        }
                        if (_decodeChain.isEmpty &&
                            widget.persistenceKey != null) {
                          final prefs = await SharedPreferences.getInstance();
                          prefs.setInt(
                            'json_view_mode_${widget.persistenceKey}',
                            index,
                          );
                        }
                      },
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            AppLocalizations.of(context)?.raw ?? 'Raw',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            AppLocalizations.of(context)?.tree ?? 'Tree',
                            style: const TextStyle(fontSize: 12),
                          ),
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
        if (_decodeChain.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.transform,
                  size: 14,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _decodeChain
                        .map((s) => decodeKindLabel(l10n, s.kind))
                        .join(' → '),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final top = _decodeChain.last;
                    final textToCopy = top.bytes != null
                        ? formatHexBytes(top.bytes!)
                        : (top.rawText ?? '');
                    Clipboard.setData(ClipboardData(text: textToCopy));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n?.valueCopiedToClipboard ??
                              'Value copied to clipboard',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Text(l10n?.copyDecoded ?? 'Copy decoded'),
                ),
                TextButton(
                  onPressed: _showOriginal,
                  child: Text(l10n?.showOriginal ?? 'Show original'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (_decodeError != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 14,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    decodeErrorMessage(l10n, _decodeError!),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 14,
                    color: colorScheme.onErrorContainer,
                  ),
                  tooltip: AppLocalizations.of(context)?.close ?? 'Close',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _decodeError = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
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
                : contentWidget,
          ),
        ),
      ],
    );
  }

  int _firstMatchEndingAfter(Int32List offsets, int queryLen, int rowStart) {
    var lo = 0;
    var hi = offsets.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (offsets[mid] + queryLen <= rowStart) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  Widget _buildRawRow(
    int rowIndex,
    TextStyle style,
    ColorScheme colorScheme,
    String text,
    Int32List rowStarts,
  ) {
    final rowStart = rowStarts[rowIndex];
    final rowEnd = rawRowTextEnd(text, rowStarts, rowIndex);
    final rowText = text.substring(rowStart, rowEnd);
    final query = widget.searchQuery;

    if (query == null ||
        query.isEmpty ||
        _rawMatchOffsets.isEmpty ||
        _rawSearchState == RawSearchState.running ||
        _rawSearchState == RawSearchState.failed) {
      return Text.rich(TextSpan(text: rowText, style: style));
    }

    final qLen = query.length;
    var matchIdx = _firstMatchEndingAfter(_rawMatchOffsets, qLen, rowStart);
    if (matchIdx >= _rawMatchOffsets.length ||
        _rawMatchOffsets[matchIdx] >= rowEnd) {
      return Text.rich(TextSpan(text: rowText, style: style));
    }

    final spans = <TextSpan>[];
    var cursor = 0;
    while (matchIdx < _rawMatchOffsets.length &&
        _rawMatchOffsets[matchIdx] < rowEnd) {
      final matchStart = _rawMatchOffsets[matchIdx];
      final hlStart = math.max(matchStart, rowStart) - rowStart;
      final hlEnd = math.min(matchStart + qLen, rowEnd) - rowStart;
      if (hlStart > cursor) {
        spans.add(
          TextSpan(text: rowText.substring(cursor, hlStart), style: style),
        );
      }
      final isFocused = matchIdx == widget.focusedMatchIndex;
      spans.add(
        TextSpan(
          text: rowText.substring(hlStart, hlEnd),
          style: style.copyWith(
            backgroundColor: isFocused
                ? Colors.orange
                : colorScheme.tertiaryContainer,
            color: isFocused ? Colors.black : colorScheme.onTertiaryContainer,
            fontWeight: isFocused ? FontWeight.bold : null,
          ),
        ),
      );
      cursor = hlEnd;
      matchIdx++;
    }
    if (cursor < rowText.length) {
      spans.add(TextSpan(text: rowText.substring(cursor), style: style));
    }
    return Text.rich(TextSpan(children: spans));
  }
}

class _DecodeStep {
  final DecodeKind kind;
  final DecodeResult result;
  final dynamic parsedJson;
  final String? rawText;
  final Uint8List? bytes;
  final Int32List rawRowStarts;

  const _DecodeStep({
    required this.kind,
    required this.result,
    this.parsedJson,
    this.rawText,
    this.bytes,
    required this.rawRowStarts,
  });
}
