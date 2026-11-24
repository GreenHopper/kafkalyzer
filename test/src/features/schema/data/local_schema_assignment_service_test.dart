import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:kafkalyzer/src/features/schema/data/local_schema_assignment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const sampleAvro = LocalSchemaAssignmentDto(
    path: '/schemas/orders.avsc',
    format: LocalSchemaFormatDto.avro,
    framing: FramingDto.auto,
    mode: LocalSchemaModeDto.fallback,
    expectedSha256: 'abc123',
  );

  test('round trip, cluster isolation, and restart persistence', () async {
    final prefs = await SharedPreferences.getInstance();
    final service1 = LocalSchemaAssignmentService(prefs: prefs);

    await service1.saveSide(
      'prod',
      'orders',
      LocalSchemaSide.value,
      sampleAvro,
    );

    final loaded = await service1.getForTopic('prod', 'orders');
    expect(loaded.unreadable, isFalse);
    expect(loaded.key, isNull);
    expect(loaded.value, equals(sampleAvro));

    // Cluster isolation: same topic on test has no assignment
    final testCluster = await service1.getForTopic('test', 'orders');
    expect(testCluster.hasAny, isFalse);
    expect(await service1.scanOptionsFor('test', 'orders'), isNull);

    // Restart: new service instance on same SharedPreferences
    final service2 = LocalSchemaAssignmentService(prefs: prefs);
    final afterRestart = await service2.scanOptionsFor('prod', 'orders');
    expect(afterRestart?.value, equals(sampleAvro));
    expect(afterRestart?.key, isNull);

    // Remove
    await service2.removeSide('prod', 'orders', LocalSchemaSide.value);
    expect((await service2.getForTopic('prod', 'orders')).hasAny, isFalse);
  });

  test(
    'unreadable stored data is reported and kept after an unrelated save',
    () async {
      const badRaw = '{not valid json';
      SharedPreferences.setMockInitialValues({
        LocalSchemaAssignmentService.storageKey('prod', 'broken'): badRaw,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = LocalSchemaAssignmentService(prefs: prefs);

      final broken = await service.getForTopic('prod', 'broken');
      expect(broken.unreadable, isTrue);
      expect(await service.scanOptionsFor('prod', 'broken'), isNull);

      // Unrelated save on another topic keeps unreadable data intact
      await service.saveSide(
        'prod',
        'other',
        LocalSchemaSide.value,
        sampleAvro,
      );
      expect(
        prefs.getString(
          LocalSchemaAssignmentService.storageKey('prod', 'broken'),
        ),
        equals(badRaw),
      );
    },
  );

  test(
    'stateFor classifies usable, changed, confirmChanged, every error, and unknown',
    () async {
      final prefs = await SharedPreferences.getInstance();
      LocalSchemaInfo nextInfo = const LocalSchemaInfo(
        fileName: 'orders.avsc',
        detectedFormat: LocalSchemaFormatDto.avro,
        sha256Hex: 'abc123',
        messageTypes: [],
      );
      var throwOnInspect = false;
      var inspectCalls = 0;

      final service = LocalSchemaAssignmentService(
        prefs: prefs,
        inspectFn: ({required path, format, messageType}) async {
          inspectCalls++;
          if (throwOnInspect) throw StateError('bridge down');
          return nextInfo;
        },
      );

      await service.saveSide(
        'prod',
        'orders',
        LocalSchemaSide.value,
        sampleAvro,
      );

      // Usable & cached
      final s1 = await service.stateFor(
        'prod',
        'orders',
        LocalSchemaSide.value,
      );
      expect(s1.state, LocalSchemaAssignmentState.usable);
      final s1Cached = await service.stateFor(
        'prod',
        'orders',
        LocalSchemaSide.value,
      );
      expect(s1Cached.state, LocalSchemaAssignmentState.usable);
      expect(inspectCalls, 1);

      // Changed + confirmChanged
      nextInfo = const LocalSchemaInfo(
        fileName: 'orders.avsc',
        detectedFormat: LocalSchemaFormatDto.avro,
        sha256Hex: 'newsha999',
        messageTypes: [],
      );
      final changed = await service.stateFor(
        'prod',
        'orders',
        LocalSchemaSide.value,
        refresh: true,
      );
      expect(changed.state, LocalSchemaAssignmentState.changed);

      await service.confirmChanged('prod', 'orders', LocalSchemaSide.value);
      final afterConfirm = await service.stateFor(
        'prod',
        'orders',
        LocalSchemaSide.value,
      );
      expect(afterConfirm.state, LocalSchemaAssignmentState.usable);
      final stored = await service.getForTopic('prod', 'orders');
      expect(stored.value?.expectedSha256, 'newsha999');

      // Error states
      for (final entry in {
        LocalDecodeErrorKindDto.fileNotFound:
            LocalSchemaAssignmentState.fileNotFound,
        LocalDecodeErrorKindDto.fileUnreadable:
            LocalSchemaAssignmentState.fileUnreadable,
        LocalDecodeErrorKindDto.fileTooLarge:
            LocalSchemaAssignmentState.fileUnreadable,
        LocalDecodeErrorKindDto.schemaInvalid:
            LocalSchemaAssignmentState.schemaInvalid,
        LocalDecodeErrorKindDto.unsupportedProto2:
            LocalSchemaAssignmentState.schemaInvalid,
        LocalDecodeErrorKindDto.unresolvedImport:
            LocalSchemaAssignmentState.schemaInvalid,
        LocalDecodeErrorKindDto.messageTypeNotFound:
            LocalSchemaAssignmentState.messageTypeMissing,
      }.entries) {
        nextInfo = LocalSchemaInfo(
          fileName: 'orders.avsc',
          messageTypes: const [],
          error: LocalSchemaErrorDto(kind: entry.key, detail: 'detail'),
        );
        final res = await service.stateFor(
          'prod',
          'orders',
          LocalSchemaSide.value,
          refresh: true,
        );
        expect(res.state, entry.value);
      }

      // Unknown when inspect throws
      throwOnInspect = true;
      final unknownRes = await service.stateFor(
        'prod',
        'orders',
        LocalSchemaSide.value,
        refresh: true,
      );
      expect(unknownRes.state, LocalSchemaAssignmentState.unknown);
    },
  );
}
