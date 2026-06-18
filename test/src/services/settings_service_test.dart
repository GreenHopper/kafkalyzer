import 'dart:convert';
import 'dart:io';
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
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

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

class MockFilePicker extends FilePickerPlatform {
  String? savePath;
  FilePickerResult? pickResult;
  bool saveFileCalled = false;
  bool pickFilesCalled = false;

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
    saveFileCalled = true;
    if (savePath == 'throw') {
      throw const FileSystemException('Failed to write');
    }
    return savePath;
  }

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    pickFilesCalled = true;
    return pickResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsService settingsService;
  late MockFilePicker mockFilePicker;
  late String tempDir;

  setUp(() async {
    await getIt.reset();

    // Register dependencies needed by controllers first
    getIt.registerSingleton<ClusterService>(MockClusterService());
    getIt.registerSingleton<ScriptRepository>(MockScriptRepository());

    getIt.registerSingleton<ClusterListController>(MockClusterListController());
    getIt.registerSingleton<ScriptController>(MockScriptController());

    tempDir = Directory.systemTemp
        .createTempSync('kafkalyzer_settings_test')
        .path;

    SharedPreferences.setMockInitialValues({'test_key': 'test_value'});

    // Mock path_provider channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationSupportDirectory' ||
                methodCall.method == 'getApplicationDocumentsDirectory') {
              return tempDir;
            }
            return null;
          },
        );

    mockFilePicker = MockFilePicker();
    FilePickerPlatform.instance = mockFilePicker;
    settingsService = SettingsService();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    try {
      Directory(tempDir).deleteSync(recursive: true);
    } catch (_) {}
  });

  group('SettingsService', () {
    test('exportConfiguration creates a zip file and saves it', () async {
      // 1. Setup mock files that should be archived
      final keystorePath = p.join(tempDir, 'keystore.jks');
      File(keystorePath).writeAsStringSync('keystore bytes');

      final truststorePath = p.join(tempDir, 'truststore.jks');
      File(truststorePath).writeAsStringSync('truststore bytes');

      // Create a GCS Key File candidate
      final gcsSharedPrefsDir = Directory(p.join(tempDir, 'shared_preferences'))
        ..createSync();
      final gcsPath = p.join(
        gcsSharedPrefsDir.path,
        'wgs-kaenup-data-test-6d6c17c275e1.json',
      );
      File(gcsPath).writeAsStringSync('gcs credentials');

      // Define cluster profiles preference
      final clusters = [
        {
          'name': 'test-cluster',
          'sslKeystoreLocation': keystorePath,
          'sslTruststoreLocation': truststorePath,
        },
      ];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cluster_profiles', jsonEncode(clusters));

      final exportPath = p.join(tempDir, 'exported_config.zip');
      mockFilePicker.savePath = exportPath;

      await settingsService.exportConfiguration();

      expect(mockFilePicker.saveFileCalled, isTrue);
      final exportFile = File(exportPath);
      expect(exportFile.existsSync(), isTrue);

      // Verify zip contains keystore, truststore, GCS key, and preferences.json
      final archive = ZipDecoder().decodeBytes(exportFile.readAsBytesSync());
      final fileNames = archive.map((f) => f.name).toList();

      expect(
        fileNames,
        containsAll([
          'files/keystore.jks',
          'files/truststore.jks',
          'files/wgs-kaenup-data-test-6d6c17c275e1.json',
          'preferences.json',
        ]),
      );

      // Check modified preferences file inside zip
      final prefsFile = archive.firstWhere((f) => f.name == 'preferences.json');
      final prefsJson = utf8.decode(prefsFile.content as List<int>);
      final decodedPrefs = jsonDecode(prefsJson) as Map<String, dynamic>;

      final dynamic exportedClustersJson = decodedPrefs['cluster_profiles'];
      expect(exportedClustersJson, isNotNull);
      final List<dynamic> exportedClusters = jsonDecode(
        exportedClustersJson as String,
      );
      expect(
        exportedClusters.first['sslKeystoreLocation'],
        'files/keystore.jks',
      );
      expect(
        exportedClusters.first['sslTruststoreLocation'],
        'files/truststore.jks',
      );
    });

    test(
      'exportConfiguration continues when keystore files do not exist',
      () async {
        final clusters = [
          {
            'name': 'non-existent-paths',
            'sslKeystoreLocation': '/invalid/path/to/keystore.jks',
            'sslTruststoreLocation': '/invalid/path/to/truststore.jks',
          },
        ];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cluster_profiles', jsonEncode(clusters));

        final exportPath = p.join(tempDir, 'exported_config_no_files.zip');
        mockFilePicker.savePath = exportPath;

        await settingsService.exportConfiguration();

        expect(mockFilePicker.saveFileCalled, isTrue);
        final archive = ZipDecoder().decodeBytes(
          File(exportPath).readAsBytesSync(),
        );
        final fileNames = archive.map((f) => f.name).toList();

        expect(fileNames, contains('preferences.json'));
        expect(fileNames, isNot(contains('files/keystore.jks')));
      },
    );

    test('exportConfiguration handles save file cancel', () async {
      mockFilePicker.savePath = null;
      await settingsService.exportConfiguration();
      expect(mockFilePicker.saveFileCalled, isTrue);
    });

    test('exportConfiguration propagates exceptions', () async {
      mockFilePicker.savePath = 'throw';
      expect(
        () => settingsService.exportConfiguration(),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('importConfiguration reads zip and restores preferences', () async {
      final archive = Archive();
      final clusters = [
        {
          'name': 'test-cluster',
          'sslKeystoreLocation': 'files/keystore.jks',
          'sslTruststoreLocation': 'files/truststore.jks',
        },
      ];

      final savedScripts = [
        {'name': 'script1', 'outputDirectory': '/invalid/output/dir'},
      ];

      final prefsJson = jsonEncode({
        'test_key': 'new_value',
        'cluster_profiles': jsonEncode(clusters),
        'saved_scripts_v1': jsonEncode(savedScripts),
        'general_default_output_dir': '/invalid/default/dir',
      });

      final prefsBytes = utf8.encode(prefsJson);
      archive.addFile(
        ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
      );

      final keystoreBytes = utf8.encode('keystore binary');
      archive.addFile(
        ArchiveFile('files/keystore.jks', keystoreBytes.length, keystoreBytes),
      );

      final zipBytes = ZipEncoder().encode(archive);

      mockFilePicker.pickResult = FilePickerResult([
        PlatformFile(
          name: 'config.zip',
          size: zipBytes.length,
          bytes: Uint8List.fromList(zipBytes),
        ),
      ]);

      await settingsService.importConfiguration();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('test_key'), 'new_value');

      // Verify clusters paths are fixed to local appSupportDir path
      final importedClustersJson = prefs.getString('cluster_profiles')!;
      final List<dynamic> importedClusters = jsonDecode(importedClustersJson);
      final resolvedKeystore =
          importedClusters.first['sslKeystoreLocation'] as String;
      expect(resolvedKeystore, contains('shared_preferences'));
      expect(resolvedKeystore, endsWith('keystore.jks'));

      // Check default output directory and script directory are fixed
      final defaultOutputDir = prefs.getString('general_default_output_dir')!;
      expect(defaultOutputDir, contains('Kafkalyzer'));
      expect(defaultOutputDir, endsWith('Output'));

      final importedScriptsJson = prefs.getString('saved_scripts_v1')!;
      final List<dynamic> importedScripts = jsonDecode(importedScriptsJson);
      final scriptOutputDir = importedScripts.first['outputDirectory'];
      expect(scriptOutputDir, isNull);
    });

    test(
      'importConfiguration supports parsing filepath directly if bytes null',
      () async {
        // Create a physical zip file
        final archive = Archive();
        final prefsJson = jsonEncode({'filepath_key': 'resolved_value'});
        final prefsBytes = utf8.encode(prefsJson);
        archive.addFile(
          ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
        );
        final zipBytes = ZipEncoder().encode(archive);

        final zipPath = p.join(tempDir, 'filepath_config.zip');
        File(zipPath).writeAsBytesSync(zipBytes);

        mockFilePicker.pickResult = FilePickerResult([
          PlatformFile(
            name: 'config.zip',
            size: zipBytes.length,
            path: zipPath,
          ),
        ]);

        await settingsService.importConfiguration();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('filepath_key'), 'resolved_value');
      },
    );

    test('importConfiguration handles picker cancel', () async {
      mockFilePicker.pickResult = null;
      await settingsService.importConfiguration();
      expect(mockFilePicker.pickFilesCalled, isTrue);
    });

    test('importConfiguration throws when fileBytes is null', () async {
      mockFilePicker.pickResult = FilePickerResult([
        PlatformFile(name: 'config.zip', size: 0),
      ]);

      expect(
        () => settingsService.importConfiguration(),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'importConfiguration handles invalid cluster_profiles or scripts format gracefully',
      () async {
        final archive = Archive();
        final prefsJson = jsonEncode({
          'cluster_profiles': 'not-a-list-or-json-array',
          'saved_scripts_v1': 'not-a-list',
        });
        final prefsBytes = utf8.encode(prefsJson);
        archive.addFile(
          ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
        );
        final zipBytes = ZipEncoder().encode(archive);

        mockFilePicker.pickResult = FilePickerResult([
          PlatformFile(
            name: 'config.zip',
            size: zipBytes.length,
            bytes: Uint8List.fromList(zipBytes),
          ),
        ]);

        await settingsService.importConfiguration();

        final prefs = await SharedPreferences.getInstance();
        // Keys are invalid types, so they should be ignored / removed during import
        expect(prefs.containsKey('cluster_profiles'), isFalse);
        expect(prefs.containsKey('saved_scripts_v1'), isFalse);
      },
    );
  });
}
