import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/ui/smart_tree/json_tree_flattener.dart';
import 'package:kafkalyzer/src/ui/smart_tree/virtual_json_node.dart';

void main() {
  group('JsonTreeFlattener', () {
    test('flattens simple flat map into primitive nodes', () {
      final json = {'name': 'Alice', 'age': 30, 'active': true};
      final result = JsonTreeFlattener.flatten(json);

      expect(result.nodes.length, 3);
      expect(result.nodes[0].key, 'name');
      expect(result.nodes[0].value, 'Alice');
      expect(result.nodes[0].type, JsonNodeType.primitive);

      expect(result.nodes[1].key, 'age');
      expect(result.nodes[1].value, 30);

      expect(result.nodes[2].key, 'active');
      expect(result.nodes[2].value, true);
    });

    test('flattens nested objects based on expandedPaths', () {
      final json = {
        'user': {
          'details': {
            'bio': 'Developer',
          }
        }
      };

      // Initially 'root.user' is not expanded
      final resultCollapsed = JsonTreeFlattener.flatten(
        json,
        expandedPaths: {},
        autoExpandSingleItemCollections: false,
      );
      expect(resultCollapsed.nodes.length, 1);
      expect(resultCollapsed.nodes[0].key, 'user');
      expect(resultCollapsed.nodes[0].type, JsonNodeType.object);
      expect(resultCollapsed.nodes[0].isExpanded, isFalse);

      // Expand 'root.user'
      final resultExpandedUser = JsonTreeFlattener.flatten(
        json,
        expandedPaths: {'root.user'},
        autoExpandSingleItemCollections: false,
      );
      expect(resultExpandedUser.nodes.length, 2);
      expect(resultExpandedUser.nodes[0].key, 'user');
      expect(resultExpandedUser.nodes[1].key, 'details');
      expect(resultExpandedUser.nodes[1].depth, 1);

      // Expand 'root.user' and 'root.user.details'
      final resultExpandedAll = JsonTreeFlattener.flatten(
        json,
        expandedPaths: {'root.user', 'root.user.details'},
        autoExpandSingleItemCollections: false,
      );
      expect(resultExpandedAll.nodes.length, 3);
      expect(resultExpandedAll.nodes[2].key, 'bio');
      expect(resultExpandedAll.nodes[2].value, 'Developer');
      expect(resultExpandedAll.nodes[2].depth, 2);
    });

    test('replaces recognized composite entity with compositeBadge node when collapsed', () {
      final json = {
        'id': 'ORD-1',
        'destination': {
          'strasse': 'Kärntner Strasse 1',
          'plz': '1010',
          'ort': 'Wien',
        },
      };

      final result = JsonTreeFlattener.flatten(json, expandedPaths: {});

      expect(result.nodes.length, 2);
      expect(result.nodes[0].key, 'id');
      expect(result.nodes[1].key, 'destination');
      expect(result.nodes[1].type, JsonNodeType.compositeBadge);
      expect(result.nodes[1].badgeData, isNotNull);
      expect(result.nodes[1].badgeData!.label, 'Kärntner Strasse 1, 1010 Wien');
    });

    test('replaces generic compact flat object with compositeBadge node', () {
      final json = {
        'orderId': 500,
        'customer': {
          'id': 1042,
          'name': 'Acme Corp',
        },
      };

      final result = JsonTreeFlattener.flatten(json, expandedPaths: {});

      expect(result.nodes.length, 2);
      expect(result.nodes[0].key, 'orderId');
      expect(result.nodes[1].key, 'customer');
      expect(result.nodes[1].type, JsonNodeType.compositeBadge);
      expect(result.nodes[1].badgeData, isNotNull);
      expect(result.nodes[1].badgeData!.label, '1042 • Acme Corp');
    });

    test('auto-expands ancestors and marks matches when searchQuery is provided', () {
      final json = {
        'organization': {
          'department': {
            'manager': 'Grace Hopper',
          }
        }
      };

      final result = JsonTreeFlattener.flatten(
        json,
        expandedPaths: {}, // Not expanded initially
        searchQuery: 'Hopper',
      );

      // Ancestors should be auto-expanded
      expect(result.nodes.length, 3);
      expect(result.nodes[0].key, 'organization');
      expect(result.nodes[1].key, 'department');
      expect(result.nodes[2].key, 'manager');
      expect(result.nodes[2].isMatch, isTrue);
      expect(result.matchNodeIndices, [2]);
    });

    test('segments array with Context Windowing when search matches item', () {
      final items = List.generate(20, (i) => {'id': i, 'name': 'Item $i'});
      final json = {'leistungen': items};

      // Search for 'Item 10'
      final result = JsonTreeFlattener.flatten(
        json,
        expandedPaths: {'root.leistungen'},
        searchQuery: 'Item 10',
        enableContextWindowing: true,
        contextRadius: 1,
      );

      // root.leistungen node is index 0
      expect(result.nodes[0].key, 'leistungen');
      expect(result.nodes[0].type, JsonNodeType.array);

      // Items around index 10: visible should be [9], [10], [11]
      // Collapsed range 1: 0..8
      // Collapsed range 2: 12..19
      final collapsedNodes = result.nodes
          .where((n) => n.type == JsonNodeType.collapsedRange)
          .toList();

      expect(collapsedNodes.length, 2);
      expect(collapsedNodes[0].collapsedRangeStart, 0);
      expect(collapsedNodes[0].collapsedRangeEnd, 8);
      expect(collapsedNodes[0].collapsedCount, 9);

      expect(collapsedNodes[1].collapsedRangeStart, 12);
      expect(collapsedNodes[1].collapsedRangeEnd, 19);
      expect(collapsedNodes[1].collapsedCount, 8);

      // Verify matching node is expanded and marked
      final matchingNodes = result.nodes.where((n) => n.isMatch).toList();
      expect(matchingNodes, isNotEmpty);
    });

    test('expands collapsed range when range path is in manuallyExpandedRanges', () {
      final items = List.generate(20, (i) => {'id': i, 'title': 'Task $i'});
      final json = {'items': items};

      final rangeKey = 'root.items[0-8]';
      final result = JsonTreeFlattener.flatten(
        json,
        expandedPaths: {'root.items'},
        searchQuery: 'Task 10',
        enableContextWindowing: true,
        contextRadius: 1,
        manuallyExpandedRanges: {rangeKey},
      );

      // Range 0..8 was manually expanded, so only range 12..19 should be collapsedRange
      final collapsedNodes = result.nodes
          .where((n) => n.type == JsonNodeType.collapsedRange)
          .toList();

      expect(collapsedNodes.length, 1);
      expect(collapsedNodes[0].collapsedRangeStart, 12);
      expect(collapsedNodes[0].collapsedRangeEnd, 19);
    });

    test('bypasses Context Windowing when array is in forcedShowAllArrays', () {
      final items = List.generate(20, (i) => {'id': i, 'title': 'Entry $i'});
      final json = {'entries': items};

      final result = JsonTreeFlattener.flatten(
        json,
        expandedPaths: {'root.entries'},
        searchQuery: 'Entry 10',
        enableContextWindowing: true,
        contextRadius: 1,
        forcedShowAllArrays: {'root.entries'},
      );

      // No collapsedRange nodes should be present
      final collapsedNodes = result.nodes
          .where((n) => n.type == JsonNodeType.collapsedRange)
          .toList();

      expect(collapsedNodes, isEmpty);
    });

    test('compresses unbranched single-child Map chain when enableIndentationFlattening is true', () {
      final json = {
        'leistungen': {
          'transport': {
            'orderId': 1001,
            'status': 'DELIVERED',
          }
        }
      };

      final result = JsonTreeFlattener.flatten(
        json,
        expandedPaths: {'root.leistungen.transport'},
        enableIndentationFlattening: true,
      );

      // The unbranched chain 'leistungen' -> 'transport' should be compressed into 'leistungen . transport'
      expect(result.nodes.length, 3);
      expect(result.nodes[0].key, 'leistungen . transport');
      expect(result.nodes[0].compoundPathKey, 'leistungen . transport');
      expect(result.nodes[0].depth, 0);

      expect(result.nodes[1].key, 'orderId');
      expect(result.nodes[1].depth, 1);

      expect(result.nodes[2].key, 'status');
      expect(result.nodes[2].depth, 1);
    });

    test('compresses array element with single-child Map when enableIndentationFlattening is true', () {
      final json = {
        'orders': [
          {
            'item': {
              'sku': 'A-100',
              'qty': 2,
            }
          }
        ]
      };

      final result = JsonTreeFlattener.flatten(
        json,
        expandedPaths: {'root.orders', 'root.orders[0].item'},
        enableIndentationFlattening: true,
      );

      // orders -> [0] . item
      expect(result.nodes[0].key, 'orders');
      expect(result.nodes[1].key, '[0] . item');
      expect(result.nodes[1].depth, 1);

      expect(result.nodes[2].key, 'sku');
      expect(result.nodes[2].depth, 2);
      expect(result.nodes[3].key, 'qty');
      expect(result.nodes[3].depth, 2);
    });

    test('omits null fields and counts them when hideNullFields is true', () {
      final json = {
        'id': '123',
        'closingTime': null,
        'depotName': null,
        'status': 'ACTIVE',
        'details': {
          'subField': 'value',
          'extra': null,
        }
      };

      final resultNoHide = JsonTreeFlattener.flatten(
        json,
        expandedPaths: {'root.details'},
        hideNullFields: false,
      );
      expect(resultNoHide.hiddenNullCount, 0);
      expect(resultNoHide.nodes.any((n) => n.key == 'closingTime'), isTrue);

      final resultHide = JsonTreeFlattener.flatten(
        json,
        expandedPaths: {'root.details'},
        hideNullFields: true,
      );
      expect(resultHide.hiddenNullCount, 3);
      expect(resultHide.nodes.any((n) => n.key == 'closingTime'), isFalse);
      expect(resultHide.nodes.any((n) => n.key == 'depotName'), isFalse);
      expect(resultHide.nodes.any((n) => n.key == 'extra'), isFalse);
      expect(resultHide.nodes.any((n) => n.key == 'id'), isTrue);
      expect(resultHide.nodes.any((n) => n.key == 'status'), isTrue);
      expect(resultHide.nodes.any((n) => n.key == 'subField'), isTrue);
    });

    test('automatically expands single-item arrays and maps by default unless list is compact badge', () {
      final json = {
        'complexArray': [
          {'subKey': 'val', 'otherKey': 'other'}
        ],
        'singleMap': {
          'nestedValue': 42,
        },
      };

      final result = JsonTreeFlattener.flatten(
        json,
        autoExpandSingleItemCollections: true,
      );

      // 'complexArray' has 1 complex item, so it should auto-expand and show '[0]'
      expect(result.nodes.any((n) => n.key == 'complexArray'), isTrue);
      expect(result.nodes.any((n) => n.key == '[0]'), isTrue);

      // 'singleMap' has 1 entry, so it should auto-expand and show 'nestedValue'
      expect(result.nodes.any((n) => n.key == 'singleMap'), isTrue);
      expect(result.nodes.any((n) => n.key == 'nestedValue'), isTrue);
    });

    test('renders compact 1-3 primitive item list as composite badge without expanding', () {
      final json = {
        'aktionsKategorien': ['ENTLADESTELLE'],
        'tags': ['A', 'B', 'C'],
      };

      final result = JsonTreeFlattener.flatten(
        json,
        autoExpandSingleItemCollections: true,
      );

      final aktionNode = result.nodes.firstWhere((n) => n.key == 'aktionsKategorien');
      expect(aktionNode.type, JsonNodeType.compositeBadge);
      expect(aktionNode.badgeData?.label, '[ "ENTLADESTELLE" ]');
      expect(result.nodes.any((n) => n.path.contains('aktionsKategorien[0]')), isFalse);

      final tagsNode = result.nodes.firstWhere((n) => n.key == 'tags');
      expect(tagsNode.type, JsonNodeType.compositeBadge);
      expect(tagsNode.badgeData?.label, '[ "A", "B", "C" ]');
      expect(result.nodes.any((n) => n.path.contains('tags[0]')), isFalse);
    });

    test('expands compact list into child nodes when path is in expandedPaths', () {
      final json = {
        'aktionsKategorien': ['ENTLADESTELLE'],
      };

      final result = JsonTreeFlattener.flatten(
        json,
        expandedPaths: {'root.aktionsKategorien'},
      );

      final aktionNode = result.nodes.firstWhere((n) => n.key == 'aktionsKategorien');
      expect(aktionNode.type, JsonNodeType.array);
      expect(aktionNode.isExpanded, isTrue);
      expect(result.nodes.any((n) => n.key == '[0]' && n.value == 'ENTLADESTELLE'), isTrue);
    });

    test('respects manuallyCollapsedPaths when autoExpandSingleItemCollections is true', () {
      final json = {
        'kundenauftragsIds': [
          {'id': '8bbe4ce1-50e5', 'deep': true}
        ],
      };

      final result = JsonTreeFlattener.flatten(
        json,
        manuallyCollapsedPaths: {'root.kundenauftragsIds'},
        autoExpandSingleItemCollections: true,
      );

      expect(result.nodes.any((n) => n.key == 'kundenauftragsIds'), isTrue);
      expect(result.nodes.any((n) => n.key == '[0]'), isFalse);
    });
  });
}
