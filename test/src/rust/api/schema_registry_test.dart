import 'package:kafkalyzer/src/rust/api/schema_registry.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'rust_mocks.mocks.dart';

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

  group('SchemaRegistry', () {
    test('fetchSubjects calls bridge', () async {
      final subjects = ['subject1', 'subject2'];
      when(
        mockApi.crateApiSchemaRegistryFetchSubjects(profile: profile),
      ).thenAnswer((_) async => subjects);

      final result = await fetchSubjects(profile: profile);

      expect(result, subjects);
      verify(
        mockApi.crateApiSchemaRegistryFetchSubjects(profile: profile),
      ).called(1);
    });

    test('fetchSchema calls bridge', () async {
      const subject = 'test-subject';
      const schema = '{"type": "record"}';

      when(
        mockApi.crateApiSchemaRegistryFetchSchema(
          profile: profile,
          subject: subject,
        ),
      ).thenAnswer((_) async => schema);

      final result = await fetchSchema(profile: profile, subject: subject);

      expect(result, schema);
      verify(
        mockApi.crateApiSchemaRegistryFetchSchema(
          profile: profile,
          subject: subject,
        ),
      ).called(1);
    });
  });
}
