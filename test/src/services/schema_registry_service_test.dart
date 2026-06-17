import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SchemaRegistryService', () {
    test('can be instantiated', () {
      final service = SchemaRegistryService();
      expect(service, isNotNull);
    });

    test('methods exist (methods cannot be called without backend)', () {
      final service = SchemaRegistryService();
      expect(service.fetchSubjects, isNotNull);
      expect(service.fetchSchema, isNotNull);
    });
  });
}
