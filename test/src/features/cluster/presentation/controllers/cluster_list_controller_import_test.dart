import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
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
      return ClusterProfile(
        name: (m['name'] as String?) ?? '',
        bootstrapServers:
            (m['bootstrapServers'] as String?) ?? 'localhost:9092',
        saslPassword: m['saslPassword'] as String?,
        saslOauthbearerToken: m['saslOauthbearerToken'] as String?,
        sslPemKeyPassword: m['sslPemKeyPassword'] as String?,
        schemaRegistryPassword: m['schemaRegistryPassword'] as String?,
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
    'exportClustersZip and exportClusters scrub secrets by default and include them on opt-in',
    () async {
      const profileWithSecrets = ClusterProfile(
        name: 'AuthCluster',
        bootstrapServers: 'broker:9093',
        saslPassword: 'sasl-secret',
        saslOauthbearerToken: 'oauth-secret',
        sslPemKeyPassword: 'pem-secret',
        schemaRegistryPassword: 'sr-secret',
      );

      // Default export scrubs all secrets.
      final defaultJson = await controller.exportClusters([profileWithSecrets]);
      expect(defaultJson, isNot(contains('sasl-secret')));
      expect(defaultJson, isNot(contains('oauth-secret')));
      expect(defaultJson, isNot(contains('pem-secret')));
      expect(defaultJson, isNot(contains('sr-secret')));

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

      // Opt-in export includes all secrets.
      final optInJson = await controller.exportClusters([
        profileWithSecrets,
      ], includeSecrets: true);
      expect(optInJson, contains('sasl-secret'));
      expect(optInJson, contains('oauth-secret'));
      expect(optInJson, contains('pem-secret'));
      expect(optInJson, contains('sr-secret'));

      final optInZip = await controller.exportClustersZip([
        profileWithSecrets,
      ], includeSecrets: true);
      final optInArchive = ZipDecoder().decodeBytes(optInZip);
      final optInClustersJson = utf8.decode(
        optInArchive.findFile('clusters.json')!.content as List<int>,
      );
      expect(optInClustersJson, contains('sasl-secret'));
      expect(optInClustersJson, contains('oauth-secret'));
      expect(optInClustersJson, contains('pem-secret'));
      expect(optInClustersJson, contains('sr-secret'));
    },
  );
}
