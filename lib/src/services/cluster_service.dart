import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
      return jsonList.map((e) => ClusterProfileExtension.fromJson(e)).toList();
    } catch (e) {
      // Return empty or throw, for now empty
      return [];
    }
  }

  Future<void> saveClusters(List<ClusterProfile> clusters) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      clusters.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_storageKey, jsonString);
  }
}

extension ClusterProfileExtension on ClusterProfile {
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'bootstrapServers': bootstrapServers,
      'saslUsername': saslUsername,
      'saslPassword': saslPassword,
      'mechanism': mechanism,
      'securityProtocol': securityProtocol,
      'schemaRegistryUrl': schemaRegistryUrl,
      'sslKeystoreLocation': sslKeystoreLocation,
      'sslKeystorePassword': sslKeystorePassword,
      'sslTruststoreLocation': sslTruststoreLocation,
      'sslTruststorePassword': sslTruststorePassword,
    };
  }

  static ClusterProfile fromJson(Map<String, dynamic> json) {
    return ClusterProfile(
      name: json['name'] as String,
      bootstrapServers: json['bootstrapServers'] as String,
      saslUsername: json['saslUsername'] as String?,
      saslPassword: json['saslPassword'] as String?,
      mechanism: json['mechanism'] as String?,
      securityProtocol: json['securityProtocol'] as String?,
      schemaRegistryUrl: json['schemaRegistryUrl'] as String?,
      sslKeystoreLocation: json['sslKeystoreLocation'] as String?,
      sslKeystorePassword: json['sslKeystorePassword'] as String?,
      sslTruststoreLocation: json['sslTruststoreLocation'] as String?,
      sslTruststorePassword: json['sslTruststorePassword'] as String?,
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
    );
  }
}
