import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([SchemaRegistryService])
import 'schema_controller_test.mocks.dart';

void main() {
  late SchemaController controller;
  late MockSchemaRegistryService mockService;

  final testProfile = ClusterProfile(
    name: 'test-cluster',
    bootstrapServers: 'localhost:9092',
    schemaRegistryUrl: 'http://localhost:8081',
    securityProtocol: 'plaintext',
    mechanism: 'plain',
  );

  setUp(() {
    mockService = MockSchemaRegistryService();
    controller = SchemaController(registryService: mockService);
  });

  group('SchemaController', () {
    test('initial state is empty', () {
      expect(controller.getSchemas(testProfile), isNull);
      expect(controller.isLoading(testProfile), isFalse);
    });

    test('fetchSchemas updates state and calls service', () async {
      when(
        mockService.fetchSubjects(profile: testProfile),
      ).thenAnswer((_) async => ['topic-key', 'topic-value']);

      final future = controller.fetchSchemas(testProfile);
      expect(controller.isLoading(testProfile), isTrue); // Loading state

      await future;

      expect(controller.isLoading(testProfile), isFalse);
      expect(controller.getSchemas(testProfile), ['topic-key', 'topic-value']);
      verify(mockService.fetchSubjects(profile: testProfile)).called(1);
    });

    test('fetchSchemas handles error gracefully', () async {
      when(
        mockService.fetchSubjects(profile: testProfile),
      ).thenThrow(Exception('Backend Error'));

      await controller.fetchSchemas(testProfile);

      expect(controller.isLoading(testProfile), isFalse);
      expect(controller.getSchemas(testProfile), isNull); // Failing gracefully
    });

    test('fetchSchemaFields parses JSON and caches result', () async {
      final jsonSchema = '{"fields": [{"name": "field1"}, {"name": "field2"}]}';
      when(
        mockService.fetchSchema(profile: testProfile, subject: 'topic-value'),
      ).thenAnswer((_) async => jsonSchema);

      final fields = await controller.fetchSchemaFields(testProfile, 'topic');

      expect(fields, ['field1', 'field2']);
      verify(
        mockService.fetchSchema(profile: testProfile, subject: 'topic-value'),
      ).called(1);

      // Subsequent call should hit cache
      await controller.fetchSchemaFields(testProfile, 'topic');
      verifyNever(
        mockService.fetchSchema(profile: testProfile, subject: 'topic-value'),
      ); // Not called again
    });

    test('parseSchemaFields returns empty list on invalid json', () {
      expect(controller.parseSchemaFields('invalid json'), isEmpty);
      expect(controller.parseSchemaFields('{}'), isEmpty); // No fields key
    });
  });
}
