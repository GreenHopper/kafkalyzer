import 'dart:typed_data';

import 'package:kafkalyzer/src/rust/api/filter_expr.dart';

sealed class FilterAstNode {
  const FilterAstNode();
}

final class FilterAndNode extends FilterAstNode {
  final List<FilterAstNode> children;
  const FilterAndNode(this.children);
}

final class FilterOrNode extends FilterAstNode {
  final List<FilterAstNode> children;
  const FilterOrNode(this.children);
}

final class FilterNotNode extends FilterAstNode {
  final FilterAstNode child;
  const FilterNotNode(this.child);
}

final class FilterCondNode extends FilterAstNode {
  final FilterConditionDto condition;
  const FilterCondNode(this.condition);
}

FilterAstNode filterAstFromFlatDtos(List<FilterNodeDto> dtos) {
  if (dtos.isEmpty) {
    throw ArgumentError('FilterNodeDto list cannot be empty');
  }

  FilterAstNode build(int index) {
    final dto = dtos[index];
    return switch (dto.kind) {
      FilterNodeKind.and => FilterAndNode(dto.children.map(build).toList()),
      FilterNodeKind.or => FilterOrNode(dto.children.map(build).toList()),
      FilterNodeKind.not => FilterNotNode(build(dto.children.first)),
      FilterNodeKind.cond => FilterCondNode(dto.condition!),
    };
  }

  return build(0);
}

List<FilterNodeDto> filterAstToFlatDtos(FilterAstNode root) {
  final out = <FilterNodeDto>[];

  int push(FilterAstNode node) {
    final idx = out.length;
    out.add(
      FilterNodeDto(
        kind: FilterNodeKind.cond,
        children: Uint32List(0),
        condition: null,
      ),
    );
    switch (node) {
      case FilterAndNode(:final children):
        final ids = children.map(push).toList();
        out[idx] = FilterNodeDto(
          kind: FilterNodeKind.and,
          children: Uint32List.fromList(ids),
          condition: null,
        );
      case FilterOrNode(:final children):
        final ids = children.map(push).toList();
        out[idx] = FilterNodeDto(
          kind: FilterNodeKind.or,
          children: Uint32List.fromList(ids),
          condition: null,
        );
      case FilterNotNode(:final child):
        final childId = push(child);
        out[idx] = FilterNodeDto(
          kind: FilterNodeKind.not,
          children: Uint32List.fromList([childId]),
          condition: null,
        );
      case FilterCondNode(:final condition):
        out[idx] = FilterNodeDto(
          kind: FilterNodeKind.cond,
          children: Uint32List(0),
          condition: condition,
        );
    }
    return idx;
  }

  push(root);
  return out;
}
