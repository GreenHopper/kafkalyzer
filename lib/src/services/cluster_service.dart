import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/json_path.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/secure_storage_service.dart';

class ClusterService {
  static const String _storageKey = 'cluster_profiles';
  static const String _migratedKey = 'credentials_migrated_to_keyring_v1';

  final SecureStorageService _storage;

  ClusterService({SecureStorageService? secureStorage})
    : _storage =
          secureStorage ??
          (getIt.isRegistered<SecureStorageService>()
              ? getIt<SecureStorageService>()
              : SecureStorageService());

  Future<List<ClusterProfile>> loadClusters() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString == null) {
      return [];
    }
    final isMigrated = prefs.getBool(_migratedKey) ?? false;
    bool needsResave = false;

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final clusters = <ClusterProfile>[];
      for (final entry in jsonList) {
        final profile = await deserializeClusterProfile(
          json: jsonEncode(entry),
        );

        if (!isMigrated) {
          // Check for plaintext secrets that need migration
          final plaintextSecrets = {
            'saslPassword': profile.saslPassword,
            'schemaRegistryPassword': profile.schemaRegistryPassword,
            'sslKeystorePassword': profile.sslKeystorePassword,
            'sslTruststorePassword': profile.sslTruststorePassword,
            'sslPemKeyPassword': profile.sslPemKeyPassword,
            'saslOauthbearerToken': profile.saslOauthbearerToken,
          };
          final hasPlaintext = plaintextSecrets.values.any(
            (v) => v != null && v.isNotEmpty,
          );
          if (hasPlaintext) {
            await _storage.saveClusterSecrets(profile.name, plaintextSecrets);
            needsResave = true;
          }
        }

        final secrets = await _storage.getClusterSecrets(profile.name);
        clusters.add(profile.withSecrets(secrets));
      }

      if (!isMigrated) {
        if (needsResave) {
          final encoded = <String>[];
          for (final c in clusters) {
            encoded.add(await serializeClusterProfile(profile: c.sanitized()));
          }
          await prefs.setString(_storageKey, '[${encoded.join(',')}]');
        }
        await prefs.setBool(_migratedKey, true);
      }

      return clusters;
    } catch (e) {
      // Return empty or throw, for now empty
      return [];
    }
  }

  Future<void> saveClusters(List<ClusterProfile> clusters) async {
    final prefs = await SharedPreferences.getInstance();
    final currentNames = <String>{};

    for (final cluster in clusters) {
      currentNames.add(cluster.name);
      final secrets = {
        'saslPassword': cluster.saslPassword,
        'schemaRegistryPassword': cluster.schemaRegistryPassword,
        'sslKeystorePassword': cluster.sslKeystorePassword,
        'sslTruststorePassword': cluster.sslTruststorePassword,
        'sslPemKeyPassword': cluster.sslPemKeyPassword,
        'saslOauthbearerToken': cluster.saslOauthbearerToken,
      };
      await _storage.saveClusterSecrets(cluster.name, secrets);
    }

    // Clean up removed clusters from secure storage
    final existingJson = prefs.getString(_storageKey);
    if (existingJson != null) {
      try {
        final List<dynamic> oldList = jsonDecode(existingJson);
        for (final entry in oldList) {
          final oldProfile = await deserializeClusterProfile(
            json: jsonEncode(entry),
          );
          if (!currentNames.contains(oldProfile.name)) {
            await _storage.deleteClusterSecrets(oldProfile.name);
          }
        }
      } catch (_) {}
    }

    // The Rust codec owns the field set, so a profile field added later is
    // persisted without touching Dart.
    final encoded = <String>[];
    for (final cluster in clusters) {
      encoded.add(await serializeClusterProfile(profile: cluster.sanitized()));
    }
    await prefs.setString(_storageKey, '[${encoded.join(',')}]');
    await prefs.setBool(_migratedKey, true);
  }
}

extension ClusterProfileExtension on ClusterProfile {
  ClusterProfile sanitized() {
    return ClusterProfile(
      name: name,
      bootstrapServers: bootstrapServers,
      saslUsername: saslUsername,
      saslPassword: null,
      mechanism: mechanism,
      securityProtocol: securityProtocol,
      schemaRegistryUrl: schemaRegistryUrl,
      sslKeystoreLocation: sslKeystoreLocation,
      sslKeystorePassword: null,
      sslTruststoreLocation: sslTruststoreLocation,
      sslTruststorePassword: null,
      schemaRegistryUsername: schemaRegistryUsername,
      schemaRegistryPassword: null,
      saslKerberosServiceName: saslKerberosServiceName,
      saslKerberosKeytab: saslKerberosKeytab,
      saslKerberosPrincipal: saslKerberosPrincipal,
      saslKerberosConf: saslKerberosConf,
      saslOauthbearerToken: null,
      sslPemCertificateLocation: sslPemCertificateLocation,
      sslPemKeyLocation: sslPemKeyLocation,
      sslPemKeyPassword: null,
    );
  }

  ClusterProfile withSecrets(Map<String, String?> secrets) {
    return ClusterProfile(
      name: name,
      bootstrapServers: bootstrapServers,
      saslUsername: saslUsername,
      saslPassword: secrets['saslPassword'] ?? saslPassword,
      mechanism: mechanism,
      securityProtocol: securityProtocol,
      schemaRegistryUrl: schemaRegistryUrl,
      sslKeystoreLocation: sslKeystoreLocation,
      sslKeystorePassword:
          secrets['sslKeystorePassword'] ?? sslKeystorePassword,
      sslTruststoreLocation: sslTruststoreLocation,
      sslTruststorePassword:
          secrets['sslTruststorePassword'] ?? sslTruststorePassword,
      schemaRegistryUsername: schemaRegistryUsername,
      schemaRegistryPassword:
          secrets['schemaRegistryPassword'] ?? schemaRegistryPassword,
      saslKerberosServiceName: saslKerberosServiceName,
      saslKerberosKeytab: saslKerberosKeytab,
      saslKerberosPrincipal: saslKerberosPrincipal,
      saslKerberosConf: saslKerberosConf,
      saslOauthbearerToken:
          secrets['saslOauthbearerToken'] ?? saslOauthbearerToken,
      sslPemCertificateLocation: sslPemCertificateLocation,
      sslPemKeyLocation: sslPemKeyLocation,
      sslPemKeyPassword: secrets['sslPemKeyPassword'] ?? sslPemKeyPassword,
    );
  }

  ClusterProfile copyWith({
    String? name,
    String? bootstrapServers,
    String? saslUsername,
    String? saslPassword,
    String? mechanism,
    String? securityProtocol,
    String? schemaRegistryUrl,
    String? sslKeystoreLocation,
    String? sslKeystorePassword,
    String? sslTruststoreLocation,
    String? sslTruststorePassword,
    String? schemaRegistryUsername,
    String? schemaRegistryPassword,
    String? saslKerberosServiceName,
    String? saslKerberosKeytab,
    String? saslKerberosPrincipal,
    String? saslKerberosConf,
    String? saslOauthbearerToken,
    String? sslPemCertificateLocation,
    String? sslPemKeyLocation,
    String? sslPemKeyPassword,
  }) {
    return ClusterProfile(
      name: name ?? this.name,
      bootstrapServers: bootstrapServers ?? this.bootstrapServers,
      saslUsername: saslUsername ?? this.saslUsername,
      saslPassword: saslPassword ?? this.saslPassword,
      mechanism: mechanism ?? this.mechanism,
      securityProtocol: securityProtocol ?? this.securityProtocol,
      schemaRegistryUrl: schemaRegistryUrl ?? this.schemaRegistryUrl,
      sslKeystoreLocation: sslKeystoreLocation ?? this.sslKeystoreLocation,
      sslKeystorePassword: sslKeystorePassword ?? this.sslKeystorePassword,
      sslTruststoreLocation:
          sslTruststoreLocation ?? this.sslTruststoreLocation,
      sslTruststorePassword:
          sslTruststorePassword ?? this.sslTruststorePassword,
      schemaRegistryUsername:
          schemaRegistryUsername ?? this.schemaRegistryUsername,
      schemaRegistryPassword:
          schemaRegistryPassword ?? this.schemaRegistryPassword,
      saslKerberosServiceName:
          saslKerberosServiceName ?? this.saslKerberosServiceName,
      saslKerberosKeytab: saslKerberosKeytab ?? this.saslKerberosKeytab,
      saslKerberosPrincipal:
          saslKerberosPrincipal ?? this.saslKerberosPrincipal,
      saslKerberosConf: saslKerberosConf ?? this.saslKerberosConf,
      saslOauthbearerToken: saslOauthbearerToken ?? this.saslOauthbearerToken,
      sslPemCertificateLocation:
          sslPemCertificateLocation ?? this.sslPemCertificateLocation,
      sslPemKeyLocation: sslPemKeyLocation ?? this.sslPemKeyLocation,
      sslPemKeyPassword: sslPemKeyPassword ?? this.sslPemKeyPassword,
    );
  }
}
