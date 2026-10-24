import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/rust/api/json_path.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class ClusterService {
  static const String _storageKey = 'cluster_profiles';

  Future<List<ClusterProfile>> loadClusters() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString == null) {
      return [];
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final clusters = <ClusterProfile>[];
      for (final entry in jsonList) {
        clusters.add(await deserializeClusterProfile(json: jsonEncode(entry)));
      }
      return clusters;
    } catch (e) {
      // Return empty or throw, for now empty
      return [];
    }
  }

  Future<void> saveClusters(List<ClusterProfile> clusters) async {
    final prefs = await SharedPreferences.getInstance();
    // The Rust codec owns the field set, so a profile field added later is
    // persisted without touching Dart.
    final encoded = <String>[];
    for (final cluster in clusters) {
      encoded.add(await serializeClusterProfile(profile: cluster));
    }
    await prefs.setString(_storageKey, '[${encoded.join(',')}]');
  }
}

extension ClusterProfileExtension on ClusterProfile {
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
