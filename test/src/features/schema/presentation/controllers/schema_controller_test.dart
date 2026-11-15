import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;
import 'package:kafkalyzer/src/services/local_schema_assignment_service.dart';
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
    tlsVerification: TlsVerification.enabled,
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

    test(
      'fetchSchemaFields returns Protobuf & JSON Schema paths and caches success',
      () async {
        const protoView = api.SubjectSchemaViewDto(
          schema: api.SubjectSchemaDto(
            subject: 'orders-value',
            version: 1,
            id: 1,
            schemaType: api.SchemaKindDto.protobuf,
            schema: 'syntax = "proto3"; message Order { string id = 1; }',
            references: [],
          ),
          fields: api.SchemaFieldModelDto(
            kind: api.SchemaKindDto.protobuf,
            messages: ['Order'],
            fields: [
              api.SchemaFieldEntryDto(
                path: 'id',
                name: 'id',
                depth: 0,
                typeLabel: 'string',
                optional: false,
                repeated: false,
              ),
              api.SchemaFieldEntryDto(
                path: 'customer.name',
                name: 'name',
                depth: 1,
                typeLabel: 'string',
                optional: false,
                repeated: false,
              ),
            ],
            truncated: false,
          ),
        );
        when(
          mockService.fetchSubjectSchemaView(
            profile: testProfile,
            subject: 'orders-value',
          ),
        ).thenAnswer((_) async => protoView);

        final protoFields = await controller.fetchSchemaFields(
          testProfile,
          'orders',
        );
        expect(protoFields, ['id', 'customer.name']);

        // Subsequent call hits cache.
        await controller.fetchSchemaFields(testProfile, 'orders');
        verify(
          mockService.fetchSubjectSchemaView(
            profile: testProfile,
            subject: 'orders-value',
          ),
        ).called(1);

        const jsonView = api.SubjectSchemaViewDto(
          schema: api.SubjectSchemaDto(
            subject: 'events-value',
            version: 1,
            id: 2,
            schemaType: api.SchemaKindDto.json,
            schema: '{"type":"object"}',
            references: [],
          ),
          fields: api.SchemaFieldModelDto(
            kind: api.SchemaKindDto.json,
            messages: [],
            fields: [
              api.SchemaFieldEntryDto(
                path: 'eventId',
                name: 'eventId',
                depth: 0,
                typeLabel: 'string',
                optional: false,
                repeated: false,
              ),
            ],
            truncated: false,
          ),
        );
        when(
          mockService.fetchSubjectSchemaView(
            profile: testProfile,
            subject: 'events-value',
          ),
        ).thenAnswer((_) async => jsonView);

        final jsonFields = await controller.fetchSchemaFields(
          testProfile,
          'events',
        );
        expect(jsonFields, ['eventId']);
      },
    );

    test(
      'fetchSchemaFields returns [] on failure without caching the failure',
      () async {
        when(
          mockService.fetchSubjectSchemaView(
            profile: testProfile,
            subject: 'broken-value',
          ),
        ).thenThrow(Exception('timeout'));

        final first = await controller.fetchSchemaFields(testProfile, 'broken');
        expect(first, isEmpty);

        final second = await controller.fetchSchemaFields(
          testProfile,
          'broken',
        );
        expect(second, isEmpty);

        verify(
          mockService.fetchSubjectSchemaView(
            profile: testProfile,
            subject: 'broken-value',
          ),
        ).called(2);
      },
    );

    test('schemaTypeFor transitions notLoaded -> failed -> known', () async {
      expect(
        controller.schemaTypeFor(testProfile, 'orders-value'),
        const SchemaTypeNotLoaded(),
      );

      when(
        mockService.fetchSubjectSchemaView(
          profile: testProfile,
          subject: 'orders-value',
        ),
      ).thenThrow(Exception('network'));

      await expectLater(
        controller.fetchSubjectSchemaView(testProfile, 'orders-value'),
        throwsException,
      );
      expect(
        controller.schemaTypeFor(testProfile, 'orders-value'),
        const SchemaTypeFailed(),
      );

      when(
        mockService.fetchSubjectSchemaView(
          profile: testProfile,
          subject: 'orders-value',
        ),
      ).thenAnswer(
        (_) async => const api.SubjectSchemaViewDto(
          schema: api.SubjectSchemaDto(
            subject: 'orders-value',
            version: 1,
            id: 1,
            schemaType: api.SchemaKindDto.protobuf,
            schema: '',
            references: [],
          ),
          fields: api.SchemaFieldModelDto(
            kind: api.SchemaKindDto.protobuf,
            messages: [],
            fields: [],
            truncated: false,
          ),
        ),
      );

      await controller.fetchSubjectSchemaView(testProfile, 'orders-value');
      expect(
        controller.schemaTypeFor(testProfile, 'orders-value'),
        const SchemaTypeKnown(api.SchemaKindDto.protobuf),
      );
    });

    test(
      'associatedTopics memoises until subject or topic list changes',
      () async {
        when(
          mockService.fetchSubjects(profile: testProfile),
        ).thenAnswer((_) async => ['orders-value']);
        await controller.fetchSchemas(testProfile);

        const assoc1 = [
          api.SubjectAssociationDto(
            subject: 'orders-value',
            topic: 'orders',
            side: api.TopicSideDto.value,
            onCluster: true,
          ),
        ];
        when(
          mockService.associateSubjects(
            subjects: ['orders-value'],
            topics: ['orders'],
          ),
        ).thenReturn(assoc1);

        expect(controller.associatedTopics(testProfile, ['orders']), assoc1);
        expect(controller.associatedTopics(testProfile, ['orders']), assoc1);
        verify(
          mockService.associateSubjects(
            subjects: ['orders-value'],
            topics: ['orders'],
          ),
        ).called(1);

        // Changing topic list triggers recomputation.
        when(
          mockService.associateSubjects(
            subjects: ['orders-value'],
            topics: ['orders', 'payments'],
          ),
        ).thenReturn(assoc1);
        controller.associatedTopics(testProfile, ['orders', 'payments']);
        verify(
          mockService.associateSubjects(
            subjects: ['orders-value'],
            topics: ['orders', 'payments'],
          ),
        ).called(1);

        // Changing subject list triggers recomputation.
        when(
          mockService.fetchSubjects(profile: testProfile),
        ).thenAnswer((_) async => ['orders-value', 'payments-value']);
        await controller.fetchSchemas(testProfile, force: true);
        when(
          mockService.associateSubjects(
            subjects: ['orders-value', 'payments-value'],
            topics: ['orders', 'payments'],
          ),
        ).thenReturn(assoc1);
        controller.associatedTopics(testProfile, ['orders', 'payments']);
        verify(
          mockService.associateSubjects(
            subjects: ['orders-value', 'payments-value'],
            topics: ['orders', 'payments'],
          ),
        ).called(1);
      },
    );

    test('compatibility getters cache successful responses', () async {
      when(
        mockService.fetchGlobalCompatibility(profile: testProfile),
      ).thenAnswer((_) async => 'BACKWARD');
      when(
        mockService.fetchSubjectCompatibility(
          profile: testProfile,
          subject: 'orders-value',
        ),
      ).thenAnswer((_) async => null);

      expect(controller.globalCompatibilityFor(testProfile), isNull);
      expect(
        await controller.fetchGlobalCompatibility(testProfile),
        'BACKWARD',
      );
      expect(controller.globalCompatibilityFor(testProfile), 'BACKWARD');

      expect(
        controller.hasSubjectCompatibility(testProfile, 'orders-value'),
        isFalse,
      );
      expect(
        await controller.fetchSubjectCompatibility(testProfile, 'orders-value'),
        isNull,
      );
      expect(
        controller.hasSubjectCompatibility(testProfile, 'orders-value'),
        isTrue,
      );
      expect(
        controller.subjectCompatibilityFor(testProfile, 'orders-value'),
        isNull,
      );
    });

    test('checkCompatibility delegates to service', () async {
      const compat = api.SchemaCompatibilityResult(
        isCompatible: true,
        messages: [],
      );
      when(
        mockService.checkSchemaCompatibility(
          profile: testProfile,
          subject: 'topic-value',
          schema: '{}',
        ),
      ).thenAnswer((_) async => compat);

      final result = await controller.checkCompatibility(
        testProfile,
        'topic-value',
        schema: '{}',
      );

      expect(result.isCompatible, isTrue);
      verify(
        mockService.checkSchemaCompatibility(
          profile: testProfile,
          subject: 'topic-value',
          schema: '{}',
        ),
      ).called(1);
    });

    test('getAssociatedTopics delegates to service', () async {
      when(
        mockService.resolveAssociatedTopics(
          subject: 'topic-value',
          availableTopics: ['topic'],
        ),
      ).thenAnswer((_) async => ['topic']);

      final result = await controller.getAssociatedTopics('topic-value', [
        'topic',
      ]);

      expect(result, ['topic']);
      verify(
        mockService.resolveAssociatedTopics(
          subject: 'topic-value',
          availableTopics: ['topic'],
        ),
      ).called(1);
    });

    test(
      'failing fetchSubjects exposes errorFor and later success clears it',
      () async {
        when(
          mockService.fetchSubjects(profile: testProfile),
        ).thenThrow(Exception('Registry 503'));

        await controller.fetchSchemas(testProfile);

        expect(controller.getSchemas(testProfile), isNull);
        expect(controller.errorFor(testProfile), contains('Registry 503'));

        when(
          mockService.fetchSubjects(profile: testProfile),
        ).thenAnswer((_) async => ['orders-value']);
        await controller.fetchSchemas(testProfile, force: true);

        expect(controller.errorFor(testProfile), isNull);
        expect(controller.getSchemas(testProfile), ['orders-value']);
      },
    );

    test(
      'profile without schemaRegistryUrl caches [] with no error and no service call',
      () async {
        const noRegistryProfile = ClusterProfile(
          name: 'no-sr',
          bootstrapServers: 'localhost:9092',
          schemaRegistryUrl: '   ',
          tlsVerification: TlsVerification.enabled,
        );

        await controller.fetchSchemas(noRegistryProfile);

        expect(controller.getSchemas(noRegistryProfile), isEmpty);
        expect(controller.errorFor(noRegistryProfile), isNull);
        verifyNever(mockService.fetchSubjects(profile: anyNamed('profile')));
      },
    );

    group('fetchSchemaFields with local schema assignments', () {
      const localAssignmentFallback = LocalSchemaAssignmentDto(
        path: '/tmp/orders.proto',
        format: LocalSchemaFormatDto.protobufSource,
        messageType: 'Order',
        framing: FramingDto.auto,
        mode: LocalSchemaModeDto.fallback,
        expectedSha256: 'abc',
      );
      const localAssignmentAlways = LocalSchemaAssignmentDto(
        path: '/tmp/orders.proto',
        format: LocalSchemaFormatDto.protobufSource,
        messageType: 'Order',
        framing: FramingDto.auto,
        mode: LocalSchemaModeDto.always,
        expectedSha256: 'abc',
      );
      const localProtoInfo = LocalSchemaInfo(
        fileName: 'orders.proto',
        detectedFormat: LocalSchemaFormatDto.protobufSource,
        messageTypes: ['Order'],
        selectedMessage: 'Order',
        fields: api.SchemaFieldModelDto(
          kind: api.SchemaKindDto.protobuf,
          messages: ['Order'],
          fields: [
            api.SchemaFieldEntryDto(
              path: 'local_id',
              name: 'local_id',
              depth: 0,
              typeLabel: 'string',
              optional: false,
              repeated: false,
            ),
            api.SchemaFieldEntryDto(
              path: 'amount',
              name: 'amount',
              depth: 0,
              typeLabel: 'int32',
              optional: false,
              repeated: false,
            ),
          ],
          truncated: false,
        ),
        sha256Hex: 'abc',
      );

      test(
        'returns local Protobuf fields when cluster has no Schema Registry',
        () async {
          const noRegistryProfile = ClusterProfile(
            name: 'no-sr',
            bootstrapServers: 'localhost:9092',
            tlsVerification: TlsVerification.enabled,
          );
          final fakeLocal = _FakeLocalSchemaAssignmentService(
            stored: const StoredTopicLocalSchemas(
              value: localAssignmentFallback,
            ),
            stateResult: const LocalSchemaStateResult(
              state: LocalSchemaAssignmentState.usable,
              info: localProtoInfo,
            ),
          );
          final localController = SchemaController(
            registryService: mockService,
            localSchemaService: fakeLocal,
          );

          final fields = await localController.fetchSchemaFields(
            noRegistryProfile,
            'orders',
          );

          expect(fields, ['local_id', 'amount']);
          verifyNever(
            mockService.fetchSubjectSchemaView(
              profile: anyNamed('profile'),
              subject: anyNamed('subject'),
              version: anyNamed('version'),
            ),
          );
        },
      );

      test('Always mode uses local fields and skips registry lookup', () async {
        final fakeLocal = _FakeLocalSchemaAssignmentService(
          stored: const StoredTopicLocalSchemas(value: localAssignmentAlways),
          stateResult: const LocalSchemaStateResult(
            state: LocalSchemaAssignmentState.usable,
            info: localProtoInfo,
          ),
        );
        final localController = SchemaController(
          registryService: mockService,
          localSchemaService: fakeLocal,
        );

        final fields = await localController.fetchSchemaFields(
          testProfile,
          'orders',
        );

        expect(fields, ['local_id', 'amount']);
        verifyNever(
          mockService.fetchSubjectSchemaView(
            profile: anyNamed('profile'),
            subject: anyNamed('subject'),
            version: anyNamed('version'),
          ),
        );
      });

      test(
        'Fallback mode prefers registry fields when registry succeeds',
        () async {
          const registryView = api.SubjectSchemaViewDto(
            schema: api.SubjectSchemaDto(
              subject: 'orders-value',
              version: 1,
              id: 1,
              schemaType: api.SchemaKindDto.avro,
              schema: '{"type":"record","name":"Order","fields":[]}',
              references: [],
            ),
            fields: api.SchemaFieldModelDto(
              kind: api.SchemaKindDto.avro,
              messages: [],
              fields: [
                api.SchemaFieldEntryDto(
                  path: 'registry_id',
                  name: 'registry_id',
                  depth: 0,
                  typeLabel: 'string',
                  optional: false,
                  repeated: false,
                ),
              ],
              truncated: false,
            ),
          );
          when(
            mockService.fetchSubjectSchemaView(
              profile: testProfile,
              subject: 'orders-value',
            ),
          ).thenAnswer((_) async => registryView);

          final fakeLocal = _FakeLocalSchemaAssignmentService(
            stored: const StoredTopicLocalSchemas(
              value: localAssignmentFallback,
            ),
            stateResult: const LocalSchemaStateResult(
              state: LocalSchemaAssignmentState.usable,
              info: localProtoInfo,
            ),
          );
          final localController = SchemaController(
            registryService: mockService,
            localSchemaService: fakeLocal,
          );

          final fields = await localController.fetchSchemaFields(
            testProfile,
            'orders',
          );

          expect(fields, ['registry_id']);
          expect(fakeLocal.stateForCalls, 0);
        },
      );

      test(
        'Fallback mode falls back to local fields when registry fails',
        () async {
          when(
            mockService.fetchSubjectSchemaView(
              profile: testProfile,
              subject: 'orders-value',
            ),
          ).thenThrow(Exception('404 Not Found'));

          final fakeLocal = _FakeLocalSchemaAssignmentService(
            stored: const StoredTopicLocalSchemas(
              value: localAssignmentFallback,
            ),
            stateResult: const LocalSchemaStateResult(
              state: LocalSchemaAssignmentState.usable,
              info: localProtoInfo,
            ),
          );
          final localController = SchemaController(
            registryService: mockService,
            localSchemaService: fakeLocal,
          );

          final fields = await localController.fetchSchemaFields(
            testProfile,
            'orders',
          );

          expect(fields, ['local_id', 'amount']);
        },
      );
    });
  });
}

class _FakeLocalSchemaAssignmentService extends ChangeNotifier
    implements LocalSchemaAssignmentService {
  final StoredTopicLocalSchemas stored;
  final LocalSchemaStateResult stateResult;
  int stateForCalls = 0;

  _FakeLocalSchemaAssignmentService({
    required this.stored,
    required this.stateResult,
  });

  @override
  Future<StoredTopicLocalSchemas> getForTopic(
    String clusterId,
    String topic,
  ) async => stored;

  @override
  Future<LocalSchemaStateResult> stateFor(
    String clusterId,
    String topic,
    LocalSchemaSide side, {
    bool refresh = false,
  }) async {
    stateForCalls++;
    return stateResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
