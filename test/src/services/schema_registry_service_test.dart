import 'package:kafkalyzer/l10n/app_localizations_de.dart';
import 'package:kafkalyzer/l10n/app_localizations_en.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../rust/api/rust_mocks.mocks.dart';

void main() {
  late MockKafkalyzerRustLibApi mockApi;

  setUpAll(() {
    mockApi = MockKafkalyzerRustLibApi();
    KafkalyzerRustLib.initMock(api: mockApi);
  });

  tearDownAll(() {
    KafkalyzerRustLib.dispose();
  });

  setUp(() {
    reset(mockApi);
  });

  const profile = ClusterProfile(
    name: 'test',
    bootstrapServers: 'localhost:9092',
    tlsVerification: TlsVerification.enabled,
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

    test('checkSchemaCompatibility delegates to API', () async {
      const compat = api.SchemaCompatibilityResult(
        isCompatible: true,
        messages: [],
      );
      when(
        mockApi.crateApiSchemaRegistryCheckSchemaCompatibility(
          profile: profile,
          subject: 'orders-value',
          schema: '{}',
        ),
      ).thenAnswer((_) async => compat);

      final service = SchemaRegistryService();
      final result = await service.checkSchemaCompatibility(
        profile: profile,
        subject: 'orders-value',
        schema: '{}',
      );

      expect(result.isCompatible, isTrue);
      expect(result.messages, isEmpty);
    });

    test('resolveAssociatedTopics delegates to API', () async {
      when(
        mockApi.crateApiSchemaRegistryResolveAssociatedTopicsForSubject(
          subject: 'orders-value',
          availableTopics: ['orders'],
        ),
      ).thenAnswer((_) async => ['orders']);

      final service = SchemaRegistryService();
      final result = await service.resolveAssociatedTopics(
        subject: 'orders-value',
        availableTopics: ['orders'],
      );

      expect(result, ['orders']);
    });

    test('fetchSubjectSchemaView delegates to API', () async {
      const view = api.SubjectSchemaViewDto(
        schema: api.SubjectSchemaDto(
          subject: 'orders-value',
          version: 1,
          id: 42,
          schemaType: api.SchemaKindDto.protobuf,
          schema: 'syntax = "proto3"; message Order {}',
          references: [],
        ),
        fields: api.SchemaFieldModelDto(
          kind: api.SchemaKindDto.protobuf,
          messages: ['Order'],
          fields: [],
          truncated: false,
        ),
      );
      when(
        mockApi.crateApiSchemaRegistryFetchSubjectSchemaView(
          profile: profile,
          subject: 'orders-value',
          version: 1,
        ),
      ).thenAnswer((_) async => view);

      final service = SchemaRegistryService();
      final result = await service.fetchSubjectSchemaView(
        profile: profile,
        subject: 'orders-value',
        version: 1,
      );

      expect(result, view);
      verify(
        mockApi.crateApiSchemaRegistryFetchSubjectSchemaView(
          profile: profile,
          subject: 'orders-value',
          version: 1,
        ),
      ).called(1);
    });

    test('fetchGlobalCompatibility delegates to API', () async {
      when(
        mockApi.crateApiSchemaRegistryFetchGlobalCompatibility(
          profile: profile,
        ),
      ).thenAnswer((_) async => 'BACKWARD');

      final service = SchemaRegistryService();
      final result = await service.fetchGlobalCompatibility(profile: profile);

      expect(result, 'BACKWARD');
    });

    test('fetchSubjectCompatibility delegates to API', () async {
      when(
        mockApi.crateApiSchemaRegistryFetchSubjectCompatibility(
          profile: profile,
          subject: 'orders-value',
        ),
      ).thenAnswer((_) async => null);

      final service = SchemaRegistryService();
      final result = await service.fetchSubjectCompatibility(
        profile: profile,
        subject: 'orders-value',
      );

      expect(result, isNull);
    });

    test('associateSubjects delegates to API', () {
      const associations = [
        api.SubjectAssociationDto(
          subject: 'orders-value',
          topic: 'orders',
          side: api.TopicSideDto.value,
          onCluster: true,
        ),
      ];
      when(
        mockApi.crateApiSchemaRegistryAssociateSubjects(
          subjects: ['orders-value'],
          topics: ['orders'],
        ),
      ).thenReturn(associations);

      final service = SchemaRegistryService();
      final result = service.associateSubjects(
        subjects: ['orders-value'],
        topics: ['orders'],
      );

      expect(result, associations);
    });
  });

  group('describeSchemaRegistryError', () {
    final en = AppLocalizationsEn();
    final de = AppLocalizationsDe();

    test('maps every SchemaRegistryErrorKindDto in EN and DE', () {
      for (final kind in api.SchemaRegistryErrorKindDto.values) {
        final dto = api.SchemaRegistryErrorDto(
          kind: kind,
          status: kind == api.SchemaRegistryErrorKindDto.httpStatus
              ? 502
              : null,
          detail: 'detail text',
        );
        final enMsg = describeSchemaRegistryError(en, dto);
        final deMsg = describeSchemaRegistryError(de, dto);
        expect(enMsg, isNotEmpty, reason: 'EN empty for $kind');
        expect(deMsg, isNotEmpty, reason: 'DE empty for $kind');
        expect(enMsg, isNot(equals(deMsg)), reason: 'EN == DE for $kind');
      }
    });

    test('handles httpStatus with null status and non-DTO fallback', () {
      const noStatus = api.SchemaRegistryErrorDto(
        kind: api.SchemaRegistryErrorKindDto.httpStatus,
        detail: 'unexpected',
      );
      expect(describeSchemaRegistryError(en, noStatus), contains('unexpected'));
      expect(describeSchemaRegistryError(de, noStatus), contains('unexpected'));

      expect(
        describeSchemaRegistryError(en, Exception('boom')),
        contains('boom'),
      );
    });
  });
}
