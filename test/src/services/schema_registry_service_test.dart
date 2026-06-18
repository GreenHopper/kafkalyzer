import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../rust/api/rust_mocks.mocks.dart';

void main() {
  late MockRustLibApi mockApi;

  setUpAll(() {
    mockApi = MockRustLibApi();
    RustLib.initMock(api: mockApi);
  });

  tearDownAll(() {
    RustLib.dispose();
  });

  setUp(() {
    reset(mockApi);
  });

  const profile = ClusterProfile(
    name: 'test',
    bootstrapServers: 'localhost:9092',
  );

  group('SchemaRegistryService', () {
    test('fetchSubjects delegates to API', () async {
      final subjects = ['subject1', 'subject2'];
      when(
        mockApi.crateApiSchemaRegistryFetchSubjects(profile: profile),
      ).thenAnswer((_) async => subjects);

      final service = SchemaRegistryService();
      final result = await service.fetchSubjects(profile: profile);

      expect(result, subjects);
      verify(
        mockApi.crateApiSchemaRegistryFetchSubjects(profile: profile),
      ).called(1);
    });

    test('fetchSchema delegates to API', () async {
      const schema = '{"type": "string"}';
      when(
        mockApi.crateApiSchemaRegistryFetchSchema(
          profile: profile,
          subject: 'subject1',
        ),
      ).thenAnswer((_) async => schema);

      final service = SchemaRegistryService();
      final result = await service.fetchSchema(
        profile: profile,
        subject: 'subject1',
      );

      expect(result, schema);
      verify(
        mockApi.crateApiSchemaRegistryFetchSchema(
          profile: profile,
          subject: 'subject1',
        ),
      ).called(1);
    });
  });
}
