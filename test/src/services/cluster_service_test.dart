import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/secure_storage_service.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../rust/api/rust_mocks.mocks.dart';

class _FakeFlutterSecureStorage implements FlutterSecureStorage {
  final Map<String, String> data = {};
  bool Function(String key)? shouldFail;

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
    if (shouldFail?.call(key) ?? false) throw Exception('Keyring error');
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
    if (shouldFail?.call(key) ?? false) throw Exception('Keyring error');
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
    if (shouldFail?.call(key) ?? false) throw Exception('Keyring error');
    data.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stand-in for the Rust profile codec: it remembers whole profiles under a
/// reference, so anything the Dart persistence layer loses shows up as a lost
/// field. Which field names the codec writes is covered by the Rust tests in
/// `rust/src/api/json_path.rs`.
class _CodecStub {
  final Map<String, ClusterProfile> byRef = {};
  final List<String> serializedJson = [];
  final List<String> deserializedInput = [];
  int _next = 0;

  void register(MockKafkalyzerRustLibApi api) {
    when(
      api.crateApiJsonPathSerializeClusterProfile(profile: anyNamed('profile')),
    ).thenAnswer((invocation) async {
      final profile = invocation.namedArguments[#profile] as ClusterProfile;
      final ref = 'profile-${_next++}';
      byRef[ref] = profile;
      final json = jsonEncode({'ref': ref});
      serializedJson.add(json);
      return json;
    });

    when(
      api.crateApiJsonPathDeserializeClusterProfile(json: anyNamed('json')),
    ).thenAnswer((invocation) async {
      final json = invocation.namedArguments[#json] as String;
      deserializedInput.add(json);
      final ref = (jsonDecode(json) as Map<String, dynamic>)['ref'];
      return byRef[ref]!;
    });
  }
}

ClusterProfile fullProfile({String name = 'prod'}) => ClusterProfile(
  name: name,
  bootstrapServers: 'broker:9092',
  saslUsername: 'user',
  saslPassword: 'pass',
  mechanism: 'SCRAM-SHA-512',
  securityProtocol: 'SASL_SSL',
  schemaRegistryUrl: 'https://sr:8081',
  sslKeystoreLocation: '/ks',
  sslKeystorePassword: 'ksp',
  sslTruststoreLocation: '/ts',
  sslTruststorePassword: 'tsp',
  schemaRegistryUsername: 'sruser',
  schemaRegistryPassword: 'srpass',
  saslKerberosServiceName: 'kafka',
  saslKerberosKeytab: '/keytab',
  saslKerberosPrincipal: 'kafka/host@REALM',
  saslKerberosConf: '/krb5.conf',
  saslOauthbearerToken: 'oauth-token',
  sslPemCertificateLocation: '/cert.pem',
  sslPemKeyLocation: '/key.pem',
  sslPemKeyPassword: 'pempw',
);

/// The generated Dart class has no equality, so comparisons list every field.
List<Object?> fieldValues(ClusterProfile profile) => [
  profile.name,
  profile.bootstrapServers,
  profile.saslUsername,
  profile.saslPassword,
  profile.mechanism,
  profile.securityProtocol,
  profile.schemaRegistryUrl,
  profile.sslKeystoreLocation,
  profile.sslKeystorePassword,
  profile.sslTruststoreLocation,
  profile.sslTruststorePassword,
  profile.schemaRegistryUsername,
  profile.schemaRegistryPassword,
  profile.saslKerberosServiceName,
  profile.saslKerberosKeytab,
  profile.saslKerberosPrincipal,
  profile.saslKerberosConf,
  profile.saslOauthbearerToken,
  profile.sslPemCertificateLocation,
  profile.sslPemKeyLocation,
  profile.sslPemKeyPassword,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ClusterService service;
  late _FakeFlutterSecureStorage fakeKeyring;
  late _CodecStub codec;
  final mockApi = MockKafkalyzerRustLibApi();

  setUpAll(() {
    KafkalyzerRustLib.initMock(api: mockApi);
  });

  tearDownAll(() {
    KafkalyzerRustLib.dispose();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    reset(mockApi);
    codec = _CodecStub()..register(mockApi);
    fakeKeyring = _FakeFlutterSecureStorage();
    service = ClusterService(
      secureStorage: SecureStorageService(storage: fakeKeyring),
    );
  });

  group('ClusterService', () {
    test('loadClusters returns empty list when no data stored', () async {
      SharedPreferences.setMockInitialValues({});
      final clusters = await service.loadClusters();
      expect(clusters, isEmpty);
      expect(codec.deserializedInput, isEmpty);
    });

    test(
      'round trip keeps schema registry, Kerberos, OAuth and PEM fields',
      () async {
        await service.saveClusters([fullProfile()]);

        final loaded = await service.loadClusters();

        expect(fieldValues(loaded.single), fieldValues(fullProfile()));
        expect(loaded.single.schemaRegistryPassword, 'srpass');
        expect(loaded.single.saslKerberosKeytab, '/keytab');
        expect(loaded.single.saslOauthbearerToken, 'oauth-token');
        expect(loaded.single.sslPemKeyPassword, 'pempw');
      },
    );

    test(
      'saving one profile calls the codec once and stores one object',
      () async {
        await service.saveClusters([
          fullProfile(name: 'a'),
          fullProfile(name: 'b'),
        ]);

        final stored = (await SharedPreferences.getInstance()).getString(
          'cluster_profiles',
        );
        expect(jsonDecode(stored!), hasLength(2));
        expect(codec.serializedJson, hasLength(2));

        final reloaded = await service.loadClusters();
        expect(reloaded.map((c) => c.name), ['a', 'b']);
      },
    );

    test('stored text is handed to the codec unchanged', () async {
      const legacy =
          '[{"name":"old","bootstrapServers":"b:9092","securityProtocol":"PLAINTEXT"}]';
      SharedPreferences.setMockInitialValues({'cluster_profiles': legacy});

      await service.loadClusters();

      expect(
        codec.deserializedInput.single,
        legacy.substring(1, legacy.length - 1),
      );
    });

    test('editing one field keeps every other field', () async {
      final original = fullProfile();
      await service.saveClusters([original]);

      final stored = (await service.loadClusters()).single;
      final edited = stored.copyWith(bootstrapServers: 'new-broker:9092');
      await service.saveClusters([edited]);

      final reloaded = await service.loadClusters();
      final expected = fullProfile().copyWith(
        bootstrapServers: 'new-broker:9092',
      );
      expect(fieldValues(reloaded.single), fieldValues(expected));
    });

    test(
      'loadClusters throws StoredDataUnreadableException on json parse error',
      () async {
        SharedPreferences.setMockInitialValues({
          'cluster_profiles': 'INVALID_JSON',
        });

        await expectLater(
          () => service.loadClusters(),
          throwsA(isA<StoredDataUnreadableException>()),
        );
      },
    );

    test(
      'sanitizes sensitive credentials before writing to SharedPreferences and persists to SecureStorage',
      () async {
        final profile = fullProfile(name: 'secure-prod');
        await service.saveClusters([profile]);

        // Verify the profile serialized to disk (via codec stub) has null passwords
        final serializedProfile = codec.byRef.values.last;
        expect(serializedProfile.saslPassword, isNull);
        expect(serializedProfile.schemaRegistryPassword, isNull);
        expect(serializedProfile.sslKeystorePassword, isNull);
        expect(serializedProfile.sslTruststorePassword, isNull);
        expect(serializedProfile.sslPemKeyPassword, isNull);
        expect(serializedProfile.saslOauthbearerToken, isNull);

        // But loading it back restores all secrets
        final reloaded = (await service.loadClusters()).firstWhere(
          (c) => c.name == 'secure-prod',
        );
        expect(reloaded.saslPassword, 'pass');
        expect(reloaded.schemaRegistryPassword, 'srpass');
        expect(reloaded.sslKeystorePassword, 'ksp');
        expect(reloaded.sslTruststorePassword, 'tsp');
        expect(reloaded.sslPemKeyPassword, 'pempw');
        expect(reloaded.saslOauthbearerToken, 'oauth-token');
      },
    );

    test(
      'migrates legacy plaintext cluster credentials to OS keyring on first load',
      () async {
        // Prepare legacy profile stored directly with plaintext passwords
        final legacyProfile = fullProfile(name: 'legacy-prod');
        final ref = 'legacy-ref-0';
        codec.byRef[ref] = legacyProfile;

        final legacyJson = jsonEncode([
          {'ref': ref},
        ]);
        SharedPreferences.setMockInitialValues({
          'cluster_profiles': legacyJson,
          // 'credentials_migrated_to_keyring_v1' is not set
        });

        final loaded = await service.loadClusters();
        expect(loaded.single.saslPassword, 'pass');
        expect(loaded.single.schemaRegistryPassword, 'srpass');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('credentials_migrated_to_keyring_v1'), isTrue);

        // Verify that after migration, the serialized copy on disk has scrubbed passwords
        final sanitizedStored = codec.byRef.values.last;
        expect(sanitizedStored.saslPassword, isNull);
        expect(sanitizedStored.schemaRegistryPassword, isNull);
      },
    );

    test(
      'migration keeps plaintext and does not set flag when keyring write throws',
      () async {
        fakeKeyring.shouldFail = (_) => true;
        final legacyProfile = fullProfile(name: 'legacy-fail');
        codec.byRef['legacy-fail-ref'] = legacyProfile;
        final legacyJson = jsonEncode([
          {'ref': 'legacy-fail-ref'},
        ]);
        SharedPreferences.setMockInitialValues({
          'cluster_profiles': legacyJson,
        });

        final loaded = await service.loadClusters();
        expect(loaded.single.saslPassword, 'pass');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('cluster_profiles'), legacyJson);
        expect(prefs.getBool('credentials_migrated_to_keyring_v1'), isNull);
      },
    );

    test(
      'migration strips plaintext only for profiles whose keyring write succeeded',
      () async {
        // Note: SecureStorageService has sticky fallback, so test per-profile
        // by failing on B's key (A is processed first).
        fakeKeyring.shouldFail = (key) => key.contains('cluster_B_');
        codec.byRef['ref-A'] = fullProfile(name: 'A');
        codec.byRef['ref-B'] = fullProfile(name: 'B');
        SharedPreferences.setMockInitialValues({
          'cluster_profiles': jsonEncode([
            {'ref': 'ref-A'},
            {'ref': 'ref-B'},
          ]),
        });

        final loaded = await service.loadClusters();
        expect(loaded.length, 2);
        expect(loaded[0].saslPassword, 'pass');
        expect(loaded[1].saslPassword, 'pass');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('credentials_migrated_to_keyring_v1'), isNull);
        final stored = jsonDecode(prefs.getString('cluster_profiles')!) as List;
        final storedA = codec.byRef[(stored[0] as Map)['ref']]!;
        final storedB = codec.byRef[(stored[1] as Map)['ref']]!;
        expect(storedA.saslPassword, isNull);
        expect(storedB.saslPassword, 'pass');
      },
    );

    test(
      'rename moves secrets and removes old keys only when writes succeed',
      () async {
        await service.saveClusters([fullProfile(name: 'Prod')]);
        expect(fakeKeyring.data['cluster_Prod_saslPassword'], 'pass');

        final renamed = fullProfile(name: 'Prod EU');
        await service.saveClusters([renamed]);
        expect(fakeKeyring.data['cluster_Prod EU_saslPassword'], 'pass');
        expect(
          fakeKeyring.data.containsKey('cluster_Prod_saslPassword'),
          isFalse,
        );

        // Now simulate keyring failure on rename
        fakeKeyring.shouldFail = (_) => true;
        await service.saveClusters([fullProfile(name: 'Prod US')]);
        expect(fakeKeyring.data['cluster_Prod EU_saslPassword'], 'pass');

        final prefs = await SharedPreferences.getInstance();
        final stored = jsonDecode(prefs.getString('cluster_profiles')!) as List;
        final storedProfile = codec.byRef[(stored.single as Map)['ref']]!;
        expect(storedProfile.saslPassword, isNull);
      },
    );

    test('preserves corrupt entry across load and saveClusters', () async {
      codec.byRef['ref-1'] = fullProfile(name: 'One');
      codec.byRef['ref-3'] = fullProfile(name: 'Three');
      SharedPreferences.setMockInitialValues({
        'cluster_profiles': jsonEncode([
          {'ref': 'ref-1'},
          {'corrupt': true},
          {'ref': 'ref-3'},
        ]),
      });

      final loaded = await service.loadClusters();
      expect(loaded.map((c) => c.name), ['One', 'Three']);
      expect(service.storeStatus.isPartiallyUnreadable, isTrue);
      expect(service.storeStatus.unreadableCount, 1);

      await service.saveClusters([
        ...loaded,
        const ClusterProfile(name: 'Four', bootstrapServers: 'b:9092'),
      ]);
      final prefs = await SharedPreferences.getInstance();
      final rawAfter = jsonDecode(prefs.getString('cluster_profiles')!) as List;
      expect(rawAfter.length, 4);
      expect(rawAfter.last, {'corrupt': true});
    });

    test(
      'truncated JSON throws on load and save, keeps raw intact, writes backup',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'kafkalyzer_cs_bkp_',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (call) async => tempDir.path,
            );
        try {
          const rawBroken = '[{"ref":"ref-1"';
          SharedPreferences.setMockInitialValues({
            'cluster_profiles': rawBroken,
          });

          await expectLater(
            () => service.loadClusters(),
            throwsA(isA<StoredDataUnreadableException>()),
          );
          expect(service.storeStatus.isUnreadable, isTrue);
          expect(service.storeStatus.backupPath, isNotNull);
          expect(
            File(service.storeStatus.backupPath!).readAsStringSync(),
            rawBroken,
          );

          await expectLater(
            () => service.saveClusters([fullProfile(name: 'New')]),
            throwsA(isA<StoredDataUnreadableException>()),
          );
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('cluster_profiles'), rawBroken);
        } finally {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('plugins.flutter.io/path_provider'),
                null,
              );
          tempDir.deleteSync(recursive: true);
        }
      },
    );
  });

  group('normalizeProfileName & mergeImportedProfiles', () {
    test('normalizes case and whitespace', () {
      expect(normalizeProfileName('  Prod  '), 'prod');
    });

    test(
      'handles replace, rename, skip, cancel, and intra-bundle duplicates',
      () async {
        final existing = [
          const ClusterProfile(name: 'Prod', bootstrapServers: 'old:9092'),
        ];
        final imported = [
          const ClusterProfile(name: ' prod ', bootstrapServers: 'new1:9092'),
          const ClusterProfile(name: 'Prod', bootstrapServers: 'new2:9092'),
          const ClusterProfile(name: 'PROD', bootstrapServers: 'new3:9092'),
          const ClusterProfile(name: 'Staging', bootstrapServers: 'stg:9092'),
        ];

        final suggestions = <String>[];
        var callIdx = 0;
        final res = await mergeImportedProfiles(existing, imported, (
          item,
          suggested,
        ) async {
          suggestions.add(suggested);
          callIdx++;
          if (callIdx == 1) return const ImportConflictChoice.replace();
          if (callIdx == 2) return ImportConflictChoice.rename(suggested);
          return const ImportConflictChoice.skip();
        });

        expect(res, isNotNull);
        expect(suggestions, [
          'prod (imported)',
          'Prod (imported)',
          'PROD (imported 2)',
        ]);
        expect(res!.clusters.map((c) => c.name), [
          ' prod ',
          'Prod (imported)',
          'Staging',
        ]);
        expect(res.summary.imported, 1);
        expect(res.summary.replaced, 1);
        expect(res.summary.renamed, 1);
        expect(res.summary.skipped, 1);

        final cancelled = await mergeImportedProfiles(
          existing,
          imported,
          (_, _) async => null,
        );
        expect(cancelled, isNull);
      },
    );
  });
}
