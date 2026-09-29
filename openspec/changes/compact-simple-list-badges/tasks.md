## 1. Entity Formatter Engine Extension

- [x] 1.1 Implement `EntityFormatterRegistry.tryFormatList()` to detect 1 to 3 non-empty primitive values (strings, numbers, booleans) within length thresholds and verify via unit tests in `test/src/ui/smart_tree/entity_formatter_registry_test.dart`

## 2. Popover Support for List Entities

- [x] 2.1 Update `SmartCompositeBadge` to support `List` payloads alongside `Map` payloads (popover rendering with indexed rows, copy action for array JSON) and verify via widget tests in `test/src/ui/smart_tree/smart_virtual_json_tree_test.dart`

## 3. Tree Flattener Integration

- [x] 3.1 Integrate `tryFormatList()` into `JsonTreeFlattener.traverse()` for `List` values, preventing single-item auto-expansion when eligible for compact list badge formatting and emitting `JsonNodeType.compositeBadge` when collapsed; verify via flattener tests in `test/src/ui/smart_tree/json_tree_flattener_test.dart`
- [ ] 3.2 Ensure search matching and highlighting operate correctly on compact list badges and verify via search tests in `test/src/ui/smart_tree/smart_virtual_json_tree_test.dart`

## 4. Verification & Static Analysis

- [ ] 4.1 Run `flutter test` across all smart tree and viewer tests to verify full regression-free functionality
- [ ] 4.2 Run `dart analyze` to ensure zero warnings or errors
