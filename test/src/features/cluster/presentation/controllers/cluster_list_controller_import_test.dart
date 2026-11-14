import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/profile_crypto.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/utils/archive_safety.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;

import '../../../../rust/api/rust_mocks.mocks.dart';

class _FakeClusterService extends ClusterService {
  List<ClusterProfile> stored;

  _FakeClusterService(this.stored);

  @override
  Future<List<ClusterProfile>> loadClusters() async => List.from(stored);

  @override
  Future<bool> saveClusters(List<ClusterProfile> clusters) async {
    stored = List.from(clusters);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockRustApi = MockKafkalyzerRustLibApi();

  setUpAll(() {
    KafkalyzerRustLib.initMock(api: mockRustApi);
  });

  tearDownAll(() {
    KafkalyzerRustLib.dispose();
  });

  late Directory tempRoot;
  late Directory docsDir;
  late _FakeClusterService fakeService;
  late ClusterListController controller;

  setUp(() async {
    await getIt.reset();
    when(
      mockRustApi.crateApiJsonPathSerializeClusterProfile(
        profile: anyNamed('profile'),
      ),
    ).thenAnswer((inv) async {
      final profile = inv.namedArguments[#profile] as ClusterProfile;
      return jsonEncode({
        'name': profile.name,
        'bootstrapServers': profile.bootstrapServers,
        'tlsVerification': profile.tlsVerification.name,
        if (profile.saslPassword != null) 'saslPassword': profile.saslPassword,
        if (profile.saslOauthbearerToken != null)
          'saslOauthbearerToken': profile.saslOauthbearerToken,
        if (profile.sslPemKeyPassword != null)
          'sslPemKeyPassword': profile.sslPemKeyPassword,
        if (profile.schemaRegistryPassword != null)
          'schemaRegistryPassword': profile.schemaRegistryPassword,
      });
    });
    when(
      mockRustApi.crateApiJsonPathDeserializeClusterProfile(
        json: anyNamed('json'),
      ),
    ).thenAnswer((inv) async {
      final m = jsonDecode(inv.namedArguments[#json] as String) as Map;
      final tlsRaw = m['tlsVerification'] as String?;
      final tlsVerification = TlsVerification.values.firstWhere(
        (v) => v.name == tlsRaw,
        orElse: () => TlsVerification.unreviewed,
      );
      return ClusterProfile(
        name: (m['name'] as String?) ?? '',
        bootstrapServers:
            (m['bootstrapServers'] as String?) ?? 'localhost:9092',
        saslPassword: m['saslPassword'] as String?,
        saslOauthbearerToken: m['saslOauthbearerToken'] as String?,
        sslPemKeyPassword: m['sslPemKeyPassword'] as String?,
        schemaRegistryPassword: m['schemaRegistryPassword'] as String?,
        tlsVerification: tlsVerification,
      );
    });
    tempRoot = Directory.systemTemp.createTempSync(
      'kafkalyzer_cluster_import_',
    );
    docsDir = Directory(p.join(tempRoot.path, 'docs'))..createSync();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async {
            if (call.method == 'getApplicationDocumentsDirectory' ||
                call.method == 'getApplicationSupportDirectory') {
              return docsDir.path;
            }
            return null;
          },
        );

    final initial = [
      const ClusterProfile(
        name: 'Existing',
        bootstrapServers: 'localhost:9092',
        tlsVerification: TlsVerification.enabled,
      ),
    ];
    fakeService = _FakeClusterService(initial);
    getIt.registerSingleton<ClusterService>(fakeService);

    controller = ClusterListController();
    await Future.delayed(Duration.zero);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  test(
    'rejects zip with ../evil.txt without writing files or changing profiles',
    () async {
      final goodBytes = utf8.encode('keystore');
      final evilBytes = utf8.encode('evil');
      final archive = Archive()
        ..addFile(ArchiveFile('keystore.jks', goodBytes.length, goodBytes))
        ..addFile(ArchiveFile('../evil.txt', evilBytes.length, evilBytes));
      final zipBytes = ZipEncoder().encode(archive);

      await expectLater(
        () => controller.importClustersZip(zipBytes),
        throwsA(
          isA<UnsafeArchiveEntryException>().having(
            (e) => e.entryName,
            'entryName',
            '../evil.txt',
          ),
        ),
      );

      expect(File(p.join(docsDir.path, 'evil.txt')).existsSync(), isFalse);
      expect(
        File(
          p.join(docsDir.path, 'shared_preferences', 'keystore.jks'),
        ).existsSync(),
        isFalse,
      );
      expect(controller.clusters.map((c) => c.name), ['Existing']);
      expect(fakeService.stored.map((c) => c.name), ['Existing']);
    },
  );

  test(
    'rejects zip with absolute entry /tmp/evil.txt without writing files or changing profiles',
    () async {
      final goodBytes = utf8.encode('keystore');
      final evilBytes = utf8.encode('evil');
      final archive = Archive()
        ..addFile(ArchiveFile('keystore.jks', goodBytes.length, goodBytes))
        ..addFile(ArchiveFile('/tmp/evil.txt', evilBytes.length, evilBytes));
      final zipBytes = ZipEncoder().encode(archive);

      await expectLater(
        () => controller.importClustersZip(zipBytes),
        throwsA(
          isA<UnsafeArchiveEntryException>().having(
            (e) => e.entryName,
            'entryName',
            '/tmp/evil.txt',
          ),
        ),
      );

      expect(
        File(
          p.join(docsDir.path, 'shared_preferences', 'keystore.jks'),
        ).existsSync(),
        isFalse,
      );
      expect(controller.clusters.map((c) => c.name), ['Existing']);
      expect(fakeService.stored.map((c) => c.name), ['Existing']);
    },
  );

  test(
    'conflicting import with skip leaves existing profile and secrets unchanged',
    () async {
      fakeService.stored = [
        const ClusterProfile(
          name: 'Prod',
          bootstrapServers: 'old-broker:9092',
          saslPassword: 'existing-secret-password',
          tlsVerification: TlsVerification.enabled,
        ),
      ];
      await controller.loadClusters();

      final importedJson = jsonEncode([
        {
          'name': ' prod ',
          'bootstrapServers': 'new-broker:9092',
          'saslPassword': 'new-secret-password',
        },
      ]);

      final summary = await controller.importClusters(
        importedJson,
        onConflict: (_, _) async => const ImportConflictChoice.skip(),
      );

      expect(summary?.skipped, 1);
      expect(summary?.replaced, 0);
      expect(controller.clusters, hasLength(1));
      expect(controller.clusters.first.name, 'Prod');
      expect(controller.clusters.first.bootstrapServers, 'old-broker:9092');
      expect(
        controller.clusters.first.saslPassword,
        'existing-secret-password',
      );
    },
  );

  test(
    'exportClustersZip scrubs secrets by default, encrypts with secrets when passphrase given, and exportClusters never includes secrets',
    () async {
      const profileWithSecrets = ClusterProfile(
        name: 'AuthCluster',
        bootstrapServers: 'broker:9093',
        saslPassword: 'sasl-secret',
        saslOauthbearerToken: 'oauth-secret',
        sslPemKeyPassword: 'pem-secret',
        schemaRegistryPassword: 'sr-secret',
        tlsVerification: TlsVerification.enabled,
      );

      // JSON export never contains secrets.
      final defaultJson = await controller.exportClusters([profileWithSecrets]);
      expect(defaultJson, isNot(contains('sasl-secret')));
      expect(defaultJson, isNot(contains('oauth-secret')));
      expect(defaultJson, isNot(contains('pem-secret')));
      expect(defaultJson, isNot(contains('sr-secret')));

      // Default ZIP export scrubs all secrets.
      final defaultZip = await controller.exportClustersZip([
        profileWithSecrets,
      ]);
      final defaultArchive = ZipDecoder().decodeBytes(defaultZip);
      final defaultClustersJson = utf8.decode(
        defaultArchive.findFile('clusters.json')!.content as List<int>,
      );
      expect(defaultClustersJson, isNot(contains('sasl-secret')));
      expect(defaultClustersJson, isNot(contains('oauth-secret')));
      expect(defaultClustersJson, isNot(contains('pem-secret')));
      expect(defaultClustersJson, isNot(contains('sr-secret')));

      // Encrypted ZIP export passes ZIP with secrets to bridge and returns encrypted bytes.
      List<int>? capturedPlaintext;
      final fakeEncrypted = Uint8List.fromList([
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
        return BundleCryptoResult(data: fakeEncrypted);
      });

      final optInZip = await controller.exportClustersZip([
        profileWithSecrets,
      ], encryptionPassphrase: 'correct-horse-battery');
      expect(optInZip, fakeEncrypted);
      expect(capturedPlaintext, isNotNull);

      final optInArchive = ZipDecoder().decodeBytes(capturedPlaintext!);
      final optInClustersJson = utf8.decode(
        optInArchive.findFile('clusters.json')!.content as List<int>,
      );
      expect(optInClustersJson, contains('sasl-secret'));
      expect(optInClustersJson, contains('oauth-secret'));
      expect(optInClustersJson, contains('pem-secret'));
      expect(optInClustersJson, contains('sr-secret'));
    },
  );

  test('ZIP export and import preserves tlsVerification', () async {
    final disabledProfile = const ClusterProfile(
      name: 'Insecure',
      bootstrapServers: 'broker:9093',
      tlsVerification: TlsVerification.disabled,
    );
    final controller = ClusterListController();
    final zipBytes = await controller.exportClustersZip([disabledProfile]);

    final target = ClusterListController();
    final summary = await target.importClustersZip(
      zipBytes,
      onConflict: (_, _) async => const ImportConflictChoice.replace(),
    );
    expect(summary, isNotNull);
    final imported = target.clusters.firstWhere((c) => c.name == 'Insecure');
    expect(imported.tlsVerification, TlsVerification.disabled);
  });
}
