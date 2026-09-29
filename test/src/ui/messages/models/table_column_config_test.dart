import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/ui/messages/models/projected_column.dart';
import 'package:kafkalyzer/src/ui/messages/models/table_column_config.dart';

void main() {
  group('TableColumnConfig', () {
    test('default configuration has correct initial values', () {
      const config = TableColumnConfig();
      expect(config.hiddenColumns, isEmpty);
      expect(config.columnWidths, isEmpty);
      expect(config.projectedColumns, isEmpty);
      expect(config.isVisible(StandardTableColumns.timestamp), isTrue);
      expect(config.getWidth(StandardTableColumns.timestamp), 180.0);
      expect(config.getWidth(StandardTableColumns.key), 240.0);
      expect(
        config.getWidth('unknown_col'),
        StandardTableColumns.defaultProjectedWidth,
      );
    });

    test('serializes to JSON and deserializes correctly', () {
      final config = TableColumnConfig(
        hiddenColumns: {'partition', 'offset'},
        columnWidths: {'timestamp': 200.0, 'customer.name': 175.0},
        projectedColumns: [
          const ProjectedColumn(
            path: 'customer.name',
            label: 'Customer',
            width: 175.0,
          ),
        ],
      );

      final json = config.toJson();
      expect(json['version'], 2);
      expect(json['hiddenColumns'], containsAll(['partition', 'offset']));
      expect(json['columnWidths']['timestamp'], 200.0);

      final restored = TableColumnConfig.fromJson(json);
      expect(restored.hiddenColumns, containsAll(['partition', 'offset']));
      expect(restored.getWidth('timestamp'), 200.0);
      expect(restored.getWidth('customer.name'), 175.0);
      expect(restored.isVisible('partition'), isFalse);
      expect(restored.isVisible('timestamp'), isTrue);
      expect(restored.projectedColumns.length, 1);
      expect(restored.projectedColumns.first.path, 'customer.name');
    });

    test('gracefully migrates legacy List json format', () {
      final legacyJson = [
        {'path': 'user.email', 'label': 'email', 'width': 180.0},
        {'path': 'order.id', 'label': 'id', 'width': 120.0},
      ];

      final restored = TableColumnConfig.fromJson(legacyJson);
      expect(restored.hiddenColumns, isEmpty);
      expect(restored.columnWidths, isEmpty);
      expect(restored.projectedColumns.length, 2);
      expect(restored.projectedColumns[0].path, 'user.email');
      expect(restored.projectedColumns[1].label, 'id');
    });

    test('clamps custom column widths between min and max bounds', () {
      final config = TableColumnConfig(
        columnWidths: {'col_tiny': 10.0, 'col_huge': 2000.0},
      );
      expect(config.getWidth('col_tiny'), StandardTableColumns.minColumnWidth);
      expect(config.getWidth('col_huge'), StandardTableColumns.maxColumnWidth);
    });
  });
}
