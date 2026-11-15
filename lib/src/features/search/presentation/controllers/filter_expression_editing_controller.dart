import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/features/search/domain/filter_expression_ast.dart';
import 'package:kafkalyzer/src/rust/api/filter_expr.dart';

enum FilterExpressionMode { builder, text }

typedef ParseFilterExpressionFn =
    FilterParseResultDto Function({required String input});
typedef FormatFilterExpressionFn =
    String Function({required List<FilterNodeDto> nodes});

class FilterExpressionEditingController extends ChangeNotifier {
  FilterExpressionEditingController({
    String initialText = '',
    FilterExpressionMode initialMode = FilterExpressionMode.text,
    ParseFilterExpressionFn? parseFn,
    FormatFilterExpressionFn? formatFn,
    Duration debounceDuration = const Duration(milliseconds: 250),
  }) : _text = initialText,
       _mode = initialMode,
       _parseFn = parseFn ?? parseFilterExpression,
       _formatFn = formatFn ?? formatFilterExpression,
       _debounceDuration = debounceDuration {
    if (_text.trim().isNotEmpty) {
      validateNow(notify: false);
    }
  }

  final ParseFilterExpressionFn _parseFn;
  final FormatFilterExpressionFn _formatFn;
  final Duration _debounceDuration;

  Timer? _debounce;
  FilterExpressionMode _mode;
  String _text;
  FilterAstNode? _tree;
  FilterErrorDto? _error;

  FilterExpressionMode get mode => _mode;
  String get text => _text;
  FilterAstNode? get tree => _tree;
  FilterErrorDto? get error => _error;
  bool get isValid => _text.trim().isEmpty || _error == null;

  void setText(String value) {
    if (_text == value) return;
    _text = value;
    if (_text.trim().isEmpty) {
      _debounce?.cancel();
      _error = null;
      _tree = null;
      notifyListeners();
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => validateNow());
    notifyListeners();
  }

  bool validateNow({bool notify = true}) {
    _debounce?.cancel();
    final trimmed = _text.trim();
    if (trimmed.isEmpty) {
      _error = null;
      _tree = null;
      if (notify) notifyListeners();
      return true;
    }
    final result = _parseFn(input: trimmed);
    if (result.ok) {
      _error = null;
      _tree = result.nodes.isNotEmpty
          ? filterAstFromFlatDtos(result.nodes)
          : null;
      if (notify) notifyListeners();
      return true;
    } else {
      _error =
          result.error ??
          const FilterErrorDto(message: '', startUtf16: 0, endUtf16: 0);
      if (notify) notifyListeners();
      return false;
    }
  }

  /// Switches between [FilterExpressionMode.text] and [FilterExpressionMode.builder].
  /// Returns `false` if switching from text to builder is blocked by a parse error.
  bool switchMode(FilterExpressionMode nextMode) {
    if (_mode == nextMode) return true;
    if (nextMode == FilterExpressionMode.builder) {
      if (_text.trim().isEmpty) {
        _error = null;
        _tree = const FilterAndNode([]);
        _mode = FilterExpressionMode.builder;
        notifyListeners();
        return true;
      }
      if (!validateNow(notify: false)) {
        notifyListeners();
        return false;
      }
      _mode = FilterExpressionMode.builder;
      notifyListeners();
      return true;
    } else {
      if (_tree != null) {
        _syncTextFromTree();
      }
      _mode = FilterExpressionMode.text;
      notifyListeners();
      return true;
    }
  }

  void updateTree(FilterAstNode? newTree) {
    _tree = newTree;
    if (newTree == null ||
        (newTree is FilterAndNode && newTree.children.isEmpty) ||
        (newTree is FilterOrNode && newTree.children.isEmpty)) {
      _text = '';
      _error = null;
      notifyListeners();
      return;
    }
    _syncTextFromTree();
    notifyListeners();
  }

  void _syncTextFromTree() {
    final node = _tree;
    if (node == null) return;
    if ((node is FilterAndNode && node.children.isEmpty) ||
        (node is FilterOrNode && node.children.isEmpty)) {
      _text = '';
      _error = null;
      return;
    }
    final normalized = _normalizeEmptyGroups(node);
    if (normalized == null) {
      _text = '';
      _error = null;
      return;
    }
    final dtos = filterAstToFlatDtos(normalized);
    _text = _formatFn(nodes: dtos);
    _error = null;
  }

  FilterAstNode? _normalizeEmptyGroups(FilterAstNode node) {
    return switch (node) {
      FilterAndNode(:final children) => () {
        final kept = children
            .map(_normalizeEmptyGroups)
            .whereType<FilterAstNode>()
            .toList();
        if (kept.isEmpty) return null;
        if (kept.length == 1) return kept.first;
        return FilterAndNode(kept);
      }(),
      FilterOrNode(:final children) => () {
        final kept = children
            .map(_normalizeEmptyGroups)
            .whereType<FilterAstNode>()
            .toList();
        if (kept.isEmpty) return null;
        if (kept.length == 1) return kept.first;
        return FilterOrNode(kept);
      }(),
      FilterNotNode(:final child) => () {
        final inner = _normalizeEmptyGroups(child);
        return inner == null ? null : FilterNotNode(inner);
      }(),
      FilterCondNode() => node,
    };
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
