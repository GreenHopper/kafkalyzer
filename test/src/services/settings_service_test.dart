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
import 'package:kafkalyzer/src/rust/api/profile_crypto.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/encrypted_bundle.dart';
import 'package:kafkalyzer/src/services/secure_storage_service.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:kafkalyzer/src/utils/archive_safety.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import '../rust/api/rust_mocks.mocks.dart';

class _FakeFlutterSecureStorage implements FlutterSecureStorage {
  final Map<String, String> data = {};
  bool throwOnOperation = false;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwOnOperation) throw Exception('Keyring error');
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwOnOperation) throw Exception('Keyring error');
    return data[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwOnOperation) throw Exception('Keyring error');
    data.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _registerClusterCodec(MockKafkalyzerRustLibApi api) {
  when(
    api.crateApiJsonPathSerializeClusterProfile(profile: anyNamed('profile')),
  ).thenAnswer((inv) async {
    final p = inv.namedArguments[#profile] as ClusterProfile;
    return jsonEncode({
      'name': p.name,
      'bootstrapServers': p.bootstrapServers,
      if (p.saslUsername != null) 'saslUsername': p.saslUsername,
      if (p.saslPassword != null) 'saslPassword': p.saslPassword,
      if (p.sslKeystoreLocation != null)
        'sslKeystoreLocation': p.sslKeystoreLocation,
      if (p.sslTruststoreLocation != null)
        'sslTruststoreLocation': p.sslTruststoreLocation,
      if (p.schemaRegistryPassword != null)
        'schemaRegistryPassword': p.schemaRegistryPassword,
    });
  });

  when(
    api.crateApiJsonPathDeserializeClusterProfile(json: anyNamed('json')),
  ).thenAnswer((inv) async {
    final m = jsonDecode(inv.namedArguments[#json] as String) as Map;
    return ClusterProfile(
      name: (m['name'] as String?) ?? '',
      bootstrapServers: (m['bootstrapServers'] as String?) ?? 'localhost:9092',
      saslUsername: m['saslUsername'] as String?,
      saslPassword: m['saslPassword'] as String?,
      sslKeystoreLocation: m['sslKeystoreLocation'] as String?,
      sslTruststoreLocation: m['sslTruststoreLocation'] as String?,
      schemaRegistryPassword: m['schemaRegistryPassword'] as String?,
      tlsVerification: TlsVerification.enabled,
    );
  });
}

class MockScriptRepository implements ScriptRepository {
  @override
  StoreStatus get storeStatus => const StoreStatus.ok();

  @override
  Future<void> discardUnreadable() async {}

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
  List<String>? lastSaveAllowedExtensions;
  List<String>? lastPickAllowedExtensions;

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
    lastSaveAllowedExtensions = allowedExtensions;
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
    lastPickAllowedExtensions = allowedExtensions;
    return pickResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsService settingsService;
  late MockFilePicker mockFilePicker;
  late String tempDir;
  late _FakeFlutterSecureStorage fakeKeyring;
  final mockRustApi = MockKafkalyzerRustLibApi();

  setUpAll(() {
    KafkalyzerRustLib.initMock(api: mockRustApi);
  });

  tearDownAll(() {
    KafkalyzerRustLib.dispose();
  });

  setUp(() async {
    reset(mockRustApi);
    _registerClusterCodec(mockRustApi);

    fakeKeyring = _FakeFlutterSecureStorage();
    final secureStorage = SecureStorageService(storage: fakeKeyring);
    getIt.registerSingleton<SecureStorageService>(secureStorage);
    getIt.registerSingleton<ClusterService>(
      ClusterService(secureStorage: secureStorage),
    );
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

      await settingsService.exportConfiguration(
        dialogTitle: 'Export Configuration',
      );

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

        await settingsService.exportConfiguration(
          dialogTitle: 'Export Configuration',
        );

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
      await settingsService.exportConfiguration(
        dialogTitle: 'Export Configuration',
      );
      expect(mockFilePicker.saveFileCalled, isTrue);
    });

    test('exportConfiguration propagates exceptions', () async {
      mockFilePicker.savePath = 'throw';
      expect(
        () => settingsService.exportConfiguration(
          dialogTitle: 'Export Configuration',
        ),
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

      await settingsService.importConfiguration(
        dialogTitle: 'Import Configuration',
        promptPassphrase: ({required previousAttemptFailed}) async => null,
      );

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

        await settingsService.importConfiguration(
          dialogTitle: 'Import Configuration',
          promptPassphrase: ({required previousAttemptFailed}) async => null,
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('filepath_key'), 'resolved_value');
      },
    );

    test('importConfiguration handles picker cancel', () async {
      mockFilePicker.pickResult = null;
      await settingsService.importConfiguration(
        dialogTitle: 'Import Configuration',
        promptPassphrase: ({required previousAttemptFailed}) async => null,
      );
      expect(mockFilePicker.pickFilesCalled, isTrue);
    });

    test('importConfiguration throws when fileBytes is null', () async {
      mockFilePicker.pickResult = FilePickerResult([
        PlatformFile(name: 'config.zip', size: 0),
      ]);

      expect(
        () => settingsService.importConfiguration(
          dialogTitle: 'Import Configuration',
          promptPassphrase: ({required previousAttemptFailed}) async => null,
        ),
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

        await settingsService.importConfiguration(
          dialogTitle: 'Import Configuration',
          promptPassphrase: ({required previousAttemptFailed}) async => null,
        );

        final prefs = await SharedPreferences.getInstance();
        // Keys are invalid types, so they should be ignored / removed during import
        expect(prefs.containsKey('cluster_profiles'), isFalse);
        expect(prefs.containsKey('saved_scripts_v1'), isFalse);
      },
    );

    test(
      'exportConfiguration scrubs passwords by default and includes credentials when opt-in is true',
      () async {
        final secureStorage = getIt<SecureStorageService>();
        await secureStorage.saveClusterSecrets('auth-cluster', {
          'saslPassword': 'secret_password',
          'schemaRegistryPassword': 'sr_secret_password',
        });

        final clusters = [
          {
            'name': 'auth-cluster',
            'bootstrapServers': 'localhost:9092',
            'saslUsername': 'user1',
            'saslPassword': 'should_be_scrubbed',
          },
        ];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cluster_profiles', jsonEncode(clusters));

        // 1. Default export (includeSensitiveCredentials = false)
        final defaultExportPath = p.join(tempDir, 'export_default.zip');
        mockFilePicker.savePath = defaultExportPath;

        await settingsService.exportConfiguration(
          dialogTitle: 'Export Configuration',
        );

        final defaultArchive = ZipDecoder().decodeBytes(
          File(defaultExportPath).readAsBytesSync(),
        );
        final defaultPrefsFile = defaultArchive.firstWhere(
          (f) => f.name == 'preferences.json',
        );
        final defaultPrefsJson = utf8.decode(
          defaultPrefsFile.content as List<int>,
        );
        final decodedDefault =
            jsonDecode(defaultPrefsJson) as Map<String, dynamic>;
        final defaultClusters =
            jsonDecode(decodedDefault['cluster_profiles'] as String)
                as List<dynamic>;

        expect(defaultClusters.first['saslUsername'], 'user1');
        expect(defaultClusters.first.containsKey('saslPassword'), isFalse);
        expect(
          defaultClusters.first.containsKey('schemaRegistryPassword'),
          isFalse,
        );

        // 2. Opt-in export (encrypted with passphrase)
        List<int>? capturedPlaintext;
        when(
          mockRustApi.crateApiProfileCryptoEncryptBundleWithPassphrase(
            plaintext: anyNamed('plaintext'),
            passphrase: 'correct-horse-battery',
          ),
        ).thenAnswer((inv) async {
          capturedPlaintext = inv.namedArguments[#plaintext] as List<int>;
          return BundleCryptoResult(
            data: Uint8List.fromList(capturedPlaintext!),
          );
        });

        final optInExportPath = p.join(tempDir, 'export_opt_in.zip.age');
        mockFilePicker.savePath = optInExportPath;

        await settingsService.exportConfiguration(
          dialogTitle: 'Export Configuration',
          encryptionPassphrase: 'correct-horse-battery',
        );

        final optInArchive = ZipDecoder().decodeBytes(capturedPlaintext!);
        final optInPrefsFile = optInArchive.firstWhere(
          (f) => f.name == 'preferences.json',
        );
        final optInPrefsJson = utf8.decode(optInPrefsFile.content as List<int>);
        final decodedOptIn = jsonDecode(optInPrefsJson) as Map<String, dynamic>;
        final optInClusters =
            jsonDecode(decodedOptIn['cluster_profiles'] as String)
                as List<dynamic>;

        expect(optInClusters.first['saslUsername'], 'user1');
        expect(optInClusters.first['saslPassword'], 'secret_password');
        expect(
          optInClusters.first['schemaRegistryPassword'],
          'sr_secret_password',
        );
      },
    );

    test(
      'importConfiguration rejects unsafe entries without writing files or preferences',
      () async {
        for (final unsafeEntry in [
          'files/../../evil',
          'files//abs/evil',
          r'files/C:\evil',
        ]) {
          final prefsBytes = utf8.encode(
            jsonEncode({'test_key': 'overwritten_value', 'new_key': 'evil'}),
          );
          final truststoreBytes = utf8.encode('good');
          final evilBytes = utf8.encode('evil');

          final archive = Archive()
            ..addFile(
              ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
            )
            ..addFile(
              ArchiveFile(
                'files/truststore.jks',
                truststoreBytes.length,
                truststoreBytes,
              ),
            )
            ..addFile(ArchiveFile(unsafeEntry, evilBytes.length, evilBytes));

          final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
          mockFilePicker.pickResult = FilePickerResult([
            PlatformFile(
              name: 'bad_config.zip',
              size: zipBytes.length,
              bytes: zipBytes,
            ),
          ]);

          await expectLater(
            () => settingsService.importConfiguration(
              dialogTitle: 'Import Configuration',
              promptPassphrase: ({required previousAttemptFailed}) async =>
                  null,
            ),
            throwsA(isA<UnsafeArchiveEntryException>()),
            reason:
                'Expected $unsafeEntry to throw UnsafeArchiveEntryException',
          );

          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('test_key'), 'test_value');
          expect(prefs.containsKey('new_key'), isFalse);
          expect(
            File(
              p.join(tempDir, 'shared_preferences', 'truststore.jks'),
            ).existsSync(),
            isFalse,
          );
        }
      },
    );

    test(
      'importConfiguration moves bundle credentials to keyring and overrides stale values',
      () async {
        fakeKeyring.data['cluster_auth-cluster_saslPassword'] = 'stale_pw';
        final archive = Archive();
        final prefsJson = jsonEncode({
          'credentials_migrated_to_keyring_v1': true,
          'cluster_profiles': jsonEncode([
            {
              'name': 'auth-cluster',
              'bootstrapServers': 'b:9092',
              'saslPassword': 'new_bundle_pw',
            },
          ]),
        });
        final prefsBytes = utf8.encode(prefsJson);
        archive.addFile(
          ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
        );
        final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
        mockFilePicker.pickResult = FilePickerResult([
          PlatformFile(
            name: 'creds.zip',
            size: zipBytes.length,
            bytes: zipBytes,
          ),
        ]);

        await settingsService.importConfiguration(
          dialogTitle: 'Import Configuration',
          promptPassphrase: ({required previousAttemptFailed}) async => null,
        );

        expect(
          fakeKeyring.data['cluster_auth-cluster_saslPassword'],
          'new_bundle_pw',
        );
        final prefs = await SharedPreferences.getInstance();
        final stored = jsonDecode(prefs.getString('cluster_profiles')!) as List;
        expect((stored.single as Map).containsKey('saslPassword'), isFalse);
        expect(prefs.getBool('credentials_migrated_to_keyring_v1'), isTrue);
      },
    );

    test(
      'importConfiguration keeps plaintext and clears migration flag when keyring fails',
      () async {
        fakeKeyring.throwOnOperation = true;
        final archive = Archive();
        final prefsJson = jsonEncode({
          'credentials_migrated_to_keyring_v1': true,
          'cluster_profiles': jsonEncode([
            {
              'name': 'auth-cluster',
              'bootstrapServers': 'b:9092',
              'saslPassword': 'bundle_pw',
            },
          ]),
        });
        final prefsBytes = utf8.encode(prefsJson);
        archive.addFile(
          ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
        );
        final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
        mockFilePicker.pickResult = FilePickerResult([
          PlatformFile(
            name: 'creds_fail.zip',
            size: zipBytes.length,
            bytes: zipBytes,
          ),
        ]);

        await settingsService.importConfiguration(
          dialogTitle: 'Import Configuration',
          promptPassphrase: ({required previousAttemptFailed}) async => null,
        );

        final prefs = await SharedPreferences.getInstance();
        final stored = jsonDecode(prefs.getString('cluster_profiles')!) as List;
        expect((stored.single as Map)['saslPassword'], 'bundle_pw');
        expect(prefs.getBool('credentials_migrated_to_keyring_v1'), isFalse);
      },
    );

    test(
      'importConfiguration merges cluster profiles and keeps existing profiles not in bundle',
      () async {
        final clusterService = getIt<ClusterService>();
        await clusterService.saveClusters([
          const ClusterProfile(
            name: 'Prod',
            bootstrapServers: 'prod:9092',
            tlsVerification: TlsVerification.enabled,
          ),
        ]);

        final archive = Archive();
        final prefsJson = jsonEncode({
          'cluster_profiles': jsonEncode([
            {'name': 'Test', 'bootstrapServers': 'test:9092'},
          ]),
        });
        final prefsBytes = utf8.encode(prefsJson);
        archive.addFile(
          ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
        );
        final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
        mockFilePicker.pickResult = FilePickerResult([
          PlatformFile(
            name: 'merge.zip',
            size: zipBytes.length,
            bytes: zipBytes,
          ),
        ]);

        await settingsService.importConfiguration(
          dialogTitle: 'Import Configuration',
          promptPassphrase: ({required previousAttemptFailed}) async => null,
        );

        final reloaded = await clusterService.loadClusters();
        expect(reloaded.map((c) => c.name), ['Prod', 'Test']);
      },
    );

    test('exportConfiguration does not include legacy GCS key file', () async {
      final sharedPrefsDir = Directory(p.join(tempDir, 'shared_preferences'))
        ..createSync(recursive: true);
      File(
        p.join(sharedPrefsDir.path, 'wgs-kaenup-data-test-6d6c17c275e1.json'),
      ).writeAsStringSync('{"secret":"gcs"}');

      final exportPath = p.join(tempDir, 'export_no_gcs.zip');
      mockFilePicker.savePath = exportPath;

      await settingsService.exportConfiguration(
        dialogTitle: 'Export Configuration',
      );

      final archive = ZipDecoder().decodeBytes(
        File(exportPath).readAsBytesSync(),
      );
      expect(archive.map((f) => f.name).toList(), ['preferences.json']);
    });

    test(
      'exportConfiguration default export strips all six secret fields and writes ZIP',
      () async {
        await fakeKeyring.write(
          key: 'cluster_secret_cluster-a_saslPassword',
          value: 's1',
        );
        await fakeKeyring.write(
          key: 'cluster_secret_cluster-a_saslOauthbearerToken',
          value: 's2',
        );
        await fakeKeyring.write(
          key: 'cluster_secret_cluster-a_sslKeyPassword',
          value: 's3',
        );
        await fakeKeyring.write(
          key: 'cluster_secret_cluster-a_sslKeystorePassword',
          value: 's4',
        );
        await fakeKeyring.write(
          key: 'cluster_secret_cluster-a_sslTruststorePassword',
          value: 's5',
        );
        await fakeKeyring.write(
          key: 'cluster_secret_cluster-a_schemaRegistryPassword',
          value: 's6',
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'cluster_profiles',
          jsonEncode([
            {
              'name': 'cluster-a',
              'saslPassword': 's1',
              'saslOauthbearerToken': 's2',
              'sslPemKeyPassword': 's3',
              'sslKeystorePassword': 's4',
              'sslTruststorePassword': 's5',
              'schemaRegistryPassword': 's6',
            },
          ]),
        );

        final exportPath = p.join(tempDir, 'default_no_secrets.zip');
        mockFilePicker.savePath = exportPath;

        final saved = await settingsService.exportConfiguration(
          dialogTitle: 'Export Configuration',
        );
        expect(saved, exportPath);
        expect(mockFilePicker.lastSaveAllowedExtensions, ['zip']);

        final archive = ZipDecoder().decodeBytes(
          File(exportPath).readAsBytesSync(),
        );
        final prefsEntry = archive.findFile('preferences.json')!;
        final decodedPrefs =
            jsonDecode(utf8.decode(prefsEntry.content as List<int>))
                as Map<String, dynamic>;
        final clusters =
            jsonDecode(decodedPrefs['cluster_profiles'] as String)
                as List<dynamic>;
        final cluster = clusters.first as Map<String, dynamic>;
        for (final field in SecureStorageService.secretFields) {
          expect(cluster.containsKey(field), isFalse);
        }
      },
    );

    test(
      'exportConfiguration with passphrase includes all six secret fields in plaintext ZIP passed to encrypt and writes only encrypted bytes',
      () async {
        final secureStorage = getIt<SecureStorageService>();
        await secureStorage.saveClusterSecrets('cluster-a', {
          'saslPassword': 'sec-sasl',
          'saslOauthbearerToken': 'sec-oauth',
          'sslPemKeyPassword': 'sec-key',
          'sslKeystorePassword': 'sec-ks',
          'sslTruststorePassword': 'sec-ts',
          'schemaRegistryPassword': 'sec-sr',
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'cluster_profiles',
          jsonEncode([
            {'name': 'cluster-a'},
          ]),
        );

        List<int>? capturedPlaintext;
        final encryptedPayload = Uint8List.fromList([
          ...utf8.encode('age-encryption.org/v1\n'),
          1,
          2,
          3,
        ]);
        when(
          mockRustApi.crateApiProfileCryptoEncryptBundleWithPassphrase(
            plaintext: anyNamed('plaintext'),
            passphrase: 'correct-horse-battery',
          ),
        ).thenAnswer((inv) async {
          capturedPlaintext = inv.namedArguments[#plaintext] as List<int>;
          return BundleCryptoResult(data: encryptedPayload);
        });

        final exportPath = p.join(tempDir, 'kafkalyzer_config.zip');
        mockFilePicker.savePath = exportPath;

        final saved = await settingsService.exportConfiguration(
          dialogTitle: 'Export Configuration',
          encryptionPassphrase: 'correct-horse-battery',
        );
        expect(saved, '$exportPath.age');
        expect(mockFilePicker.lastSaveAllowedExtensions, ['age']);
        expect(File(exportPath).existsSync(), isFalse);
        expect(File('$exportPath.age').readAsBytesSync(), encryptedPayload);

        expect(capturedPlaintext, isNotNull);
        final archive = ZipDecoder().decodeBytes(capturedPlaintext!);
        final prefsEntry = archive.findFile('preferences.json')!;
        final decodedPrefs =
            jsonDecode(utf8.decode(prefsEntry.content as List<int>))
                as Map<String, dynamic>;
        final clusters =
            jsonDecode(decodedPrefs['cluster_profiles'] as String)
                as List<dynamic>;
        final cluster = clusters.first as Map<String, dynamic>;
        expect(cluster['saslPassword'], 'sec-sasl');
        expect(cluster['saslOauthbearerToken'], 'sec-oauth');
        expect(cluster['sslPemKeyPassword'], 'sec-key');
        expect(cluster['sslKeystorePassword'], 'sec-ks');
        expect(cluster['sslTruststorePassword'], 'sec-ts');
        expect(cluster['schemaRegistryPassword'], 'sec-sr');
      },
    );

    test(
      'exportConfiguration writes nothing and rethrows on encrypt failure',
      () async {
        when(
          mockRustApi.crateApiProfileCryptoEncryptBundleWithPassphrase(
            plaintext: anyNamed('plaintext'),
            passphrase: anyNamed('passphrase'),
          ),
        ).thenAnswer(
          (_) async => const BundleCryptoResult(
            error: BundleCryptoErrorKind.internal,
            message: 'boom',
          ),
        );

        final exportPath = p.join(tempDir, 'should_not_exist.zip.age');
        mockFilePicker.savePath = exportPath;

        await expectLater(
          () => settingsService.exportConfiguration(
            dialogTitle: 'Export Configuration',
            encryptionPassphrase: 'correct-horse-battery',
          ),
          throwsA(isA<EncryptedBundleException>()),
        );
        expect(File(exportPath).existsSync(), isFalse);
      },
    );

    test(
      'importConfiguration accepts zip and age, decrypts encrypted bundle, and restores preferences',
      () async {
        final archive = Archive();
        final prefsBytes = utf8.encode(
          jsonEncode({'encrypted_restored_key': 'restored_val'}),
        );
        archive.addFile(
          ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
        );
        final plainZip = Uint8List.fromList(ZipEncoder().encode(archive));
        final fakeAgeBytes = Uint8List.fromList([
          ...utf8.encode('age-encryption.org/v1\n'),
          9,
          8,
          7,
        ]);

        when(
          mockRustApi.crateApiProfileCryptoDecryptBundleWithPassphrase(
            ciphertext: fakeAgeBytes,
            passphrase: 'correct-horse-battery',
          ),
        ).thenAnswer((_) async => BundleCryptoResult(data: plainZip));

        mockFilePicker.pickResult = FilePickerResult([
          PlatformFile(
            name: 'config.zip.age',
            size: fakeAgeBytes.length,
            bytes: fakeAgeBytes,
          ),
        ]);

        final summary = await settingsService.importConfiguration(
          dialogTitle: 'Import Configuration',
          promptPassphrase: ({required previousAttemptFailed}) async =>
              'correct-horse-battery',
        );
        expect(summary, isNotNull);
        expect(mockFilePicker.lastPickAllowedExtensions, ['zip', 'age']);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('encrypted_restored_key'), 'restored_val');
      },
    );

    test(
      'importConfiguration returns null without modifying preferences when passphrase prompt is cancelled',
      () async {
        final fakeAgeBytes = Uint8List.fromList([
          ...utf8.encode('age-encryption.org/v1\n'),
          9,
          8,
          7,
        ]);

        mockFilePicker.pickResult = FilePickerResult([
          PlatformFile(
            name: 'config.zip.age',
            size: fakeAgeBytes.length,
            bytes: fakeAgeBytes,
          ),
        ]);

        final summary = await settingsService.importConfiguration(
          dialogTitle: 'Import Configuration',
          promptPassphrase: ({required previousAttemptFailed}) async => null,
        );
        expect(summary, isNull);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('test_key'), 'test_value');
      },
    );

    test(
      'importConfiguration decrypts encrypted bundle with profiles and writes secrets to keyring',
      () async {
        final archive = Archive();
        final prefsBytes = utf8.encode(
          jsonEncode({
            'cluster_profiles': jsonEncode([
              {
                'name': 'enc-cluster',
                'bootstrapServers': 'localhost:9092',
                'saslPassword': 'pw',
              },
            ]),
          }),
        );
        archive.addFile(
          ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
        );
        final plainZip = Uint8List.fromList(ZipEncoder().encode(archive));
        final fakeAgeBytes = Uint8List.fromList([
          ...utf8.encode('age-encryption.org/v1\n'),
          4,
          5,
          6,
        ]);

        when(
          mockRustApi.crateApiProfileCryptoDecryptBundleWithPassphrase(
            ciphertext: fakeAgeBytes,
            passphrase: 'correct-horse-battery',
          ),
        ).thenAnswer((_) async => BundleCryptoResult(data: plainZip));

        mockFilePicker.pickResult = FilePickerResult([
          PlatformFile(
            name: 'config.zip.age',
            size: fakeAgeBytes.length,
            bytes: fakeAgeBytes,
          ),
        ]);

        final result = await settingsService.importConfiguration(
          dialogTitle: 'Import Configuration',
          promptPassphrase: ({required previousAttemptFailed}) async =>
              'correct-horse-battery',
        );
        expect(result, isNotNull);
        final secrets = await getIt<SecureStorageService>().getClusterSecrets(
          'enc-cluster',
        );
        expect(secrets['saslPassword'], 'pw');
      },
    );

    test(
      'importConfiguration wrong passphrase then cancel leaves prefs and keyring untouched',
      () async {
        final fakeAgeBytes = Uint8List.fromList([
          ...utf8.encode('age-encryption.org/v1\n'),
          4,
          5,
          6,
        ]);
        when(
          mockRustApi.crateApiProfileCryptoDecryptBundleWithPassphrase(
            ciphertext: fakeAgeBytes,
            passphrase: 'wrong-passphrase',
          ),
        ).thenAnswer(
          (_) async => const BundleCryptoResult(
            error: BundleCryptoErrorKind.wrongPassphrase,
          ),
        );

        mockFilePicker.pickResult = FilePickerResult([
          PlatformFile(
            name: 'config.zip.age',
            size: fakeAgeBytes.length,
            bytes: fakeAgeBytes,
          ),
        ]);

        var attempts = 0;
        final result = await settingsService.importConfiguration(
          dialogTitle: 'Import Configuration',
          promptPassphrase: ({required previousAttemptFailed}) async {
            attempts++;
            return attempts == 1 ? 'wrong-passphrase' : null;
          },
        );
        expect(result, isNull);
        expect(attempts, 2);
        expect(fakeKeyring.data, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('test_key'), 'test_value');
      },
    );

    test(
      'importConfiguration corrupt encrypted bundle throws EncryptedBundleException without writing',
      () async {
        final fakeAgeBytes = Uint8List.fromList([
          ...utf8.encode('age-encryption.org/v1\n'),
          4,
          5,
          6,
        ]);
        when(
          mockRustApi.crateApiProfileCryptoDecryptBundleWithPassphrase(
            ciphertext: fakeAgeBytes,
            passphrase: 'any-passphrase',
          ),
        ).thenAnswer(
          (_) async => const BundleCryptoResult(
            error: BundleCryptoErrorKind.corrupt,
            message: 'bad header',
          ),
        );

        mockFilePicker.pickResult = FilePickerResult([
          PlatformFile(
            name: 'config.zip.age',
            size: fakeAgeBytes.length,
            bytes: fakeAgeBytes,
          ),
        ]);

        await expectLater(
          () => settingsService.importConfiguration(
            dialogTitle: 'Import Configuration',
            promptPassphrase: ({required previousAttemptFailed}) async =>
                'any-passphrase',
          ),
          throwsA(
            isA<EncryptedBundleException>().having(
              (e) => e.kind,
              'kind',
              EncryptedBundleFailure.corrupt,
            ),
          ),
        );
        expect(fakeKeyring.data, isEmpty);
      },
    );

    test(
      'importConfiguration legacy plaintext bundle with credentials imports without prompting',
      () async {
        final archive = Archive();
        final prefsBytes = utf8.encode(
          jsonEncode({
            'cluster_profiles': jsonEncode([
              {
                'name': 'legacy-cluster',
                'bootstrapServers': 'localhost:9092',
                'saslPassword': 'legacy-secret',
              },
            ]),
          }),
        );
        archive.addFile(
          ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
        );
        final plainZip = Uint8List.fromList(ZipEncoder().encode(archive));
        mockFilePicker.pickResult = FilePickerResult([
          PlatformFile(
            name: 'legacy.zip',
            size: plainZip.length,
            bytes: plainZip,
          ),
        ]);

        var prompted = false;
        final result = await settingsService.importConfiguration(
          dialogTitle: 'Import Configuration',
          promptPassphrase: ({required previousAttemptFailed}) async {
            prompted = true;
            return null;
          },
        );
        expect(prompted, isFalse);
        expect(result, isNotNull);
        final secrets = await getIt<SecureStorageService>().getClusterSecrets(
          'legacy-cluster',
        );
        expect(secrets['saslPassword'], 'legacy-secret');
      },
    );

    group('messageBufferLimit', () {
      test('defaults to 50,000 when unset', () async {
        await settingsService.loadMessageBufferLimit();
        expect(settingsService.messageBufferLimit.value, 50000);
      });

      test(
        'invalid stored value yields default without rewriting preference',
        () async {
          SharedPreferences.setMockInitialValues({'message_buffer_limit': 0});
          await settingsService.loadMessageBufferLimit();
          expect(settingsService.messageBufferLimit.value, 50000);
          var prefs = await SharedPreferences.getInstance();
          expect(prefs.getInt('message_buffer_limit'), 0);

          SharedPreferences.setMockInitialValues({
            'message_buffer_limit': 5000000,
          });
          await settingsService.loadMessageBufferLimit();
          expect(settingsService.messageBufferLimit.value, 50000);
          prefs = await SharedPreferences.getInstance();
          expect(prefs.getInt('message_buffer_limit'), 5000000);

          SharedPreferences.setMockInitialValues({
            'message_buffer_limit': 'not-an-int',
          });
          await settingsService.loadMessageBufferLimit();
          expect(settingsService.messageBufferLimit.value, 50000);
          prefs = await SharedPreferences.getInstance();
          expect(prefs.get('message_buffer_limit'), 'not-an-int');
        },
      );

      test(
        'setMessageBufferLimit persists valid values and rejects out-of-range',
        () async {
          await settingsService.setMessageBufferLimit(10000);
          expect(settingsService.messageBufferLimit.value, 10000);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getInt('message_buffer_limit'), 10000);

          await expectLater(
            () => settingsService.setMessageBufferLimit(999),
            throwsArgumentError,
          );
          await expectLater(
            () => settingsService.setMessageBufferLimit(1000001),
            throwsArgumentError,
          );
          expect(settingsService.messageBufferLimit.value, 10000);
        },
      );

      test(
        'parseMessageBufferLimit accepts 1,000..1,000,000 and rejects invalid',
        () {
          expect(SettingsService.parseMessageBufferLimit('1000'), 1000);
          expect(SettingsService.parseMessageBufferLimit(' 1000000 '), 1000000);
          expect(SettingsService.parseMessageBufferLimit('999'), isNull);
          expect(SettingsService.parseMessageBufferLimit('1000001'), isNull);
          expect(SettingsService.parseMessageBufferLimit('abc'), isNull);
          expect(SettingsService.parseMessageBufferLimit(''), isNull);
        },
      );

      test('importConfiguration reloads messageBufferLimit', () async {
        final archive = Archive();
        final prefsBytes = utf8.encode(
          jsonEncode({'message_buffer_limit': 25000}),
        );
        archive.addFile(
          ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
        );
        final zip = Uint8List.fromList(ZipEncoder().encode(archive));
        mockFilePicker.pickResult = FilePickerResult([
          PlatformFile(name: 'cfg.zip', size: zip.length, bytes: zip),
        ]);

        await settingsService.importConfiguration(
          dialogTitle: 'Import Configuration',
          promptPassphrase: ({required previousAttemptFailed}) async => null,
        );
        expect(settingsService.messageBufferLimit.value, 25000);
      });
    });

    group('IntSetting & defaultResultLimit', () {
      test(
        'readInt handles missing, wrong type, out-of-range, and boundaries',
        () async {
          SharedPreferences.setMockInitialValues({});
          var prefs = await SharedPreferences.getInstance();
          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.maxRunHistorySetting,
            ),
            30,
          );
          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.maxConcurrentLagQueriesSetting,
            ),
            5,
          );

          SharedPreferences.setMockInitialValues({
            SettingsService.maxConcurrentLagQueriesSetting.key: 'not-an-int',
            SettingsService.maxRunHistorySetting.key: -1,
            SettingsService.defaultResultLimitSetting.key: 100001,
          });
          prefs = await SharedPreferences.getInstance();
          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.maxConcurrentLagQueriesSetting,
            ),
            5,
          );
          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.maxRunHistorySetting,
            ),
            30,
          );
          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.defaultResultLimitSetting,
            ),
            200,
          );
          // Does not rewrite invalid stored value
          expect(
            prefs.get(SettingsService.defaultResultLimitSetting.key),
            100001,
          );

          SharedPreferences.setMockInitialValues({
            SettingsService.maxRunHistorySetting.key: 0,
            SettingsService.maxConcurrentLagQueriesSetting.key: 20,
            SettingsService.defaultResultLimitSetting.key: 1,
          });
          prefs = await SharedPreferences.getInstance();
          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.maxRunHistorySetting,
            ),
            0,
          );
          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.maxConcurrentLagQueriesSetting,
            ),
            20,
          );
          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.defaultResultLimitSetting,
            ),
            1,
          );
        },
      );

      test('parseInt validates range and rejects non-numeric text', () {
        expect(
          SettingsService.parseInt('0', SettingsService.maxRunHistorySetting),
          0,
        );
        expect(
          SettingsService.parseInt(
            ' 1000 ',
            SettingsService.maxRunHistorySetting,
          ),
          1000,
        );
        expect(
          SettingsService.parseInt(
            '1001',
            SettingsService.maxRunHistorySetting,
          ),
          isNull,
        );
        expect(
          SettingsService.parseInt(
            '0',
            SettingsService.maxConcurrentLagQueriesSetting,
          ),
          isNull,
        );
        expect(
          SettingsService.parseInt(
            'abc',
            SettingsService.defaultResultLimitSetting,
          ),
          isNull,
        );
      });

      test(
        'importConfiguration with invalid default_result_limit: 0 yields 200 and leaves stored value',
        () async {
          final archive = Archive();
          final prefsBytes = utf8.encode(
            jsonEncode({'default_result_limit': 0}),
          );
          archive.addFile(
            ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
          );
          final zip = Uint8List.fromList(ZipEncoder().encode(archive));
          mockFilePicker.pickResult = FilePickerResult([
            PlatformFile(name: 'cfg.zip', size: zip.length, bytes: zip),
          ]);

          await settingsService.importConfiguration(
            dialogTitle: 'Import Configuration',
            promptPassphrase: ({required previousAttemptFailed}) async => null,
          );
          expect(settingsService.defaultResultLimit.value, 200);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getInt('default_result_limit'), 0);
        },
      );

      test(
        'partitionSkewThresholdSetting clamps out-of-range stored 0 to 50 and resets to 50',
        () async {
          SharedPreferences.setMockInitialValues({
            SettingsService.partitionSkewThresholdSetting.key: 0,
          });
          final prefs = await SharedPreferences.getInstance();
          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.partitionSkewThresholdSetting,
            ),
            50,
          );
          expect(
            SettingsService.parseInt(
              '0',
              SettingsService.partitionSkewThresholdSetting,
            ),
            isNull,
          );
          expect(
            SettingsService.parseInt(
              '150',
              SettingsService.partitionSkewThresholdSetting,
            ),
            isNull,
          );
          expect(
            SettingsService.parseInt(
              '75',
              SettingsService.partitionSkewThresholdSetting,
            ),
            75,
          );

          await settingsService.writeInt(
            SettingsService.partitionSkewThresholdSetting,
            80,
          );
          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.partitionSkewThresholdSetting,
            ),
            80,
          );

          await settingsService.resetGeneralSettings();
          expect(
            prefs.getInt(SettingsService.partitionSkewThresholdSetting.key),
            50,
          );
        },
      );

      test(
        'analysisConfirmThresholdSetting and analysisHistoryPerTopicSetting defaults, bounds and reset',
        () async {
          SharedPreferences.setMockInitialValues({
            SettingsService.analysisConfirmThresholdSetting.key: 500,
            SettingsService.analysisHistoryPerTopicSetting.key: 200,
          });
          final prefs = await SharedPreferences.getInstance();

          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.analysisConfirmThresholdSetting,
            ),
            1000000,
          );
          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.analysisHistoryPerTopicSetting,
            ),
            10,
          );

          await settingsService.writeInt(
            SettingsService.analysisConfirmThresholdSetting,
            250000,
          );
          await settingsService.writeInt(
            SettingsService.analysisHistoryPerTopicSetting,
            0,
          );
          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.analysisConfirmThresholdSetting,
            ),
            250000,
          );
          expect(
            SettingsService.readInt(
              prefs,
              SettingsService.analysisHistoryPerTopicSetting,
            ),
            0,
          );

          await settingsService.resetGeneralSettings();
          expect(
            prefs.getInt(SettingsService.analysisConfirmThresholdSetting.key),
            1000000,
          );
          expect(
            prefs.getInt(SettingsService.analysisHistoryPerTopicSetting.key),
            10,
          );
        },
      );
    });
  });
}
