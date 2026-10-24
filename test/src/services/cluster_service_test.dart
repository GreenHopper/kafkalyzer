import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../rust/api/rust_mocks.mocks.dart';

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
    service = ClusterService();
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

    test('loadClusters returns empty list on json parse error', () async {
      SharedPreferences.setMockInitialValues({
        'cluster_profiles': 'INVALID_JSON',
      });

      final clusters = await service.loadClusters();
      expect(clusters, isEmpty);
    });
  });
}
