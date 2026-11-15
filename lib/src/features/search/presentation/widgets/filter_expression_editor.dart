import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/search/domain/filter_expression_ast.dart';
import 'package:kafkalyzer/src/features/search/domain/filter_field_suggestions.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/filter_expression_editing_controller.dart';
import 'package:kafkalyzer/src/rust/api/filter_expr.dart';
import 'package:material_ui/material_ui.dart';

class FilterExpressionEditor extends StatefulWidget {
  final FilterExpressionEditingController controller;
  final FilterFieldSuggestions? suggestions;
  final bool showPlaceholderHint;

  const FilterExpressionEditor({
    super.key,
    required this.controller,
    this.suggestions,
    this.showPlaceholderHint = false,
  });

  @override
  State<FilterExpressionEditor> createState() => _FilterExpressionEditorState();
}

class _FilterExpressionEditorState extends State<FilterExpressionEditor> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.text);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant FilterExpressionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _textController.text = widget.controller.text;
    }
  }

  void _onControllerChanged() {
    if (_textController.text != widget.controller.text) {
      _textController.value = TextEditingValue(
        text: widget.controller.text,
        selection: TextSelection.collapsed(
          offset: widget.controller.text.length,
        ),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = widget.controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              l10n.filterExpressionLabel,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const Spacer(),
            SegmentedButton<FilterExpressionMode>(
              segments: [
                ButtonSegment(
                  value: FilterExpressionMode.builder,
                  label: Text(l10n.filterExpressionModeBuilder),
                ),
                ButtonSegment(
                  value: FilterExpressionMode.text,
                  label: Text(l10n.filterExpressionModeText),
                ),
              ],
              selected: {ctrl.mode},
              onSelectionChanged: (sel) {
                ctrl.switchMode(sel.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (ctrl.mode == FilterExpressionMode.text)
          _buildTextMode(context, l10n, ctrl)
        else
          _buildBuilderMode(context, l10n, ctrl),
        if (ctrl.error != null) ...[
          const SizedBox(height: 6),
          Text(
            l10n.filterExpressionErrorAtColumn(
              ctrl.error!.startUtf16 + 1,
              ctrl.error!.message,
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
        if (widget.showPlaceholderHint) ...[
          const SizedBox(height: 4),
          Text(
            l10n.filterExpressionPlaceholderHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (widget.suggestions != null) ...[
          const SizedBox(height: 6),
          _buildSuggestionsBar(context, l10n, widget.suggestions!, ctrl),
        ],
      ],
    );
  }

  Widget _buildTextMode(
    BuildContext context,
    AppLocalizations l10n,
    FilterExpressionEditingController ctrl,
  ) {
    return TextField(
      controller: _textController,
      decoration: InputDecoration(
        hintText: l10n.filterExpressionHint,
        border: const OutlineInputBorder(),
        isDense: true,
        errorText: ctrl.error != null ? '' : null,
        errorStyle: const TextStyle(height: 0, fontSize: 0),
      ),
      maxLines: 2,
      minLines: 1,
      onChanged: ctrl.setText,
    );
  }

  Widget _buildBuilderMode(
    BuildContext context,
    AppLocalizations l10n,
    FilterExpressionEditingController ctrl,
  ) {
    final root = ctrl.tree ?? const FilterAndNode([]);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _buildGroupOrNode(
        context,
        l10n,
        root,
        isRoot: true,
        onChanged: ctrl.updateTree,
      ),
    );
  }

  Widget _buildGroupOrNode(
    BuildContext context,
    AppLocalizations l10n,
    FilterAstNode node, {
    required bool isRoot,
    required ValueChanged<FilterAstNode?> onChanged,
  }) {
    if (node is FilterNotNode) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Chip(
              label: Text(l10n.filterExpressionNotToggle),
              onDeleted: () => onChanged(node.child),
              deleteButtonTooltipMessage: l10n.filterExpressionNotToggle,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildGroupOrNode(
                context,
                l10n,
                node.child,
                isRoot: false,
                onChanged: (updated) {
                  if (updated == null) {
                    onChanged(null);
                  } else {
                    onChanged(FilterNotNode(updated));
                  }
                },
              ),
            ),
          ],
        ),
      );
    }

    if (node is FilterCondNode) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildConditionChip(context, l10n, node.condition, (updated) {
            onChanged(updated == null ? null : FilterCondNode(updated));
          }),
          if (isRoot)
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(l10n.filterExpressionAddCondition),
              onPressed: () {
                onChanged(FilterAndNode([node, _defaultCondition()]));
              },
            ),
        ],
      );
    }

    final isAnd = node is FilterAndNode;
    final children = switch (node) {
      FilterAndNode(:final children) => children,
      FilterOrNode(:final children) => children,
      _ => const <FilterAstNode>[],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: Text(
                isAnd
                    ? l10n.filterExpressionAndLabel
                    : l10n.filterExpressionOrLabel,
              ),
              selected: true,
              onSelected: (_) {
                onChanged(
                  isAnd ? FilterOrNode(children) : FilterAndNode(children),
                );
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(l10n.filterExpressionAddCondition),
              onPressed: () {
                final next = [...children, _defaultCondition()];
                onChanged(isAnd ? FilterAndNode(next) : FilterOrNode(next));
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.account_tree_outlined, size: 16),
              label: Text(l10n.filterExpressionAddGroup),
              onPressed: () {
                final next = [
                  ...children,
                  if (isAnd)
                    FilterOrNode([_defaultCondition()])
                  else
                    FilterAndNode([_defaultCondition()]),
                ];
                onChanged(isAnd ? FilterAndNode(next) : FilterOrNode(next));
              },
            ),
            if (!isRoot)
              IconButton(
                icon: const Icon(Icons.exposure_neg_1, size: 18),
                tooltip: l10n.filterExpressionNotToggle,
                onPressed: () => onChanged(FilterNotNode(node)),
              ),
            if (!isRoot)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: l10n.filterExpressionRemoveNode,
                onPressed: () => onChanged(null),
              ),
          ],
        ),
        if (children.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  _buildGroupOrNode(
                    context,
                    l10n,
                    children[i],
                    isRoot: false,
                    onChanged: (updated) {
                      final next = [...children];
                      if (updated == null) {
                        next.removeAt(i);
                      } else {
                        next[i] = updated;
                      }
                      onChanged(
                        isAnd ? FilterAndNode(next) : FilterOrNode(next),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConditionChip(
    BuildContext context,
    AppLocalizations l10n,
    FilterConditionDto cond,
    ValueChanged<FilterConditionDto?> onChanged,
  ) {
    final label = _formatConditionSummary(l10n, cond);
    return InputChip(
      label: Text(label),
      tooltip: l10n.filterExpressionEditCondition,
      onPressed: () async {
        final edited = await _showConditionDialog(context, l10n, cond);
        if (edited != null) {
          onChanged(edited);
        }
      },
      deleteButtonTooltipMessage: l10n.filterExpressionRemoveNode,
      onDeleted: () => onChanged(null),
    );
  }

  FilterCondNode _defaultCondition() {
    return const FilterCondNode(
      FilterConditionDto(
        fieldKind: FilterFieldKind.value,
        fieldPath: 'status',
        op: FilterOpDto.eq,
        scalar: FilterScalarDto(
          kind: FilterScalarKind.string,
          text: '',
          intVal: null,
          floatVal: null,
          boolVal: null,
        ),
        listItems: [],
      ),
    );
  }

  String _formatConditionSummary(
    AppLocalizations l10n,
    FilterConditionDto cond,
  ) {
    final fieldStr = switch (cond.fieldKind) {
      FilterFieldKind.value => 'value.${cond.fieldPath ?? ''}',
      FilterFieldKind.key => 'key',
      FilterFieldKind.keyPath => 'key.${cond.fieldPath ?? ''}',
      FilterFieldKind.header => 'header.${cond.fieldPath ?? ''}',
      FilterFieldKind.timestamp => 'timestamp',
      FilterFieldKind.offset => 'offset',
      FilterFieldKind.partition => 'partition',
    };
    final opStr = _opLabel(l10n, cond.op);
    if (cond.op == FilterOpDto.exists ||
        cond.op == FilterOpDto.isNull ||
        cond.op == FilterOpDto.isNotNull) {
      return '$fieldStr $opStr';
    }
    final valStr = cond.scalar == null
        ? '[${cond.listItems.map((e) => e.text).join(', ')}]'
        : switch (cond.scalar!.kind) {
            FilterScalarKind.string => '"${cond.scalar!.text}"',
            FilterScalarKind.placeholder => '{{${cond.scalar!.text}}}',
            _ => cond.scalar!.text,
          };
    return '$fieldStr $opStr $valStr';
  }

  String _opLabel(AppLocalizations l10n, FilterOpDto op) {
    return switch (op) {
      FilterOpDto.eq => l10n.filterExpressionOpEq,
      FilterOpDto.ne => l10n.filterExpressionOpNe,
      FilterOpDto.gt => l10n.filterExpressionOpGt,
      FilterOpDto.ge => l10n.filterExpressionOpGe,
      FilterOpDto.lt => l10n.filterExpressionOpLt,
      FilterOpDto.le => l10n.filterExpressionOpLe,
      FilterOpDto.contains => l10n.filterExpressionOpContains,
      FilterOpDto.startsWith => l10n.filterExpressionOpStartsWith,
      FilterOpDto.endsWith => l10n.filterExpressionOpEndsWith,
      FilterOpDto.matches => l10n.filterExpressionOpMatches,
      FilterOpDto.in_ => l10n.filterExpressionOpIn,
      FilterOpDto.exists => l10n.filterExpressionOpExists,
      FilterOpDto.isNull => l10n.filterExpressionOpIsNull,
      FilterOpDto.isNotNull => l10n.filterExpressionOpIsNotNull,
    };
  }

  Future<FilterConditionDto?> _showConditionDialog(
    BuildContext context,
    AppLocalizations l10n,
    FilterConditionDto initial,
  ) async {
    var fieldKind = initial.fieldKind;
    final pathCtrl = TextEditingController(text: initial.fieldPath ?? '');
    var op = initial.op;
    var scalarKind = initial.scalar?.kind ?? FilterScalarKind.string;
    final valCtrl = TextEditingController(text: initial.scalar?.text ?? '');

    final result = await showDialog<FilterConditionDto>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final needsPath =
              fieldKind == FilterFieldKind.value ||
              fieldKind == FilterFieldKind.keyPath ||
              fieldKind == FilterFieldKind.header;
          final isUnary =
              op == FilterOpDto.exists ||
              op == FilterOpDto.isNull ||
              op == FilterOpDto.isNotNull;

          return AlertDialog(
            title: Text(l10n.filterExpressionEditCondition),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<FilterFieldKind>(
                  initialValue: fieldKind,
                  decoration: InputDecoration(
                    labelText: l10n.filterExpressionSourceLabel,
                  ),
                  items: FilterFieldKind.values
                      .map(
                        (k) => DropdownMenuItem(value: k, child: Text(k.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => fieldKind = v);
                  },
                ),
                if (needsPath) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: pathCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.filterExpressionPathLabel,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<FilterOpDto>(
                  initialValue: op,
                  decoration: InputDecoration(
                    labelText: l10n.filterExpressionOperatorLabel,
                  ),
                  items: FilterOpDto.values
                      .map(
                        (o) => DropdownMenuItem(
                          value: o,
                          child: Text(_opLabel(l10n, o)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => op = v);
                  },
                ),
                if (!isUnary) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<FilterScalarKind>(
                    initialValue: scalarKind,
                    items: FilterScalarKind.values
                        .map(
                          (k) => DropdownMenuItem(
                            value: k,
                            child: Text(switch (k) {
                              FilterScalarKind.string =>
                                l10n.filterExpressionTypeString,
                              FilterScalarKind.int || FilterScalarKind.float =>
                                l10n.filterExpressionTypeNumber,
                              FilterScalarKind.bool =>
                                l10n.filterExpressionTypeBoolean,
                              FilterScalarKind.null_ =>
                                l10n.filterExpressionTypeNull,
                              FilterScalarKind.placeholder =>
                                l10n.filterExpressionTypeVariable,
                            }),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => scalarKind = v);
                    },
                  ),
                  if (scalarKind != FilterScalarKind.null_) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: valCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.filterExpressionValueLabel,
                      ),
                    ),
                  ],
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final nullText = l10n.filterExpressionTypeNull.toLowerCase();
                  final scalar = isUnary
                      ? null
                      : FilterScalarDto(
                          kind: scalarKind,
                          text: scalarKind == FilterScalarKind.null_
                              ? nullText
                              : valCtrl.text,
                          intVal: scalarKind == FilterScalarKind.int
                              ? int.tryParse(valCtrl.text)
                              : null,
                          floatVal: scalarKind == FilterScalarKind.float
                              ? double.tryParse(valCtrl.text)
                              : null,
                          boolVal: scalarKind == FilterScalarKind.bool
                              ? valCtrl.text.toLowerCase() == 'true'
                              : null,
                        );
                  Navigator.of(ctx).pop(
                    FilterConditionDto(
                      fieldKind: fieldKind,
                      fieldPath: needsPath ? pathCtrl.text.trim() : null,
                      op: op,
                      scalar: scalar,
                      listItems: const [],
                    ),
                  );
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
    pathCtrl.dispose();
    valCtrl.dispose();
    return result;
  }

  Widget _buildSuggestionsBar(
    BuildContext context,
    AppLocalizations l10n,
    FilterFieldSuggestions suggestions,
    FilterExpressionEditingController ctrl,
  ) {
    if (suggestions.isEmpty) {
      return Text(
        l10n.filterExpressionSuggestionsEmpty,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final sourceLabel = switch (suggestions.source) {
      FilterSuggestionSource.schema =>
        l10n.filterExpressionSuggestionsSourceSchema,
      FilterSuggestionSource.analysis =>
        l10n.filterExpressionSuggestionsSourceAnalysis,
      FilterSuggestionSource.sample =>
        l10n.filterExpressionSuggestionsSourceSample,
      null => l10n.filterExpressionSuggestionsLabel,
    };

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$sourceLabel:', style: Theme.of(context).textTheme.labelSmall),
        for (final p in suggestions.valuePaths.take(12))
          _buildSuggestionChip('value.$p', ctrl),
        for (final h in suggestions.headerNames.take(8))
          _buildSuggestionChip('header.$h', ctrl),
      ],
    );
  }

  Widget _buildSuggestionChip(
    String fieldRef,
    FilterExpressionEditingController ctrl,
  ) {
    return ActionChip(
      label: Text(fieldRef),
      onPressed: () {
        final cur = ctrl.text.trim();
        final insertion = '$fieldRef = ""';
        ctrl.setText(cur.isEmpty ? insertion : '$cur AND $insertion');
      },
    );
  }
}
