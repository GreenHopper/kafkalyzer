import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Manual Mocks
class MockClusterService extends ClusterService {
  @override
  Future<List<ClusterProfile>> loadClusters() async => [];
}

class MockScriptRepository implements ScriptRepository {
  @override
  Future<void> deleteScript(String id) async {}

  @override
  Future<List<Script>> getScripts() async => [];

  @override
  Future<void> saveScript(Script script) async {}
}

class MockClusterListController extends ClusterListController {
  @override
  Future<void> loadClusters() async {
    // No-op for test
  }
}

class MockScriptController extends ScriptController {
  @override
  Future<void> loadScripts() async {
    // No-op for test
  }
}

class MockFilePicker extends FilePicker {
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
    return '/tmp/kafkalyzer_config.zip'; // Dummy path
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsService settingsService;

  setUp(() async {
    await getIt.reset();

    // Register dependencies needed by controllers first
    getIt.registerSingleton<ClusterService>(MockClusterService());
    getIt.registerSingleton<ScriptRepository>(MockScriptRepository());

    getIt.registerSingleton<ClusterListController>(MockClusterListController());
    getIt.registerSingleton<ScriptController>(MockScriptController());

    SharedPreferences.setMockInitialValues({'test_key': 'test_value'});

    // Mock path_provider channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationSupportDirectory' ||
                methodCall.method == 'getApplicationDocumentsDirectory') {
              return '/tmp';
            }
            return null;
          },
        );

    FilePicker.platform = MockFilePicker();
    settingsService = SettingsService();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  group('SettingsService', () {
    test('exportConfiguration creates a zip file and saves it', () async {
      await settingsService.exportConfiguration();
    });

    test('importConfiguration reads zip and restores preferences', () async {
      // Create a mock zip file content
      final archive = Archive();
      final prefsJson = '{"test_key": "new_value"}';
      final prefsBytes = utf8.encode(prefsJson);
      archive.addFile(
        ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
      );
      final zipBytes = ZipEncoder().encode(archive);

      // Mock FilePicker to return this file
      FilePicker.platform = MockFilePickerWithResult(zipBytes);

      await settingsService.importConfiguration();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('test_key'), 'new_value');
    });
  });
}

class MockFilePickerWithResult extends FilePicker {
  final List<int> fileBytes;

  MockFilePickerWithResult(this.fileBytes);

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool? allowCompression,
    bool allowMultiple = false,
    bool? withData,
    bool? withReadStream,
    bool lockParentWindow = false,
    bool readSequential = false,
    int compressionQuality = 30,
  }) async {
    return FilePickerResult([
      PlatformFile(
        name: 'config.zip',
        size: fileBytes.length,
        bytes: Uint8List.fromList(fileBytes),
      ),
    ]);
  }
}
