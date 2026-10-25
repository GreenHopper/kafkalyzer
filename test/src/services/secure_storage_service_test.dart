import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/services/secure_storage_service.dart';

class FakeFlutterSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};
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
    if (throwOnOperation) throw Exception('Keyring unavailable');
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
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
    if (throwOnOperation) throw Exception('Keyring unavailable');
    return _data[key];
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
    if (throwOnOperation) throw Exception('Keyring unavailable');
    _data.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SecureStorageService', () {
    late FakeFlutterSecureStorage fakeStorage;
    late SecureStorageService service;

    setUp(() {
      fakeStorage = FakeFlutterSecureStorage();
      service = SecureStorageService(storage: fakeStorage);
    });

    test('writes and reads single secret', () async {
      await service.write('test_key', 'my_secret_token');
      final val = await service.read('test_key');
      expect(val, 'my_secret_token');
    });

    test('deletes secret successfully', () async {
      await service.write('temp_key', 'temp_val');
      expect(await service.read('temp_key'), 'temp_val');

      await service.delete('temp_key');
      expect(await service.read('temp_key'), isNull);
    });

    test(
      'saves and retrieves cluster secrets scoped by cluster name',
      () async {
        final secrets = {
          'saslPassword': 'secret_password_123',
          'schemaRegistryPassword': 'sr_secret_456',
          'sslKeystorePassword': 'ks_password_789',
        };

        await service.saveClusterSecrets('prod-cluster', secrets);

        final retrieved = await service.getClusterSecrets('prod-cluster');
        expect(retrieved['saslPassword'], 'secret_password_123');
        expect(retrieved['schemaRegistryPassword'], 'sr_secret_456');
        expect(retrieved['sslKeystorePassword'], 'ks_password_789');
        expect(retrieved['sslPemKeyPassword'], isNull);

        // Other cluster returns null
        final other = await service.getClusterSecrets('staging-cluster');
        expect(other['saslPassword'], isNull);
      },
    );

    test(
      'deleteClusterSecrets removes all secrets for specified cluster',
      () async {
        await service.saveClusterSecrets('cluster-to-delete', {
          'saslPassword': 'pwd',
          'saslOauthbearerToken': 'token123',
        });

        expect(
          (await service.getClusterSecrets(
            'cluster-to-delete',
          ))['saslPassword'],
          'pwd',
        );

        await service.deleteClusterSecrets('cluster-to-delete');
        final empty = await service.getClusterSecrets('cluster-to-delete');
        expect(empty['saslPassword'], isNull);
        expect(empty['saslOauthbearerToken'], isNull);
      },
    );

    test(
      'falls back gracefully to in-memory storage when OS keyring throws error',
      () async {
        fakeStorage.throwOnOperation = true;

        // Should not throw
        await service.write('fallback_key', 'fallback_secret');
        final val = await service.read('fallback_key');
        expect(val, 'fallback_secret');
      },
    );
  });
}
