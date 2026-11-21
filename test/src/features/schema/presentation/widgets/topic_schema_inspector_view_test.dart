import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/schema_viewer_dialog.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;
import 'package:kafkalyzer/src/services/file_opener_service.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FailingSchemaRegistryService extends SchemaRegistryService {
  final Object error;
  _FailingSchemaRegistryService([Object? error])
    : error = error ?? StateError('Registry unreachable');

  @override
  Future<List<String>> fetchSubjects({required ClusterProfile profile}) async {
    throw error;
  }
}

class _FakeSchemaRegistryService extends SchemaRegistryService {
  final Map<String, List<String>> subjectsByCluster;
  final Map<(String, int?), api.SubjectSchemaViewDto> views;
  final Map<String, List<int>> versionsBySubject;
  final Object? globalCompatibilityResult;
  final Map<String, Object?> subjectCompatibilityResult;

  _FakeSchemaRegistryService({
    this.subjectsByCluster = const {},
    this.views = const {},
    this.versionsBySubject = const {},
    this.globalCompatibilityResult = 'BACKWARD',
    this.subjectCompatibilityResult = const {},
  });

  @override
  Future<List<String>> fetchSubjects({required ClusterProfile profile}) async {
    return subjectsByCluster[profile.name] ?? const [];
  }

  @override
  Future<List<int>> fetchSchemaVersions({
    required ClusterProfile profile,
    required String subject,
  }) async {
    return versionsBySubject[subject] ?? const [1];
  }

  @override
  Future<api.SubjectSchemaViewDto> fetchSubjectSchemaView({
    required ClusterProfile profile,
    required String subject,
    int? version,
  }) async {
    final exact = views[(subject, version)];
    if (exact != null) return exact;
    final latest = views[(subject, null)];
    if (latest != null) return latest;
    throw StateError('Missing view for $subject v$version');
  }

  @override
  Future<String> fetchGlobalCompatibility({
    required ClusterProfile profile,
  }) async {
    final res = globalCompatibilityResult;
    if (res is Exception || res is Error || res is api.SchemaRegistryErrorDto) {
      throw res!;
    }
    return res as String;
  }

  @override
  Future<String?> fetchSubjectCompatibility({
    required ClusterProfile profile,
    required String subject,
  }) async {
    if (!subjectCompatibilityResult.containsKey(subject)) {
      return null;
    }
    final res = subjectCompatibilityResult[subject];
    if (res is Exception || res is Error || res is api.SchemaRegistryErrorDto) {
      throw res!;
    }
    return res as String?;
  }
}

class _FakeFilePicker extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  String? nextSavePath;
  String? lastSuggestedFileName;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    lastSuggestedFileName = fileName;
    return nextSavePath;
  }
}

class _FakeFileOpenerService extends FileOpenerService {
  @override
  Future<bool> openFile(String path) async => true;
}

const _profile = ClusterProfile(
  name: 'prod',
  bootstrapServers: 'b:9092',
  schemaRegistryUrl: 'https://sr.internal:8081',
  tlsVerification: TlsVerification.enabled,
);

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  late FilePickerPlatform originalPicker;

  setUp(() {
    originalPicker = FilePickerPlatform.instance;
    if (!getIt.isRegistered<Logger>()) {
      getIt.registerSingleton<Logger>(Logger());
    }
    if (!getIt.isRegistered<FileOpenerService>()) {
      getIt.registerSingleton<FileOpenerService>(_FakeFileOpenerService());
    }
  });

  tearDown(() {
    FilePickerPlatform.instance = originalPicker;
  });

  testWidgets(
    'TopicSchemaInspectorView shows error state when fetchSchemas fails',
    (tester) async {
      final controller = SchemaController(
        registryService: _FailingSchemaRegistryService(),
      );

      await tester.pumpWidget(
        _wrap(
          TopicSchemaInspectorView(
            profile: _profile,
            topicName: 'orders',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Registry unreachable'), findsOneWidget);
    },
  );

  testWidgets(
    '401 error shows credentials message and not empty schema state',
    (tester) async {
      const err = api.SchemaRegistryErrorDto(
        kind: api.SchemaRegistryErrorKindDto.unauthorized,
        status: 401,
        detail: 'HTTP 401',
      );
      final controller = SchemaController(
        registryService: _FailingSchemaRegistryService(err),
      );

      await tester.pumpWidget(
        _wrap(
          TopicSchemaInspectorView(
            profile: _profile,
            topicName: 'orders',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('username and password'), findsOneWidget);
      expect(find.textContaining('No schema found'), findsNothing);
    },
  );

  testWidgets('JSON Schema topic shows customer -> name, not object', (
    tester,
  ) async {
    const jsonView = api.SubjectSchemaViewDto(
      schema: api.SubjectSchemaDto(
        subject: 'orders-value',
        version: 2,
        id: 101,
        schemaType: api.SchemaKindDto.json,
        schema: '{"type":"object","properties":{"customer":{"type":"object"}}}',
        references: [],
      ),
      fields: api.SchemaFieldModelDto(
        kind: api.SchemaKindDto.json,
        messages: [],
        fields: [
          api.SchemaFieldEntryDto(
            path: 'customer',
            name: 'customer',
            depth: 0,
            typeLabel: 'object',
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
    final controller = SchemaController(
      registryService: _FakeSchemaRegistryService(
        subjectsByCluster: const {
          'prod': ['orders-value'],
        },
        views: const {('orders-value', null): jsonView},
      ),
    );

    await tester.pumpWidget(
      _wrap(
        TopicSchemaInspectorView(
          profile: _profile,
          topicName: 'orders',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('JSON Schema'), findsWidgets);
    expect(find.textContaining('customer'), findsWidgets);
    expect(find.textContaining('name'), findsWidgets);
  });

  testWidgets(
    'Protobuf topic shows repeated marker, messages list, and pin/filter yields customer.name',
    (tester) async {
      const protoView = api.SubjectSchemaViewDto(
        schema: api.SubjectSchemaDto(
          subject: 'orders-value',
          version: 3,
          id: 55,
          schemaType: api.SchemaKindDto.protobuf,
          schema: 'syntax = "proto3"; message Order {} message Customer {}',
          references: [],
        ),
        fields: api.SchemaFieldModelDto(
          kind: api.SchemaKindDto.protobuf,
          messages: ['Order', 'Customer'],
          fields: [
            api.SchemaFieldEntryDto(
              path: 'customer',
              name: 'customer',
              depth: 0,
              typeLabel: 'Customer',
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
            api.SchemaFieldEntryDto(
              path: 'tags',
              name: 'tags',
              depth: 0,
              typeLabel: 'string',
              optional: false,
              repeated: true,
            ),
          ],
          truncated: false,
        ),
      );
      final controller = SchemaController(
        registryService: _FakeSchemaRegistryService(
          subjectsByCluster: const {
            'prod': ['orders-value'],
          },
          views: const {('orders-value', null): protoView},
        ),
      );

      final pinned = <String>[];
      final filtered = <String>[];

      await tester.pumpWidget(
        _wrap(
          TopicSchemaInspectorView(
            profile: _profile,
            topicName: 'orders',
            controller: controller,
            onPinToColumn: pinned.add,
            onFilterByField: filtered.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Protobuf · v3 · ID 55'), findsOneWidget);
      expect(find.textContaining('Messages: Order, Customer'), findsOneWidget);
      expect(find.textContaining('(repeated)'), findsWidgets);

      // Pin & filter on nested Protobuf field `name` -> `customer.name`.
      final pinIcons = find.byIcon(Icons.push_pin_outlined);
      expect(pinIcons, findsWidgets);
      await tester.tap(pinIcons.at(1));
      await tester.pumpAndSettle();
      expect(pinned, ['customer.name']);

      final filterIcons = find.byIcon(Icons.filter_alt_outlined);
      expect(filterIcons, findsWidgets);
      await tester.tap(filterIcons.at(1));
      await tester.pumpAndSettle();
      expect(filtered, ['customer.name']);
    },
  );

  testWidgets('proto2 schema shows unavailable notice and raw text', (
    tester,
  ) async {
    const rawProto2 =
        'syntax = "proto2"; message Legacy { required string a = 1; }';
    const proto2View = api.SubjectSchemaViewDto(
      schema: api.SubjectSchemaDto(
        subject: 'legacy-value',
        version: 1,
        id: 7,
        schemaType: api.SchemaKindDto.protobuf,
        schema: rawProto2,
        references: [],
      ),
      fields: api.SchemaFieldModelDto(
        kind: api.SchemaKindDto.protobuf,
        messages: [],
        fields: [],
        truncated: false,
        unavailableReason: 'proto2 is not supported',
      ),
    );
    final controller = SchemaController(
      registryService: _FakeSchemaRegistryService(
        subjectsByCluster: const {
          'prod': ['legacy-value'],
        },
        views: const {('legacy-value', null): proto2View},
      ),
    );

    await tester.pumpWidget(
      _wrap(
        TopicSchemaInspectorView(
          profile: _profile,
          topicName: 'legacy',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Structured view unavailable: proto2 is not supported',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('syntax = "proto2"'), findsOneWidget);
  });

  testWidgets('compatibility displays inherited, subject-set, and 403-unknown', (
    tester,
  ) async {
    const view = api.SubjectSchemaViewDto(
      schema: api.SubjectSchemaDto(
        subject: 'orders-value',
        version: 1,
        id: 1,
        schemaType: api.SchemaKindDto.avro,
        schema:
            '{"type":"record","name":"R","fields":[{"name":"a","type":"string"}]}',
        references: [],
      ),
      fields: api.SchemaFieldModelDto(
        kind: api.SchemaKindDto.avro,
        messages: [],
        fields: [],
        truncated: false,
      ),
    );

    // 1. Inherited
    var controller = SchemaController(
      registryService: _FakeSchemaRegistryService(
        subjectsByCluster: const {
          'prod': ['orders-value'],
        },
        views: const {('orders-value', null): view},
        globalCompatibilityResult: 'BACKWARD',
        subjectCompatibilityResult: const {'orders-value': null},
      ),
    );
    await tester.pumpWidget(
      _wrap(
        TopicSchemaInspectorView(
          key: const ValueKey('compat-inherited'),
          profile: _profile,
          topicName: 'orders',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Compatibility: BACKWARD (inherited)'), findsOneWidget);

    // 2. Set on subject
    controller = SchemaController(
      registryService: _FakeSchemaRegistryService(
        subjectsByCluster: const {
          'prod': ['orders-value'],
        },
        views: const {('orders-value', null): view},
        subjectCompatibilityResult: const {'orders-value': 'FULL'},
      ),
    );
    await tester.pumpWidget(
      _wrap(
        TopicSchemaInspectorView(
          key: const ValueKey('compat-subject'),
          profile: _profile,
          topicName: 'orders',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Compatibility: FULL (set on subject)'), findsOneWidget);

    // 3. 403-unknown
    controller = SchemaController(
      registryService: _FakeSchemaRegistryService(
        subjectsByCluster: const {
          'prod': ['orders-value'],
        },
        views: const {('orders-value', null): view},
        subjectCompatibilityResult: const {
          'orders-value': api.SchemaRegistryErrorDto(
            kind: api.SchemaRegistryErrorKindDto.forbidden,
            status: 403,
            detail: 'Forbidden',
          ),
        },
      ),
    );
    await tester.pumpWidget(
      _wrap(
        TopicSchemaInspectorView(
          key: const ValueKey('compat-403'),
          profile: _profile,
          topicName: 'orders',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Compatibility: unknown'), findsOneWidget);
    expect(find.textContaining('HTTP 403'), findsOneWidget);
  });

  testWidgets(
    'tapping a reference chip opens SchemaViewerDialog at ref version',
    (tester) async {
      const mainView = api.SubjectSchemaViewDto(
        schema: api.SubjectSchemaDto(
          subject: 'orders-value',
          version: 1,
          id: 1,
          schemaType: api.SchemaKindDto.protobuf,
          schema: 'syntax = "proto3"; import "common.proto"; message Order {}',
          references: [
            api.SchemaReferenceDto(
              name: 'common.proto',
              subject: 'common-proto',
              version: 2,
            ),
          ],
        ),
        fields: api.SchemaFieldModelDto(
          kind: api.SchemaKindDto.protobuf,
          messages: ['Order'],
          fields: [],
          truncated: false,
        ),
      );
      const refView = api.SubjectSchemaViewDto(
        schema: api.SubjectSchemaDto(
          subject: 'common-proto',
          version: 2,
          id: 2,
          schemaType: api.SchemaKindDto.protobuf,
          schema: 'syntax = "proto3"; message Money {}',
          references: [],
        ),
        fields: api.SchemaFieldModelDto(
          kind: api.SchemaKindDto.protobuf,
          messages: ['Money'],
          fields: [],
          truncated: false,
        ),
      );
      final controller = SchemaController(
        registryService: _FakeSchemaRegistryService(
          subjectsByCluster: const {
            'prod': ['orders-value', 'common-proto'],
          },
          views: const {
            ('orders-value', null): mainView,
            ('common-proto', 2): refView,
          },
          versionsBySubject: const {
            'common-proto': [1, 2],
          },
        ),
      );

      // The app's default window: this inspector shows two schema cards and
      // needs the height the desktop shell actually gives it.
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(
          TopicSchemaInspectorView(
            profile: _profile,
            topicName: 'orders',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('common.proto (common-proto v2)'));
      await tester.pumpAndSettle();

      expect(find.byType(SchemaViewerDialog), findsOneWidget);
      expect(find.text('Schema: common-proto'), findsOneWidget);
    },
  );

  testWidgets(
    'copy & save: clipboard, proposed filename per type, cancel, write failure',
    (tester) async {
      String? clipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });

      const rawProto = 'syntax = "proto3"; message M {}';
      const protoView = api.SubjectSchemaViewDto(
        schema: api.SubjectSchemaDto(
          subject: 'orders-value',
          version: 4,
          id: 9,
          schemaType: api.SchemaKindDto.protobuf,
          schema: rawProto,
          references: [],
        ),
        fields: api.SchemaFieldModelDto(
          kind: api.SchemaKindDto.protobuf,
          messages: ['M'],
          fields: [],
          truncated: false,
        ),
      );

      final controller = SchemaController(
        registryService: _FakeSchemaRegistryService(
          subjectsByCluster: const {
            'prod': ['orders-value'],
          },
          views: const {('orders-value', null): protoView},
        ),
      );
      final fakePicker = _FakeFilePicker();
      FilePickerPlatform.instance = fakePicker;

      await tester.pumpWidget(
        _wrap(
          TopicSchemaInspectorView(
            profile: _profile,
            topicName: 'orders',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Copy
      await tester.tap(find.byKey(const Key('schema_copy_value')));
      await tester.pumpAndSettle();
      expect(clipboardText, rawProto);
      expect(find.text('Schema copied to clipboard'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Save cancel
      fakePicker.nextSavePath = null;
      await tester.tap(find.byKey(const Key('schema_save_value')));
      await tester.pumpAndSettle();
      expect(fakePicker.lastSuggestedFileName, 'orders-value-v4.proto');

      // Save success
      final tmpDir = Directory.systemTemp.createTempSync(
        'kafkalyzer_schema_test_',
      );
      try {
        final outPath = '${tmpDir.path}/saved.proto';
        fakePicker.nextSavePath = outPath;
        await tester.tap(find.byKey(const Key('schema_save_value')));
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 500));
        expect(File(outPath).readAsStringSync(), rawProto);
        expect(find.textContaining('Schema saved to $outPath'), findsOneWidget);
        await tester.pump(const Duration(seconds: 9));
        await tester.pumpAndSettle();

        // Save write failure (directory path cannot be opened as file)
        fakePicker.nextSavePath = tmpDir.path;
        await tester.tap(find.byKey(const Key('schema_save_value')));
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.textContaining('Failed to save schema'), findsOneWidget);
      } finally {
        tmpDir.deleteSync(recursive: true);
      }

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    },
  );
}
