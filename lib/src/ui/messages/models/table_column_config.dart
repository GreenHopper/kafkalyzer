import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/ui/messages/models/projected_column.dart';

/// Identifiers for standard table columns.
class StandardTableColumns {
  static const String timestamp = 'timestamp';
  static const String step = 'step';
  static const String topic = 'topic';
  static const String partition = 'partition';
  static const String offset = 'offset';
  static const String key = 'key';
  static const String content = 'content';

  /// All standard column IDs in default logical order.
  static const List<String> all = [
    timestamp,
    step,
    topic,
    partition,
    offset,
    key,
    content,
  ];

  /// Standard column IDs applicable to explorer view (omitting step & topic).
  static const List<String> explorerStandard = [
    timestamp,
    partition,
    offset,
    key,
    content,
  ];

  /// Standard column IDs applicable to script view (including step & topic).
  static const List<String> scriptingStandard = [
    timestamp,
    step,
    topic,
    partition,
    offset,
    key,
    content,
  ];

  /// Default widths for columns in logical pixels.
  static const Map<String, double> defaultWidths = {
    timestamp: 180.0,
    step: 120.0,
    topic: 150.0,
    partition: 100.0,
    offset: 110.0,
    key: 240.0,
    content: 360.0,
  };

  static const double defaultProjectedWidth = 150.0;
  static const double minColumnWidth = 60.0;
  static const double maxColumnWidth = 800.0;
}

/// Represents the table column configuration for a topic or table view,
/// including standard column visibility, custom column widths, and dynamic projected columns.
@immutable
class TableColumnConfig {
  /// Set of column IDs that are hidden by the user.
  final Set<String> hiddenColumns;

  /// Custom widths for columns (standard column IDs or projected paths).
  final Map<String, double> columnWidths;

  /// Active dynamic projected columns extracted from JSON payload.
  final List<ProjectedColumn> projectedColumns;

  const TableColumnConfig({
    this.hiddenColumns = const {},
    this.columnWidths = const {},
    this.projectedColumns = const [],
  });

  /// Check if a column (by ID or path) is visible.
  bool isVisible(String columnId) => !hiddenColumns.contains(columnId);

  /// Returns width for standard column or projected column path, falling back to defaults.
  double getWidth(String columnId, {double? fallback}) {
    if (columnWidths.containsKey(columnId)) {
      return columnWidths[columnId]!.clamp(
        StandardTableColumns.minColumnWidth,
        StandardTableColumns.maxColumnWidth,
      );
    }
    if (StandardTableColumns.defaultWidths.containsKey(columnId)) {
      return StandardTableColumns.defaultWidths[columnId]!;
    }
    return fallback ?? StandardTableColumns.defaultProjectedWidth;
  }

  TableColumnConfig copyWith({
    Set<String>? hiddenColumns,
    Map<String, double>? columnWidths,
    List<ProjectedColumn>? projectedColumns,
  }) {
    return TableColumnConfig(
      hiddenColumns: hiddenColumns ?? this.hiddenColumns,
      columnWidths: columnWidths ?? this.columnWidths,
      projectedColumns: projectedColumns ?? this.projectedColumns,
    );
  }

  /// Serializes to JSON Map.
  Map<String, dynamic> toJson() {
    return {
      'version': 2,
      'hiddenColumns': hiddenColumns.toList(),
      'columnWidths': columnWidths,
      'projectedColumns': projectedColumns.map((c) => c.toJson()).toList(),
    };
  }

  /// Deserializes from dynamic JSON, gracefully handling legacy `List` presets.
  factory TableColumnConfig.fromJson(dynamic json) {
    if (json == null) {
      return const TableColumnConfig();
    }

    // Migration: Legacy format was a List of projected column json maps
    if (json is List) {
      final list = json
          .map((e) => ProjectedColumn.fromJson(e as Map<String, dynamic>))
          .toList();
      return TableColumnConfig(projectedColumns: list);
    }

    if (json is Map<String, dynamic>) {
      final hiddenList =
          (json['hiddenColumns'] as List?)?.map((e) => e.toString()).toSet() ??
          <String>{};

      final widthsRaw = json['columnWidths'] as Map<String, dynamic>? ?? {};
      final widths = <String, double>{};
      widthsRaw.forEach((k, v) {
        if (v is num) {
          widths[k] = v.toDouble();
        }
      });

      final projRaw = json['projectedColumns'] as List? ?? [];
      final proj = projRaw
          .map((e) => ProjectedColumn.fromJson(e as Map<String, dynamic>))
          .toList();

      return TableColumnConfig(
        hiddenColumns: hiddenList,
        columnWidths: widths,
        projectedColumns: proj,
      );
    }

    return const TableColumnConfig();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableColumnConfig &&
          runtimeType == other.runtimeType &&
          setEquals(hiddenColumns, other.hiddenColumns) &&
          mapEquals(columnWidths, other.columnWidths) &&
          listEquals(projectedColumns, other.projectedColumns);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(hiddenColumns),
    Object.hashAll(columnWidths.entries),
    Object.hashAll(projectedColumns),
  );
}
