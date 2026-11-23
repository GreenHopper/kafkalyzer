import 'package:flutter/foundation.dart';

/// Represents a user-projected column extracted from JSON message payloads
/// for display in the master message table.
@immutable
class ProjectedColumn {
  /// The normalized JSON path used to extract the cell value (e.g. `customer.name`, `leistungen[0].transportId`).
  final String path;

  /// The human-readable header label for this column.
  final String label;

  /// The column width in logical pixels.
  final double width;

  const ProjectedColumn({
    required this.path,
    required this.label,
    this.width = 150.0,
  });

  /// Creates a [ProjectedColumn] with an automatically generated label derived from [path].
  factory ProjectedColumn.fromPath(String path, {double width = 150.0}) {
    return ProjectedColumn(path: path, label: deriveLabel(path), width: width);
  }

  /// Derives a concise, readable column label from a JSON [path].
  ///
  /// Examples:
  /// - `customer.address.city` -> `city`
  /// - `leistungen[0].transportId` -> `transportId`
  /// - `items[0]` -> `items[0]`
  static String deriveLabel(String path) {
    if (path.isEmpty) return 'Field';
    final parts = path.split('.');
    final lastPart = parts.last;
    return lastPart.isNotEmpty ? lastPart : path;
  }

  Map<String, dynamic> toJson() {
    return {'path': path, 'label': label, 'width': width};
  }

  factory ProjectedColumn.fromJson(Map<String, dynamic> json) {
    final path = json['path'] as String? ?? '';
    final label = json['label'] as String? ?? deriveLabel(path);
    final width = (json['width'] as num?)?.toDouble() ?? 150.0;
    return ProjectedColumn(path: path, label: label, width: width);
  }

  ProjectedColumn copyWith({String? path, String? label, double? width}) {
    return ProjectedColumn(
      path: path ?? this.path,
      label: label ?? this.label,
      width: width ?? this.width,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectedColumn &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() =>
      'ProjectedColumn(path: $path, label: $label, width: $width)';
}
