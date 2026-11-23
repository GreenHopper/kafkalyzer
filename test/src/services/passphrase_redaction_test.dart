import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/profile_crypto.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/encrypted_bundle.dart';
import 'package:kafkalyzer/src/services/secure_storage_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:logger/logger.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../rust/api/rust_mocks.mocks.dart';

class _CaptureLogOutput extends LogOutput {
  final List<String> lines;
  _CaptureLogOutput(this.lines);

  @override
  void output(OutputEvent event) {
    lines.addAll(event.lines);
  }
}

class _MemorySecureStorage implements FlutterSecureStorage {
  final Map<String, String> data = {};

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
  }) async => data[key];

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
    data.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFilePicker extends FilePickerPlatform {
  String? savePath;
  FilePickerResult? pickResult;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async => savePath;

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
  }) async => pickResult;
}

class _StubScriptRepository extends ScriptRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secretPassphrase = 'super-secret-passphrase-9999';

  test(
    'passphrase never appears in debugPrint, Logger, SharedPreferences, or keyring',
    () async {
      final mockRustApi = MockKafkalyzerRustLibApi();
      KafkalyzerRustLib.initMock(api: mockRustApi);
      addTearDown(KafkalyzerRustLib.dispose);

      when(
        mockRustApi.crateApiJsonPathSerializeClusterProfile(
          profile: anyNamed('profile'),
        ),
      ).thenAnswer((inv) async {
        final profile = inv.namedArguments[#profile] as ClusterProfile;
        return jsonEncode({
          'name': profile.name,
          'bootstrapServers': profile.bootstrapServers,
        });
      });

      final capturedLogs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) capturedLogs.add(message);
      };
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });

      final logger = Logger(output: _CaptureLogOutput(capturedLogs));
      final memoryKeyring = _MemorySecureStorage();
      final secureStorage = SecureStorageService(
        storage: memoryKeyring,
        logger: logger,
      );

      await getIt.reset();
      getIt.registerSingleton<SecureStorageService>(secureStorage);
      getIt.registerSingleton<ClusterService>(
        ClusterService(secureStorage: secureStorage),
      );
      getIt.registerSingleton<ScriptRepository>(_StubScriptRepository());

      final tempDir = Directory.systemTemp
          .createTempSync('kafkalyzer_redaction_test')
          .path;
      addTearDown(() {
        try {
          Directory(tempDir).deleteSync(recursive: true);
        } catch (_) {}
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async => tempDir,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              null,
            );
      });

      SharedPreferences.setMockInitialValues({});
      final fakePicker = _FakeFilePicker();
      final originalPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = fakePicker;
      addTearDown(() {
        FilePickerPlatform.instance = originalPicker;
      });

      final settingsService = SettingsService();
      final fakeAgeBytes = Uint8List.fromList([
        ...utf8.encode('age-encryption.org/v1\n'),
        1,
        2,
        3,
      ]);

      // 1. Encrypted export
      when(
        mockRustApi.crateApiProfileCryptoEncryptBundleWithPassphrase(
          plaintext: anyNamed('plaintext'),
          passphrase: secretPassphrase,
        ),
      ).thenAnswer((_) async => BundleCryptoResult(data: fakeAgeBytes));
      fakePicker.savePath = p.join(tempDir, 'out.zip.age');
      await settingsService.exportConfiguration(
        dialogTitle: 'Export Configuration',
        encryptionPassphrase: secretPassphrase,
      );

      // 2. Successful encrypted import
      final archive = Archive();
      final prefsBytes = utf8.encode(jsonEncode({'sample_pref': 'ok'}));
      archive.addFile(
        ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
      );
      final plainZip = Uint8List.fromList(ZipEncoder().encode(archive));
      when(
        mockRustApi.crateApiProfileCryptoDecryptBundleWithPassphrase(
          ciphertext: fakeAgeBytes,
          passphrase: secretPassphrase,
        ),
      ).thenAnswer((_) async => BundleCryptoResult(data: plainZip));
      fakePicker.pickResult = FilePickerResult([
        PlatformFile(
          name: 'out.zip.age',
          size: fakeAgeBytes.length,
          bytes: fakeAgeBytes,
        ),
      ]);
      await settingsService.importConfiguration(
        dialogTitle: 'Import Configuration',
        promptPassphrase: ({required previousAttemptFailed}) async =>
            secretPassphrase,
      );

      // 3. Wrong-passphrase import then cancel
      when(
        mockRustApi.crateApiProfileCryptoDecryptBundleWithPassphrase(
          ciphertext: fakeAgeBytes,
          passphrase: secretPassphrase,
        ),
      ).thenAnswer(
        (_) async => const BundleCryptoResult(
          error: BundleCryptoErrorKind.wrongPassphrase,
        ),
      );
      var attempts = 0;
      await settingsService.importConfiguration(
        dialogTitle: 'Import Configuration',
        promptPassphrase: ({required previousAttemptFailed}) async {
          attempts++;
          return attempts == 1 ? secretPassphrase : null;
        },
      );

      // 4. Failed encryption
      when(
        mockRustApi.crateApiProfileCryptoEncryptBundleWithPassphrase(
          plaintext: anyNamed('plaintext'),
          passphrase: secretPassphrase,
        ),
      ).thenAnswer(
        (_) async => const BundleCryptoResult(
          error: BundleCryptoErrorKind.internal,
          message: 'internal failure',
        ),
      );
      await expectLater(
        () => settingsService.exportConfiguration(
          dialogTitle: 'Export Configuration',
          encryptionPassphrase: secretPassphrase,
        ),
        throwsA(isA<EncryptedBundleException>()),
      );

      for (final line in capturedLogs) {
        expect(line, isNot(contains(secretPassphrase)));
      }

      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        expect(key, isNot(contains(secretPassphrase)));
        expect(prefs.get(key).toString(), isNot(contains(secretPassphrase)));
      }

      for (final entry in memoryKeyring.data.entries) {
        expect(entry.key, isNot(contains(secretPassphrase)));
        expect(entry.value, isNot(contains(secretPassphrase)));
      }
    },
  );
}
